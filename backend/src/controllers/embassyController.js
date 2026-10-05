const pool = require('../db/db');
const { getTranslator } = require('../services/translator');
const { isSupported } = require('../i18n/languages');

// GET /api/embassies?country=&lang=  - 대사관 목록 조회
//  lang 을 주면 국가/공관 이름을 해당 언어로 번역한 name_translated 를 함께 반환 (주소는 원문 유지)
const getEmbassies = async (req, res) => {
  const { country } = req.query;
  const lang = isSupported(req.query.lang) ? req.query.lang : 'en';

  let query = `
    SELECT id, country_code, flag, name_en, name_ko, address_en, address_ko, phone, phone_dial,
           email, fax, zip_code, embassy_type, latitude, longitude
      FROM embassies`;
  const params = [];
  if (country) {
    query += ' WHERE name_en LIKE ? OR name_ko LIKE ?';
    params.push(`%${country}%`, `%${country}%`);
  }
  query += ' ORDER BY name_en ASC';

  const [rows] = await pool.query(query, params);

  if (lang !== 'en' && rows.length > 0) {
    const names = await getTranslator().translateMany(rows.map((r) => r.name_en), lang, 'en');
    rows.forEach((r, i) => { r.name_translated = names[i] || r.name_en; });
  } else {
    rows.forEach((r) => { r.name_translated = r.name_en; });
  }
  res.json({ embassies: rows });
};

// GET /api/emergency-numbers - 긴급전화 목록 조회
const getEmergencyNumbers = async (req, res) => {
  const [rows] = await pool.query(
    `SELECT label, number, description_en, description_ko, hours, source_url
       FROM emergency_numbers ORDER BY sort_order ASC`,
  );
  res.json({ numbers: rows });
};

module.exports = { getEmbassies, getEmergencyNumbers };
