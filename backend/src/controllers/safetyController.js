const pool = require('../db/db');

// GET /api/safety-manuals?lang=&category_code= - 안전 행동요령 목록
//  요청 언어 번역이 없으면 영어로 대체 (기존: NULL 반환)
const getSafetyManuals = async (req, res) => {
  const { lang = 'en', category_code } = req.query;

  let query = `
    SELECT sm.id, sm.category_code, sm.sort_order, sm.image_path,
           COALESCE(t.title, en.title)     AS title,
           COALESCE(t.content, en.content) AS content,
           IF(t.title IS NULL, 'en', ?)    AS language_code
      FROM safety_manuals sm
      LEFT JOIN safety_manual_translations t  ON sm.id = t.manual_id  AND t.language_code = ?
      LEFT JOIN safety_manual_translations en ON sm.id = en.manual_id AND en.language_code = 'en'
     WHERE 1=1`;
  const params = [lang, lang];

  if (category_code) {
    query += ' AND sm.category_code = ?';
    params.push(category_code);
  }
  query += ' ORDER BY sm.category_code ASC, sm.sort_order ASC';

  const [rows] = await pool.query(query, params);
  res.json({ manuals: rows });
};

// GET /api/regions - 지역 목록
const getRegions = async (req, res) => {
  const [rows] = await pool.query(
    `SELECT code, name_en, name_ko, latitude, longitude, parent_code
       FROM regions WHERE code != 'KR' ORDER BY sort_order ASC`,
  );
  res.json({ regions: rows });
};

module.exports = { getSafetyManuals, getRegions };
