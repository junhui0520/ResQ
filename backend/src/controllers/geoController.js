const pool = require('../db/db');
const { reverseGeocode } = require('../services/geocoder');

// 대한민국 대략 범위 (잘못된 좌표/남용 방지)
const inKorea = (lat, lng) => lat >= 32.5 && lat <= 39.5 && lng >= 124 && lng <= 132.5;

function parseLatLng(query) {
  const lat = Number(query.lat);
  const lng = Number(query.lng);
  if (query.lat === undefined || query.lng === undefined || Number.isNaN(lat) || Number.isNaN(lng)) return null;
  return { lat, lng };
}

// GET /api/geo/reverse?lat=&lng=  → 한국어 주소 + 알림 지역 코드
const getReverse = async (req, res) => {
  const p = parseLatLng(req.query);
  if (!p) return res.status(400).json({ error: 'lat, lng 값이 필요합니다.' });
  if (!inKorea(p.lat, p.lng)) return res.status(422).json({ error: '대한민국 범위 밖의 좌표입니다.', out_of_korea: true });

  const result = await reverseGeocode(p.lat, p.lng);
  let region = null;
  if (result.region_code) {
    const [rows] = await pool.query('SELECT code, name_en, name_ko FROM regions WHERE code = ?', [result.region_code]);
    region = rows[0] || null;
  }
  res.json({
    lat: p.lat,
    lng: p.lng,
    address_ko: result.address_ko,
    region_code: result.region_code,
    region,
    provider: result.provider,
    attribution: result.provider === 'nominatim' ? '© OpenStreetMap contributors' : null,
  });
};

module.exports = { getReverse, parseLatLng, inKorea };
