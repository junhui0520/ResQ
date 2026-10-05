const pool = require('../db/db');
const { saveAlert } = require('../services/alertStore');
const { importShelters } = require('../services/shelterImporter');
const { kstDate } = require('../utils/time');

/*
 * 관리자 / 발표용 데모 기능 (X-Admin-Key 필요)
 * 데모 알림은 source='DEMO' 로 저장되고, 본문 앞에 [ResQ 데모] 가 붙어 실제 재난문자와 구분됩니다.
 */

const DEMO_PRESETS = [
  {
    key: 'earthquake', category_code: 'EARTHQUAKE', severity_code: 'HIGH', emergency_step: '긴급재난',
    region_text: '충청남도 천안시',
    message_ko: '[ResQ 데모] 충남 천안시 동남구 인근 규모 4.2 지진 발생(가상 상황). 낙하물로부터 머리를 보호하고, 흔들림이 멈추면 계단으로 넓은 곳으로 대피하세요.',
  },
  {
    key: 'rain', category_code: 'RAIN', severity_code: 'HIGH', emergency_step: '긴급재난',
    region_text: '충청남도 천안시',
    message_ko: '[ResQ 데모] 천안시 전역 호우경보 발효(가상 상황). 하천변·산책로 출입을 금지하고 저지대 주민은 안전한 곳으로 대피하시기 바랍니다.',
  },
  {
    key: 'fire', category_code: 'FIRE', severity_code: 'MEDIUM', emergency_step: '안전안내',
    region_text: '충청남도 천안시',
    message_ko: '[ResQ 데모] 천안시 동남구 산림 인접지역 산불 발생(가상 상황). 인근 주민은 산불 진행 방향의 반대쪽 안전한 곳으로 대피하시기 바랍니다.',
  },
  {
    key: 'heat', category_code: 'HEAT', severity_code: 'MEDIUM', emergency_step: '안전안내',
    region_text: '충청남도 전체',
    message_ko: '[ResQ 데모] 폭염경보 발효 중(가상 상황). 낮 시간 야외활동을 자제하고 물을 자주 마시는 등 건강관리에 유의하시기 바랍니다.',
  },
];

// GET /api/admin/demo-presets
const getDemoPresets = (req, res) => res.json({ presets: DEMO_PRESETS });

// POST /api/admin/demo-alert  { preset } 또는 { message_ko, region_text|region_code, category_code, severity_code }
const createDemoAlert = async (req, res) => {
  const body = req.body || {};
  const preset = DEMO_PRESETS.find((p) => p.key === body.preset);
  const data = { ...(preset || {}), ...body };

  let message = String(data.message_ko || '').trim();
  if (!message) return res.status(400).json({ error: 'preset 또는 message_ko 가 필요합니다.' });
  if (!message.startsWith('[ResQ 데모]')) message = `[ResQ 데모] ${message}`;

  const { id, created } = await saveAlert({
    source: 'DEMO',
    sourceSn: `demo-${Date.now()}`,
    message,
    regionText: data.region_text || null,
    regionCodes: data.region_code ? [data.region_code] : undefined,
    emergencyStep: data.emergency_step || null,
    disasterType: null,
    categoryCode: data.category_code || undefined,
    severityCode: data.severity_code || undefined,
    issuedAt: new Date(),
  });
  res.status(201).json({ id, created, message });
};

// DELETE /api/admin/demo-alerts
const clearDemoAlerts = async (req, res) => {
  const [result] = await pool.query("DELETE FROM alerts WHERE source = 'DEMO'");
  res.json({ deleted: result.affectedRows });
};

// POST /api/admin/import-shelters
const runShelterImport = async (req, res) => {
  try {
    const result = await importShelters();
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(502).json({ success: false, error: err.message });
  }
};

// GET /api/admin/stats
const getStats = async (req, res) => {
  const [[alerts]] = await pool.query(
    "SELECT COUNT(*) AS total, SUM(status = 'ACTIVE') AS active, SUM(source = 'DEMO') AS demo FROM alerts",
  );
  const [[usage]] = await pool.query('SELECT chars FROM translation_usage WHERE usage_date = ?', [kstDate()]);
  const [[shelters]] = await pool.query('SELECT COUNT(*) AS total FROM shelters');
  const [[users]] = await pool.query('SELECT COUNT(*) AS total FROM users');
  res.json({
    alerts: { total: alerts.total, active: Number(alerts.active || 0), demo: Number(alerts.demo || 0) },
    translation_chars_today: usage ? usage.chars : 0,
    shelters: shelters.total,
    users: users.total,
  });
};

module.exports = { getDemoPresets, createDemoAlert, clearDemoAlerts, runShelterImport, getStats, DEMO_PRESETS };
