/**
 * 대사관 목록 가져오기: db/embassies.tsv (기존 앱 assets/embassy_utf8_C.txt 와 동일, 탭 구분) → embassies 테이블
 * 컬럼: 국기 | 공관명 | 주소 | 우편번호 | 전화번호 | 이메일 | 팩스번호 | 주한공관 유형
 * 국제기구(🌐)는 기존 앱과 같이 제외합니다.
 *   npm run db:import-embassies
 */
const fs = require('fs');
const path = require('path');
const { normalizeEmbassyPhone, flagToCountryCode } = require('../src/utils/phone');

const SOURCE = process.env.EMBASSY_FILE
  || path.resolve(__dirname, '../db/embassies.tsv');

function parseEmbassyFile(text) {
  const lines = text.replace(/^﻿/, '').split(/\r?\n/).filter((l) => l.trim());
  return lines.slice(1).map((line) => line.split('\t').map((c) => c.trim()))
    .filter((c) => c.length >= 5 && c[0] !== '🌐' && c[1])
    .map((c) => ({
      flag: c[0] || null,
      country_code: flagToCountryCode(c[0]),
      name_en: c[1],
      address_en: c[2] || null,
      zip_code: c[3] || null,
      phone: c[4] || null,
      phone_dial: normalizeEmbassyPhone(c[4], c[2]),
      email: c[5] || null,
      fax: c[6] || null,
      embassy_type: c[7] || null,
    }));
}

async function importEmbassies() {
  const pool = require('../src/db/db');
  const rows = parseEmbassyFile(fs.readFileSync(SOURCE, 'utf8'));
  if (rows.length === 0) return 0;
  await pool.query(
    `INSERT INTO embassies (flag, country_code, name_en, address_en, zip_code, phone, phone_dial, email, fax, embassy_type)
     VALUES ?
     ON DUPLICATE KEY UPDATE flag = VALUES(flag), country_code = VALUES(country_code), address_en = VALUES(address_en),
       zip_code = VALUES(zip_code), phone = VALUES(phone), phone_dial = VALUES(phone_dial), email = VALUES(email),
       fax = VALUES(fax), embassy_type = VALUES(embassy_type)`,
    [rows.map((r) => [r.flag, r.country_code, r.name_en, r.address_en, r.zip_code, r.phone, r.phone_dial, r.email, r.fax, r.embassy_type])],
  );
  return rows.length;
}

module.exports = { importEmbassies, parseEmbassyFile };

if (require.main === module) {
  importEmbassies()
    .then((n) => { console.log(`대사관 ${n}건 저장 완료`); process.exit(0); })
    .catch((e) => { console.error(e.message); process.exit(1); });
}
