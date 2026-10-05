const pool = require('../db/db');
const { getTranslator } = require('../services/translator');
const { isSupported } = require('../i18n/languages');

/*
 * 재난 알림 조회
 * - 기존 응답 필드(id, region_code, region_name, category_code, category_label, color_hex,
 *   severity_code, severity_label, title, content, action_guide, status, issued_at, resolved_at)를 유지하고
 *   원문/번역 정보 필드를 추가했습니다.
 * - 번역은 요청된 언어로 "필요할 때" 서버에서 수행 후 alert_translations 에 저장(캐시)합니다.
 */

const SELECT_ALERT = `
  SELECT
    a.id, a.region_code, r.name_en AS region_name, r.name_ko AS region_name_ko,
    a.category_code, ac.label_en AS category_label, ac.color_hex,
    a.severity_code, sl.label_en AS severity_label, sl.level AS severity_level,
    a.status, a.issued_at, a.resolved_at, a.source,
    a.region_text, a.emergency_step, a.disaster_type,
    COALESCE(tko.title, '') AS ko_title,
    COALESCE(tko.content, a.original_message, '') AS ko_content,
    tl.title AS t_title, tl.content AS t_content, tl.action_guide AS t_action_guide, tl.provider AS t_provider,
    (SELECT GROUP_CONCAT(ar.region_code) FROM alert_regions ar WHERE ar.alert_id = a.id) AS region_codes
  FROM alerts a
  JOIN regions r           ON a.region_code = r.code
  JOIN alert_categories ac ON a.category_code = ac.code
  JOIN severity_levels sl  ON a.severity_code = sl.code
  LEFT JOIN alert_translations tko ON tko.alert_id = a.id AND tko.language_code = 'ko'
  LEFT JOIN alert_translations tl  ON tl.alert_id  = a.id AND tl.language_code  = ?
`;

const clampInt = (v, d, min, max) => {
  const n = parseInt(v, 10);
  if (Number.isNaN(n)) return d;
  return Math.min(Math.max(n, min), max);
};

const normalizeLang = (lang) => (lang && isSupported(lang) ? lang : 'en');

/** 사용자가 선택한 지역 + 상위 지역(천안→충남) + 전국 */
async function regionScope(regionCode) {
  if (!regionCode || regionCode === 'ALL') return null;
  const [rows] = await pool.query('SELECT code, parent_code FROM regions WHERE code = ?', [regionCode]);
  if (rows.length === 0) return [regionCode, 'KR'];
  return [...new Set([rows[0].code, rows[0].parent_code, 'KR'].filter(Boolean))];
}

const REGION_FILTER_SQL =
  ' AND EXISTS (SELECT 1 FROM alert_regions arf WHERE arf.alert_id = a.id AND arf.region_code IN (?))';

/** DB 행 → API 응답 (+ 필요한 번역 수행) */
async function localize(rows, lang) {
  const needs = [];
  for (const row of rows) {
    if (lang !== 'ko' && !row.t_content && row.ko_content) needs.push(row);
  }

  if (needs.length > 0) {
    const translator = getTranslator();
    const texts = needs.flatMap((r) => [r.ko_title || '', r.ko_content]);
    const results = await translator.translateMany(texts, lang, 'ko');
    const inserts = [];
    needs.forEach((r, i) => {
      const title = results[i * 2];
      const content = results[i * 2 + 1];
      if (content) {
        r.t_title = title || '';
        r.t_content = content;
        r.t_action_guide = '';
        r.t_provider = translator.providerName;
        inserts.push([r.id, lang, r.t_title, content, '', translator.providerName]);
      }
    });
    if (inserts.length > 0) {
      await pool.query(
        `INSERT IGNORE INTO alert_translations (alert_id, language_code, title, content, action_guide, provider) VALUES ?`,
        [inserts],
      );
    }
  }

  return rows.map((r) => {
    const isOriginal = lang === 'ko';
    const hasTranslation = !isOriginal && !!r.t_content;
    return {
      id: r.id,
      region_code: r.region_code,
      region_name: r.region_name,
      region_name_ko: r.region_name_ko,
      region_codes: r.region_codes ? String(r.region_codes).split(',') : [r.region_code],
      region_text: r.region_text,
      category_code: r.category_code,
      category_label: r.category_label,
      color_hex: r.color_hex,
      severity_code: r.severity_code,
      severity_label: r.severity_label,
      severity_level: r.severity_level,
      emergency_step: r.emergency_step,
      disaster_type: r.disaster_type,
      title: hasTranslation ? (r.t_title || '') : r.ko_title,
      content: hasTranslation ? r.t_content : r.ko_content,
      action_guide: hasTranslation ? (r.t_action_guide || '') : '',
      original_title: r.ko_title,
      original_content: r.ko_content,
      language: hasTranslation ? lang : 'ko',
      translated: hasTranslation,
      translation_provider: hasTranslation ? r.t_provider : null,
      status: r.status,
      source: r.source,
      issued_at: r.issued_at,
      resolved_at: r.resolved_at,
    };
  });
}

