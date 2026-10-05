const crypto = require('crypto');
const pool = require('../db/db');
const config = require('../config');

/**
 * 기기 소유자 확인
 * 앱은 최초 실행 때 만든 device_uuid 를 `X-Device-Id` 헤더로 보냅니다.
 * :userId 와 device_uuid 가 같은 사용자일 때만 통과 → 다른 사람의 의료정보 조회(IDOR) 차단.
 */
async function requireDeviceOwner(req, res, next) {
  const deviceId = req.get('X-Device-Id');
  const userId = Number(req.params.userId);

  if (!deviceId) return res.status(401).json({ error: 'X-Device-Id 헤더가 필요합니다.' });
  if (!Number.isInteger(userId) || userId <= 0) {
    return res.status(400).json({ error: '잘못된 userId 입니다.' });
  }

  const [rows] = await pool.query('SELECT device_uuid FROM users WHERE id = ?', [userId]);
  if (rows.length === 0) return res.status(404).json({ error: '유저를 찾을 수 없습니다.' });
  if (!safeEqual(rows[0].device_uuid, deviceId)) {
    return res.status(403).json({ error: '접근 권한이 없습니다.' });
  }
  req.userId = userId;
  next();
}

/** 관리자 전용 (재난문자 수동 수집, 데모 알림 등) */
function requireAdmin(req, res, next) {
  if (!config.adminKey) {
    return res.status(503).json({ error: 'ADMIN_KEY 가 설정되지 않아 관리자 기능이 비활성화되어 있습니다.' });
  }
  const key = req.get('X-Admin-Key') || '';
  if (!safeEqual(key, config.adminKey)) return res.status(401).json({ error: '관리자 키가 올바르지 않습니다.' });
  next();
}

function safeEqual(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

module.exports = { requireDeviceOwner, requireAdmin };
