const crypto = require('crypto');
const config = require('../config');
const pool = require('../db/db');
const { kstDate } = require('../utils/time');

/**
 * 서버 번역 서비스
 *  - 공급자: Google Cloud Translation Basic(v2) REST
 *    POST https://translation.googleapis.com/language/translate/v2  (q 최대 128개, 요청당 권장 5K자)
 *  - 결과는 translation_cache 테이블에 저장 → 같은 문장은 다시 과금되지 않음
 *  - translation_usage 테이블로 하루 사용 글자 수를 제한 → 무료 크레딧 초과 방지
 *  - 키가 없거나 상한 초과 시 null 을 돌려주고, 호출한 쪽은 원문을 그대로 보여줍니다.
 */

// 앱 언어 코드 → Google 언어 코드
const GOOGLE_LANG = { zh: 'zh-CN', tl: 'tl', he: 'iw' };
const toProviderLang = (lang) => GOOGLE_LANG[lang] || lang;

const MAX_SEGMENTS = 100; // 문서상 128 이하
const MAX_CHARS_PER_REQUEST = 4500; // 문서상 권장 5K 이하

const sha256 = (s) => crypto.createHash('sha256').update(s, 'utf8').digest('hex');

function createGoogleProvider(apiKey, fetchImpl = globalThis.fetch) {
  return async function googleTranslate(texts, target, source) {
    const body = { q: texts, target: toProviderLang(target), format: 'text' };
    if (source && source !== 'auto') body.source = toProviderLang(source);
    const res = await fetchImpl(
      `https://translation.googleapis.com/language/translate/v2?key=${encodeURIComponent(apiKey)}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) },
    );
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      throw new Error(`Google Translation API ${res.status}: ${detail.slice(0, 300)}`);
    }
    const json = await res.json();
    const list = json?.data?.translations || [];
    if (list.length !== texts.length) throw new Error('Google Translation API: 응답 개수 불일치');
    return list.map((t) => t.translatedText);
  };
}

class Translator {
  /**
   * @param {object} opts
   * @param {string} opts.providerName  'google' | 'none' | 'fake'
   * @param {Function} [opts.provider]  (texts[], target, source) => Promise<string[]>
   * @param {number} opts.dailyCharLimit
   */
  constructor({ providerName, provider, dailyCharLimit, db = pool }) {
    this.providerName = providerName;
    this.provider = provider;
    this.dailyCharLimit = dailyCharLimit;
    this.db = db;
  }

  isEnabled() {
    return typeof this.provider === 'function';
  }

  /**
   * 여러 문장을 번역. 결과 배열의 각 원소는 번역문 또는 null(번역 불가).
   * 빈 문자열은 그대로 돌려줍니다.
   */
  async translateMany(texts, target, source = 'ko') {
    const src = source || 'auto';
    const out = texts.map((t) => (t ? null : t));
    if (!target || target === src) return texts.slice();

    const pending = []; // { idx, text, hash }
    texts.forEach((text, idx) => {
      if (text) pending.push({ idx, text: String(text), hash: sha256(String(text)) });
    });
    if (pending.length === 0) return out;

    // 1) 캐시 조회
    const uniqueHashes = [...new Set(pending.map((p) => p.hash))];
    const cached = new Map();
    for (let i = 0; i < uniqueHashes.length; i += 500) {
      const chunk = uniqueHashes.slice(i, i + 500);
      const [rows] = await this.db.query(
        `SELECT source_hash, translated_text FROM translation_cache
          WHERE source_lang = ? AND target_lang = ? AND source_hash IN (?)`,
        [src, target, chunk],
      );
      rows.forEach((r) => cached.set(r.source_hash, r.translated_text));
    }

    const misses = [];
    const seen = new Set();
    for (const p of pending) {
      if (cached.has(p.hash)) out[p.idx] = cached.get(p.hash);
      else if (!seen.has(p.hash)) { seen.add(p.hash); misses.push(p); }
    }
    if (misses.length === 0 || !this.isEnabled()) {
      return this._fill(out, pending, cached);
    }

    // 2) 일일 사용량 확인
    const needChars = misses.reduce((n, m) => n + m.text.length, 0);
    const today = kstDate();
    const [[usage]] = await this.db.query('SELECT chars FROM translation_usage WHERE usage_date = ?', [today]);
    const used = usage ? usage.chars : 0;
    if (used + needChars > this.dailyCharLimit) {
      console.warn(`[번역] 일일 상한 초과로 번역 생략 (사용 ${used} + 요청 ${needChars} > ${this.dailyCharLimit})`);
      return this._fill(out, pending, cached);
    }

    // 3) 공급자 호출 (요청 크기 제한에 맞춰 분할)
    let translatedChars = 0;
    for (const batch of chunkByLimits(misses)) {
      try {
        const results = await this.provider(batch.map((b) => b.text), target, src);
        const values = [];
        batch.forEach((b, i) => {
          cached.set(b.hash, results[i]);
          values.push([src, target, b.hash, b.text, results[i], this.providerName]);
          translatedChars += b.text.length;
        });
        await this.db.query(
          `INSERT IGNORE INTO translation_cache
             (source_lang, target_lang, source_hash, source_text, translated_text, provider) VALUES ?`,
          [values],
        );
      } catch (err) {
        console.error('[번역] 실패:', err.message);
        break; // 나머지는 원문 유지
      }
    }
    if (translatedChars > 0) {
      await this.db.query(
        `INSERT INTO translation_usage (usage_date, chars) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE chars = chars + VALUES(chars)`,
        [today, translatedChars],
      );
    }
    return this._fill(out, pending, cached);
  }

  async translateOne(text, target, source = 'ko') {
    const [r] = await this.translateMany([text], target, source);
    return r;
  }

  _fill(out, pending, cached) {
    for (const p of pending) if (out[p.idx] === null && cached.has(p.hash)) out[p.idx] = cached.get(p.hash);
    return out;
  }
}

function chunkByLimits(items) {
  const batches = [];
  let cur = [];
  let chars = 0;
  for (const it of items) {
    if (cur.length && (cur.length >= MAX_SEGMENTS || chars + it.text.length > MAX_CHARS_PER_REQUEST)) {
      batches.push(cur); cur = []; chars = 0;
    }
    cur.push(it); chars += it.text.length;
  }
  if (cur.length) batches.push(cur);
  return batches;
}

function createDefaultTranslator() {
  const t = config.translation;
  const provider = t.provider === 'google' && t.googleApiKey ? createGoogleProvider(t.googleApiKey) : null;
  return new Translator({
    providerName: provider ? 'google' : 'none',
    provider,
    dailyCharLimit: t.dailyCharLimit,
  });
}

// 앱 전체에서 하나만 사용 (테스트에서는 setTranslator 로 교체)
let instance = createDefaultTranslator();
const getTranslator = () => instance;
const setTranslator = (t) => { instance = t; };

module.exports = {
  Translator, createGoogleProvider, getTranslator, setTranslator, toProviderLang, sha256,
};