// GET /api/alerts
const getAlerts = async (req, res) => {
  const { region_code, category_code, status } = req.query;
  const lang = normalizeLang(req.query.lang);
  const limit = clampInt(req.query.limit, 50, 1, 200);
  const offset = clampInt(req.query.offset, 0, 0, 100000);

  let query = `${SELECT_ALERT} WHERE 1=1`;
  const params = [lang];

  const scope = await regionScope(region_code);
  if (scope) { query += REGION_FILTER_SQL; params.push(scope); }
  if (category_code && category_code !== 'ALL') { query += ' AND a.category_code = ?'; params.push(category_code); }
  if (status) { query += ' AND a.status = ?'; params.push(status); }

  query += ' ORDER BY a.issued_at DESC, a.id DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const [rows] = await pool.query(query, params);
  res.json({ alerts: await localize(rows, lang) });
};

// GET /api/alerts/categories
const getCategories = async (req, res) => {
  const [rows] = await pool.query(
    'SELECT code, label_en, label_ko, color_hex FROM alert_categories ORDER BY sort_order ASC',
  );
  res.json({ categories: rows });
};

// GET /api/alerts/:id
const getAlertById = async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ error: '잘못된 id 입니다.' });
  const lang = normalizeLang(req.query.lang);

  const [rows] = await pool.query(`${SELECT_ALERT} WHERE a.id = ?`, [lang, id]);
  if (rows.length === 0) return res.status(404).json({ error: '알림을 찾을 수 없습니다.' });

  const [alert] = await localize(rows, lang);
  res.json(alert);
};

// GET /api/alerts/recent  (?region_code=&since_id= 로 새 알림 폴링에도 사용)
const getRecentAlerts = async (req, res) => {
  const lang = normalizeLang(req.query.lang);
  const limit = clampInt(req.query.limit, 5, 1, 50);
  const sinceId = clampInt(req.query.since_id, 0, 0, Number.MAX_SAFE_INTEGER);

  let query = `${SELECT_ALERT} WHERE a.status = 'ACTIVE'`;
  const params = [lang];
  const scope = await regionScope(req.query.region_code);
  if (scope) { query += REGION_FILTER_SQL; params.push(scope); }
  if (sinceId > 0) { query += ' AND a.id > ?'; params.push(sinceId); }
  query += ' ORDER BY a.issued_at DESC, a.id DESC LIMIT ?';
  params.push(limit);

  const [rows] = await pool.query(query, params);
  res.json({ alerts: await localize(rows, lang) });
};

// GET /api/alerts/nearby?lat=&lng=&radius=
const getNearbyAlerts = async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  if (!req.query.lat || !req.query.lng || Number.isNaN(lat) || Number.isNaN(lng)) {
    return res.status(400).json({ error: 'lat, lng 값이 필요합니다.' });
  }
  const radius = Math.min(Math.max(Number(req.query.radius) || 50, 1), 500);
  const lang = normalizeLang(req.query.lang);

  // 알림 대상 지역들 중 가장 가까운 지역 중심까지의 거리 (전국 문자는 0km 로 취급)
  const [rows] = await pool.query(
    `SELECT * FROM (
       ${SELECT_ALERT.replace('SELECT', `SELECT (
          SELECT MIN(CASE WHEN rr.code = 'KR' THEN 0 ELSE
            6371 * ACOS(LEAST(1, GREATEST(-1,
              COS(RADIANS(?)) * COS(RADIANS(rr.latitude)) * COS(RADIANS(rr.longitude) - RADIANS(?)) +
              SIN(RADIANS(?)) * SIN(RADIANS(rr.latitude)))))
          END)
          FROM alert_regions ar2 JOIN regions rr ON rr.code = ar2.region_code
          WHERE ar2.alert_id = a.id
        ) AS distance,`)}
       WHERE a.status = 'ACTIVE'
     ) t
     WHERE t.distance <= ?
     ORDER BY t.distance ASC, t.issued_at DESC
     LIMIT 50`,
    [lat, lng, lat, lang, radius],
  );

  const alerts = await localize(rows, lang);
  alerts.forEach((a, i) => { a.distance = Math.round(rows[i].distance * 10) / 10; });
  res.json({ success: true, count: alerts.length, alerts });
};

module.exports = { getAlerts, getCategories, getAlertById, getRecentAlerts, getNearbyAlerts, localize };
