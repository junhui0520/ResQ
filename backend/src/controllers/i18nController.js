const crypto = require('crypto');
const { LANGUAGES, isSupported } = require('../i18n/languages');
const base = require('../i18n/en.base.json');
const { getTranslator } = require('../services/translator');
const { protect, restore } = require('../i18n/placeholders');

// 원문이 바뀌면 앱 캐시도 갱신되도록 버전 해시 제공
const BASE_VERSION = crypto.createHash('sha256').update(JSON.stringify(base)).digest('hex').slice(0, 12);

// GET /api/i18n/languages
const getLanguages = (req, res) => {
  res.json({ languages: LANGUAGES, base_version: BASE_VERSION, translation_enabled: getTranslator().isEnabled() });
};

// GET /api/i18n/:lang  → 영어 기준 문구 전체를 해당 언어로 (서버 캐시)
const getStrings = async (req, res) => {
  const { lang } = req.params;
  if (!isSupported(lang)) return res.status(404).json({ error: '지원하지 않는 언어입니다.' });
  if (lang === 'en') return res.json({ lang, base_version: BASE_VERSION, machine_translated: false, strings: base });

  // ?keys=a,b,c → 해당 키만 (앱에 검수 번역이 있는 언어는 빠진 문구만 요청 → 비용 절감)
  const requested = typeof req.query.keys === 'string' && req.query.keys
    ? req.query.keys.split(',').filter((k) => Object.prototype.hasOwnProperty.call(base, k))
    : null;
  const keys = requested || Object.keys(base);
  const prepared = keys.map((k) => protect(base[k]));
  const translated = await getTranslator().translateMany(prepared.map((p) => p.out), lang, 'en');

  const strings = {};
  let missing = 0;
  keys.forEach((k, i) => {
    const t = translated[i] ? restore(translated[i], prepared[i].names) : null;
    if (t) strings[k] = t;
    else missing += 1;
  });

  res.json({
    lang,
    base_version: BASE_VERSION,
    machine_translated: true,
    complete: missing === 0,
    strings,
  });
};

module.exports = { getLanguages, getStrings, BASE_VERSION };
