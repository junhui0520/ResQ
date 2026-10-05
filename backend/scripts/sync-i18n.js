/**
 * 앱의 기준 문구(app/assets/i18n/en.json)를 백엔드로 복사합니다.
 * 서버의 /api/i18n/:lang 자동 번역은 이 파일을 원문으로 사용합니다.
 *   npm run i18n:sync
 */
const fs = require('fs');
const path = require('path');

const src = path.resolve(__dirname, '../../app/assets/i18n/en.json');
const dst = path.resolve(__dirname, '../src/i18n/en.base.json');
fs.copyFileSync(src, dst);
console.log(`복사 완료: ${path.relative(process.cwd(), src)} → ${path.relative(process.cwd(), dst)}`);
