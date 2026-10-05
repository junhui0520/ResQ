const pool = require('../db/db');
const config = require('../config');
const { parseLatLng, inKorea } = require('./geoController');
const { buildSampleShelters, SAMPLE_SOURCE } = require('../services/sampleShelters');

// GET /api/shelters/nearby?lat=&lng=&radius_km=3&limit=20
const getNearbyShelters = async (req, res) => {
  const p = parseLatLng(req.query);
  if (!p) return res.status(400).json({ error: 'lat, lng 값이 필요합니다.' });
  if (!inKorea(p.lat, p.lng)) return res.status(422).json({ error: '대한민국 범위 밖의 좌표입니다.', out_of_korea: true });

  const radiusKm = Math.min(Math.max(Number(req.query.radius_km) || 3, 0.2), 20);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);

  // 시연용: 대피소 데이터가 없고 샘플 모드가 켜져 있으면 [샘플] 대피소 반환
  if (config.shelter.sampleMode) {
    const [[{ total }]] = await pool.query('SELECT COUNT(*) AS total FROM shelters');
    if (total === 0) {
      return res.json({
        shelters: buildSampleShelters(p.lat, p.lng, radiusKm, limit),
        data_loaded: true,
        sample: true,
        source: SAMPLE_SOURCE,
      });
    }
  }

  // 위경도 범위로 먼저 거른 뒤(인덱스 사용) 정확한 거리 계산
  const dLat = radiusKm / 111;
  const dLng = radiusKm / (111 * Math.cos((p.lat * Math.PI) / 180));
  const [rows] = await pool.query(
    `SELECT * FROM (
       SELECT id, name, address, shelter_type, latitude, longitude, source,
              6371 * ACOS(LEAST(1, GREATEST(-1,
                COS(RADIANS(?)) * COS(RADIANS(latitude)) * COS(RADIANS(longitude) - RADIANS(?)) +
                SIN(RADIANS(?)) * SIN(RADIANS(latitude))))) AS distance_km
         FROM shelters
        WHERE latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?
     ) t WHERE t.distance_km <= ? ORDER BY t.distance_km ASC LIMIT ?`,
    [p.lat, p.lng, p.lat, p.lat - dLat, p.lat + dLat, p.lng - dLng, p.lng + dLng, radiusKm, limit],
  );

  const [[{ total }]] = await pool.query('SELECT COUNT(*) AS total FROM shelters');
  res.json({
    shelters: rows.map((r) => ({ ...r, distance_km: Math.round(r.distance_km * 100) / 100 })),
    data_loaded: total > 0,
    sample: false,
    source: '행정안전부 민방위 대피시설 (재난안전데이터공유플랫폼)',
  });
};

module.exports = { getNearbyShelters };
