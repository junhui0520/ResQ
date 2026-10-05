/**
 * 테스트 공통: 별도 DB(resq_test)를 매번 새로 만들고 schema/seed 적용
 * 필요: 로컬 MySQL/MariaDB (docker compose up -d db) 와 .env 의 DB_USER/DB_PASSWORD
 */
process.env.NODE_ENV = 'test';
process.env.DB_NAME = process.env.TEST_DB_NAME || 'resq_test';
process.env.ADMIN_KEY = 'test-admin-key';
process.env.GOOGLE_TRANSLATE_API_KEY = '';
process.env.TRANSLATE_PROVIDER = 'none';
process.env.GEOCODER_PROVIDER = 'none';
process.env.DISASTER_API_KEY = 'test-key';
process.env.PUBLIC_BASE_URL = 'https://resq.example';

const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const config = require('../src/config');

async function resetDatabase() {
  const { database, ...conn } = config.db;
  const c = await mysql.createConnection({ ...conn, multipleStatements: true, charset: 'utf8mb4' });
  await c.query(`DROP DATABASE IF EXISTS \`${database}\``);
  await c.query(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await c.query(`USE \`${database}\``);
  for (const f of ['schema.sql', 'seed.sql']) {
    await c.query(fs.readFileSync(path.join(__dirname, '..', 'db', f), 'utf8'));
  }
  await c.end();
}

/** 번역 호출을 기록하는 가짜 번역기: '[vi] 원문' 형태로 반환 */
function makeFakeTranslator() {
  const { Translator } = require('../src/services/translator');
  const calls = [];
  const provider = async (texts, target, source) => {
    calls.push({ texts, target, source });
    return texts.map((t) => `[${target}] ${t}`);
  };
  const t = new Translator({ providerName: 'fake', provider, dailyCharLimit: 1_000_000 });
  t.calls = calls;
  return t;
}

/** 재난문자 API 응답 흉내 */
function fakeDisasterFetch(items) {
  return async () => ({
    ok: true,
    status: 200,
    text: async () => JSON.stringify({ header: { resultCode: '00', resultMsg: 'NORMAL SERVICE' }, totalCount: items.length, body: items }),
  });
}

module.exports = { resetDatabase, makeFakeTranslator, fakeDisasterFetch };
