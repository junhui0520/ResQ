/**
 * 발표 전 준비: 모든 지원 언어의 앱 UI 문구를 미리 번역해 DB 캐시에 저장
 * (GOOGLE_TRANSLATE_API_KEY 필요. 일일 상한은 이 스크립트 실행 동안만 PREWARM_LIMIT 으로 변경)
 *   npm run i18n:prewarm
 */
process.env.TRANSLATE_DAILY_CHAR_LIMIT = process.env.PREWARM_LIMIT || '200000';
const { LANGUAGES } = require('../src/i18n/languages');
const base = require('../src/i18n/en.base.json');
const { getTranslator } = require('../src/services/translator');
const pool = require('../src/db/db');
const { protect } = require('../src/i18n/placeholders');

async function main() {
  const t = getTranslator();
  if (!t.isEnabled()) throw new Error('GOOGLE_TRANSLATE_API_KEY 가 없습니다.');
  // 서버 /api/i18n 과 같은 형태로 보호 → 같은 캐시를 사용
  for (const { code } of LANGUAGES) {
    if (code === 'en') continue;
    const texts = Object.values(base).map((v) => protect(v).out);
    const out = await t.translateMany(texts, code, 'en');
    console.log(`${code}: ${out.filter(Boolean).length}/${texts.length}`);
  }
}

main().then(() => pool.end()).catch(async (e) => { console.error(e.message); await pool.end(); process.exit(1); });
