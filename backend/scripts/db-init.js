/**
 * DB 초기화: 데이터베이스 생성 → schema.sql → seed.sql → 대사관 데이터 가져오기
 *   npm run db:init
 * (여러 번 실행해도 안전: CREATE TABLE IF NOT EXISTS + UPSERT)
 * ※ 서버도 시작할 때 테이블이 없으면 같은 작업을 자동으로 합니다 (DB_AUTO_INIT=true, 기본값)
 */
const { initDatabase } = require('../src/db/initDb');

initDatabase().then(() => process.exit(0)).catch((err) => {
  console.error('DB 초기화 실패:', err.message);
  process.exit(1);
});
