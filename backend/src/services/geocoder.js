const config = require('../config');
const pool = require('../db/db');
const { SIDO_PREFIXES, CITY_KEYWORDS } = require('./disasterClassifier');

/**
 * 좌표 → 한국어 주소 / 지역 코드
 * 공급자: OpenStreetMap Nominatim (키 불필요)
 * 이용정책 준수: 초당 1회 이하, 앱을 식별하는 User-Agent, 결과 캐시 (geocode_cache)
 *   https://operations.osmfoundation.org/policies/nominatim/
 * 주소 데이터 © OpenStreetMap contributors (ODbL)
 */

let lastCallAt = 0;
let queue = Promise.resolve();

/** 초당 1회 제한을 지키는 직렬 큐 */
function throttle(fn) {
  const run = queue.then(async () => {
    const wait = Math.max(0, 1100 - (Date.now() - lastCallAt));
    if (wait) await new Promise((r) => setTimeout(r, wait));
    lastCallAt = Date.now();
    return fn();
  });
  queue = run.catch(() => {});
  return run;
}

const haversineKm = (lat1, lng1, lat2, lng2) => {
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(a));
};

/** 한국어 주소 문자열 → 지역 코드 (예: '충청남도 천안시 동남구 …' → CHEONAN) */
function regionFromAddress(address) {
  if (!address) return null;
  const first = address.trim().split(/\s+/)[0] || '';
  const sido = SIDO_PREFIXES.find(([p]) => first.startsWith(p) && p !== '전국');
  for (const [kw, code, parent] of CITY_KEYWORDS) {
    if (address.includes(kw) && (!sido || sido[1] === parent)) return code;
  }
  return sido ? sido[1] : null;
}

/** 주소를 못 얻으면 가장 가까운 지역 중심 좌표로 대체 */
async function nearestRegion(lat, lng) {
  const [rows] = await pool.query(
    "SELECT code, latitude, longitude FROM regions WHERE code NOT IN ('KR', 'CHEONAN') AND latitude IS NOT NULL",
  );
  let best = null;
  for (const r of rows) {
    const d = haversineKm(lat, lng, r.latitude, r.longitude);
    if (!best || d < best.d) best = { code: r.code, d };
  }
  return best ? best.code : null;
}

function buildKoreanAddress(json) {
  const a = json?.address || {};
  const parts = [
    a.province, a.state, a.city, a.county, a.borough, a.city_district, a.district,
    a.town, a.village, a.suburb, a.quarter, a.neighbourhood, a.road, a.house_number,
  ].filter(Boolean);
  const unique = parts.filter((p, i) => parts.indexOf(p) === i);
  if (unique.length >= 2) return unique.join(' ');
  // display_name 은 작은 단위부터 쉼표로 나열 → 뒤집어서 우편번호/국가 제외
  const dn = String(json?.display_name || '').split(',').map((s) => s.trim())
    .filter((s) => s && !/^\d{5}$/.test(s) && s !== '대한민국' && s !== 'South Korea');
  return dn.reverse().join(' ') || null;
}

async function nominatimReverse(lat, lng, fetchImpl = globalThis.fetch) {
  const url = new URL(config.geocoder.nominatimUrl);
  url.searchParams.set('format', 'jsonv2');
  url.searchParams.set('lat', String(lat));
  url.searchParams.set('lon', String(lng));
  url.searchParams.set('zoom', '18');
  url.searchParams.set('addressdetails', '1');
  url.searchParams.set('accept-language', 'ko');
  const ua = `ResQ-capstone/2.0 (disaster alert app for foreigners${config.geocoder.contactEmail ? `; ${config.geocoder.contactEmail}` : ''})`;
  const res = await fetchImpl(url, { headers: { 'User-Agent': ua }, signal: AbortSignal.timeout(8000) });
  if (!res.ok) throw new Error(`Nominatim HTTP ${res.status}`);
  return res.json();
}

/**
 * @returns {{address_ko:string|null, region_code:string|null, provider:string, cached:boolean}}
 */
async function reverseGeocode(lat, lng, { fetchImpl } = {}) {
  const latKey = Math.round(lat * 10000) / 10000;
  const lngKey = Math.round(lng * 10000) / 10000;

  const [cached] = await pool.query(
    'SELECT address_ko, region_code, provider FROM geocode_cache WHERE lat_key = ? AND lng_key = ?',
    [latKey, lngKey],
  );
  if (cached.length) return { ...cached[0], cached: true };

  let address = null;
  let provider = 'none';
  if (config.geocoder.provider === 'nominatim') {
    try {
      const json = await throttle(() => nominatimReverse(lat, lng, fetchImpl));
      address = buildKoreanAddress(json);
      provider = 'nominatim';
    } catch (err) {
      console.warn('[주소] 역지오코딩 실패:', err.message);
    }
  }
  const regionCode = regionFromAddress(address) || await nearestRegion(lat, lng);

  if (provider !== 'none') {
    await pool.query(
      `INSERT INTO geocode_cache (lat_key, lng_key, address_ko, region_code, provider) VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE address_ko = VALUES(address_ko), region_code = VALUES(region_code)`,
      [latKey, lngKey, address, regionCode, provider],
    );
  }
  return { address_ko: address, region_code: regionCode, provider, cached: false };
}

module.exports = { reverseGeocode, regionFromAddress, buildKoreanAddress, haversineKm, nearestRegion };
