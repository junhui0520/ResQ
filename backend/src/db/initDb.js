/**
 * DB 초기화: 데이터베이스 생성 → schema.sql → seed.sql → 대사관 데이터
 *  - npm run db:init 과 서버 시작 시 자동 초기화(DB_AUTO_INIT)가 함께 사용
 *  - 여러 번 실행해도 안전 (CREATE TABLE IF NOT EXISTS + UPSERT)
 */
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const config = require('../config');

function adminConnection() {
  const { database, ...conn } = config.db;
  if (!/^[A-Za-z0-9_]+$/.test(database)) throw new Error(`DB_NAME 이 올바르지 않습니다: ${database}`);
  return mysql.createConnection({ ...conn, multipleStatements: true, charset: 'utf8mb4' });
}

async function initDatabase({ log = console.log } = {}) {
  const { database } = config.db;
  const admin = await adminConnection();
  try {
    await admin.query(`CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    await admin.query(`USE \`${database}\``);
    for (const file of ['schema.sql', 'seed.sql']) {
      const sql = fs.readFileSync(path.join(__dirname, '..', '..', 'db', file), 'utf8');
      await admin.query(sql);
      log(`✔ ${file} 적용`);
    }
  } finally {
    await admin.end();
  }
  // 순환 참조를 피하려고 여기서 불러옴
  const { importEmbassies } = require('../../scripts/import-embassies');
  const n = await importEmbassies();
  log(`✔ 대사관 ${n}건 가져오기`);
  log('DB 초기화 완료');
}

/** 핵심 테이블(regions)이 이미 있는지 */
async function isInitialized() {
  const admin = await adminConnection();
  try {
    const [[row]] = await admin.query(
      "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = ? AND table_name = 'regions'",
      [config.db.database],
    );
    return Number(row.n) > 0;
  } finally {
    await admin.end();
  }
}

/**
 * 서버 시작 시: DB 가 뜰 때까지 기다렸다가(최대 약 60초) 테이블이 없으면 초기화
 * 실패해도 서버는 계속 실행 (/api/health 에서 상태 확인 가능)
 */
async function autoInitDatabase({ retries = 20, delayMs = 3000, log = console.log } = {}) {
  for (let i = 1; i <= retries; i += 1) {
    try {
      if (await isInitialized()) {
        log('[DB] 테이블 확인 완료 (자동 초기화 불필요)');
        return { initialized: false };
      }
      log('[DB] 테이블이 없어 자동 초기화를 시작합니다...');
      await initDatabase({ log });
      return { initialized: true };
    } catch (err) {
      if (i === retries) {
        console.error('[DB] 자동 초기화 실패:', err.message);
        return { initialized: false, error: err.message };
      }
      log(`[DB] 연결 대기 중... (${i}/${retries}) ${err.code || err.message}`);
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  return { initialized: false };
}

module.exports = { initDatabase, isInitialized, autoInitDatabase };
