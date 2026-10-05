const crypto = require('crypto');
const pool = require('../db/db');
const {
  classifyCategory, classifySeverity, classifyRegions, makeTitle,
} = require('./disasterClassifier');

/**
 * 알림 1건 저장 (재난문자 수집 / 데모 알림 공통)
 * - (source, source_sn) 유니크 → 같은 문자를 두 번 저장하지 않음
 * - 한국어 원문은 alert_translations 에 language_code='ko' 로 저장
 * - 수신지역 전체를 alert_regions 에 저장
 * @returns {{id:number, created:boolean}}
 */
async function saveAlert({
  source = 'SAFETYDATA', sourceSn, message, regionText, emergencyStep, disasterType, issuedAt,
  categoryCode, severityCode, regionCodes,
}) {
  const msg = String(message || '').trim();
  const sn = sourceSn ? String(sourceSn) : crypto.createHash('sha1').update(`${issuedAt}|${regionText}|${msg}`).digest('hex').slice(0, 40);

  const regions = regionCodes && regionCodes.length ? regionCodes : classifyRegions(regionText);
  const category = categoryCode || classifyCategory(msg, disasterType);
  const severity = severityCode || classifySeverity(msg, emergencyStep);

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // 존재하지 않는 지역 코드는 전국(KR)으로 대체
    const [known] = await conn.query('SELECT code FROM regions WHERE code IN (?)', [regions]);
    const knownSet = new Set(known.map((r) => r.code));
    const validRegions = regions.filter((c) => knownSet.has(c));
    if (validRegions.length === 0) validRegions.push('KR');

    const [result] = await conn.query(
      `INSERT IGNORE INTO alerts
        (source, source_sn, region_code, category_code, severity_code, status, issued_at,
         original_message, region_text, emergency_step, disaster_type)
       VALUES (?, ?, ?, ?, ?, 'ACTIVE', ?, ?, ?, ?, ?)`,
      [source, sn, validRegions[0], category, severity, issuedAt || new Date(),
        msg, regionText || null, emergencyStep || null, disasterType || null],
    );

    if (result.affectedRows === 0) {
      await conn.rollback();
      const [[existing]] = await pool.query('SELECT id FROM alerts WHERE source = ? AND source_sn = ?', [source, sn]);
      return { id: existing ? existing.id : null, created: false };
    }

    const alertId = result.insertId;
    await conn.query('INSERT INTO alert_regions (alert_id, region_code) VALUES ?', [validRegions.map((c) => [alertId, c])]);
    await conn.query(
      `INSERT INTO alert_translations (alert_id, language_code, title, content, action_guide, provider)
       VALUES (?, 'ko', ?, ?, '', 'original')`,
      [alertId, makeTitle(msg), msg],
    );
    await conn.commit();
    return { id: alertId, created: true };
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

/** 발송 후 일정 시간이 지난 알림을 종료 처리 (재난문자에는 '해제' 정보가 없으므로) */
async function resolveExpiredAlerts(activeHours) {
  const [result] = await pool.query(
    `UPDATE alerts SET status = 'RESOLVED', resolved_at = NOW()
      WHERE status = 'ACTIVE' AND issued_at < (NOW() - INTERVAL ? HOUR)`,
    [activeHours],
  );
  return result.affectedRows;
}

module.exports = { saveAlert, resolveExpiredAlerts };
