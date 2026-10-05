const mysql = require('mysql2/promise');
const config = require('../config');

// 모든 시각은 한국 표준시(KST) 기준으로 저장/해석합니다.
//  - timezone: JS Date ↔ DATETIME 변환 기준
//  - SET time_zone: NOW() 등 SQL 함수 기준
// (서버가 UTC 지역(Railway 등)에 있어도 9시간 어긋나지 않도록)
const pool = mysql.createPool({
  ...config.db,
  waitForConnections: true,
  connectionLimit: 10,
  timezone: '+09:00',
  charset: 'utf8mb4',
  decimalNumbers: true,
});

pool.on('connection', (conn) => {
  conn.query("SET time_zone = '+09:00'");
});

module.exports = pool;
