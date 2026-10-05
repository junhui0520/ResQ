/**
 * 시연용 [샘플] 대피소 (SHELTER_SAMPLE_MODE=true 이고 DB 에 대피소가 하나도 없을 때만 사용)
 *  - 실제 대피소가 아닙니다. 이름·주소·출처에 모두 '샘플'임을 표시합니다.
 *  - 사용자 위치를 약 200m 격자로 반올림한 지점을 기준으로 고정된 거리에 배치하므로
 *    위치가 조금 흔들려도 같은 자리에 표시됩니다.
 */

const SAMPLE_SOURCE = '샘플 데이터 (실제 대피소 아님)';

// [동쪽 m, 북쪽 m, 유형]
const OFFSETS = [
  [320, 180, '지하주차장'],
  [-420, 360, '학교 운동장'],
  [650, -480, '주민센터'],
  [-780, -260, '지하철역'],
  [140, -920, '체육관'],
  [1250, 720, '공원'],
];

const LETTERS = 'ABCDEFGHIJ';
const toRad = (d) => (d * Math.PI) / 180;

function distanceKm(lat1, lng1, lat2, lng2) {
  const x = Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.cos(toRad(lng2) - toRad(lng1))
    + Math.sin(toRad(lat1)) * Math.sin(toRad(lat2));
  return 6371 * Math.acos(Math.min(1, Math.max(-1, x)));
}

/** 기준점 주변 샘플 대피소 (반경 안, 가까운 순) */
function buildSampleShelters(lat, lng, radiusKm, limit) {
  const grid = 0.002; // 약 200m
  const cLat = Math.round(lat / grid) * grid;
  const cLng = Math.round(lng / grid) * grid;
  const mPerDegLat = 111320;
  const mPerDegLng = 111320 * Math.cos(toRad(cLat));

  return OFFSETS.map(([east, north, type], i) => {
    const sLat = cLat + north / mPerDegLat;
    const sLng = cLng + east / mPerDegLng;
    return {
      id: -(i + 1), // 실제 DB id 와 겹치지 않도록 음수
      name: `[샘플] 대피소 ${LETTERS[i]}`,
      address: '샘플 데이터 — 실제 대피소가 아닙니다 (Sample, not a real shelter)',
      shelter_type: `${type} · 샘플`,
      latitude: Math.round(sLat * 1e6) / 1e6,
      longitude: Math.round(sLng * 1e6) / 1e6,
      source: 'SAMPLE',
      distance_km: Math.round(distanceKm(lat, lng, sLat, sLng) * 100) / 100,
    };
  })
    .filter((s) => s.distance_km <= radiusKm)
    .sort((a, b) => a.distance_km - b.distance_km)
    .slice(0, limit);
}

module.exports = { buildSampleShelters, SAMPLE_SOURCE };
