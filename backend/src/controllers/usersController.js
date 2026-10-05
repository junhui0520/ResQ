const pool = require('../db/db');
const { isSupported } = require('../i18n/languages');

// POST /api/users - 유저 등록 (이미 있는 device_uuid 면 기존 유저 반환)
const createUser = async (req, res) => {
  const { device_uuid, nationality } = req.body || {};
  const language_code = isSupported(req.body?.language_code) ? req.body.language_code : 'en';

  if (!device_uuid || typeof device_uuid !== 'string' || device_uuid.length < 16 || device_uuid.length > 64) {
    return res.status(400).json({ error: 'device_uuid는 필수입니다. (16~64자)' });
  }

  const [existing] = await pool.query(
    'SELECT id, device_uuid, language_code FROM users WHERE device_uuid = ?',
    [device_uuid],
  );

  if (existing.length > 0) {
    await pool.query('UPDATE users SET last_seen_at = NOW() WHERE id = ?', [existing[0].id]);
    return res.status(200).json({
      user_id: existing[0].id,
      device_uuid: existing[0].device_uuid,
      language_code: existing[0].language_code,
    });
  }

  const [result] = await pool.query(
    'INSERT INTO users (device_uuid, nationality, language_code, last_seen_at) VALUES (?, ?, ?, NOW())',
    [device_uuid, nationality || null, language_code],
  );
  const userId = result.insertId;

  // user_settings 기본값 자동 생성
  await pool.query(
    'INSERT INTO user_settings (user_id, alert_enabled, sound_enabled, location_enabled) VALUES (?, TRUE, TRUE, FALSE)',
    [userId],
  );

  return res.status(201).json({ user_id: userId, device_uuid, language_code });
};

// GET /api/users/:userId/settings
const getSettings = async (req, res) => {
  const [rows] = await pool.query(
    `SELECT us.alert_enabled, us.sound_enabled, us.location_enabled, us.selected_region_code, u.language_code
       FROM user_settings us JOIN users u ON us.user_id = u.id
      WHERE us.user_id = ?`,
    [req.userId],
  );
  if (rows.length === 0) return res.status(404).json({ error: '유저를 찾을 수 없습니다.' });
  const r = rows[0];
  res.json({
    alert_enabled: !!r.alert_enabled,
    sound_enabled: !!r.sound_enabled,
    location_enabled: !!r.location_enabled,
    selected_region_code: r.selected_region_code,
    language_code: r.language_code,
  });
};

// PUT /api/users/:userId/settings  (보낸 항목만 수정)
const updateSettings = async (req, res) => {
  const body = req.body || {};
  const sets = [];
  const params = [];

  for (const key of ['alert_enabled', 'sound_enabled', 'location_enabled']) {
    if (body[key] !== undefined && body[key] !== null) { sets.push(`${key} = ?`); params.push(!!body[key]); }
  }

  if (body.selected_region_code !== undefined) {
    let region = body.selected_region_code;
    if (!region || region === 'ALL') region = null;
    if (region) {
      const [r] = await pool.query('SELECT code FROM regions WHERE code = ?', [region]);
      if (r.length === 0) return res.status(400).json({ error: '알 수 없는 지역 코드입니다.' });
    }
    sets.push('selected_region_code = ?');
    params.push(region);
  }

  if (sets.length > 0) {
    await pool.query(`UPDATE user_settings SET ${sets.join(', ')} WHERE user_id = ?`, [...params, req.userId]);
  }
  if (body.language_code && isSupported(body.language_code)) {
    await pool.query('UPDATE users SET language_code = ? WHERE id = ?', [body.language_code, req.userId]);
  }

  res.json({ updated: true });
};

module.exports = { createUser, getSettings, updateSettings };
