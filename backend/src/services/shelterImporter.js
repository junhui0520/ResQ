const crypto = require('crypto');
const config = require('../config');
const pool = require('../db/db');
const { normalizeServiceKey } = require('../utils/serviceKey');

/**
 * 민방위 대피시설 가져오기 (재난안전데이터공유플랫폼 DSSP-IF-00195)
 *  요청: serviceKey, returnType=json, pageNo, numOfRows
 *  응답(body[]): FCLT_NM(시설명), FCLT_ADDR_RONA(도로명주소),
 *               LAT_PROVIN/LAT_MIN/LAT_SEC(위도 도·분·초), LOT_PROVIN/LOT_MIN/LOT_SEC(경도 도·분·초) 등
 *  ※ 필드 구성이 바뀌어도 동작하도록 십진 좌표 필드(LAT/LOT 등)도 함께 확인합니다.
 */

const num = (v) => (v === undefined || v === null || v === '' ? NaN : Number(v));

function dmsToDecimal(deg, min, sec) {
  const d = num(deg); const m = num(min) || 0; const s = num(sec) || 0;
  if (Number.isNaN(d)) return NaN;
  return d + m / 60 + s / 3600;
}

function pickCoord(item, kind) {
  const decimalKeys = kind === 'lat' ? ['LAT', 'LA', 'LATITUDE', 'YCORD'] : ['LOT', 'LO', 'LONGITUDE', 'XCORD'];
  for (const k of decimalKeys) {
    const v = num(item[k]);
    if (!Number.isNaN(v) && v !== 0) return v;
  }
  const p = kind === 'lat' ? 'LAT' : 'LOT';
  return dmsToDecimal(item[`${p}_PROVIN`], item[`${p}_MIN`], item[`${p}_SEC`]);
}

/** API 1건 → shelters 행 (좌표가 한국 범위를 벗어나면 null) */
function mapShelter(item) {
  const name = String(item.FCLT_NM || item.REARE_NM || '').trim();
  const address = String(item.FCLT_ADDR_RONA || item.FCLT_ADDR_LOTNO || item.RONA_DADDR || item.DADDR || '').trim();
  const lat = pickCoord(item, 'lat');
  const lng = pickCoord(item, 'lng');
  if (!name || Number.isNaN(lat) || Number.isNaN(lng)) return null;
  if (lat < 32.5 || lat > 39.5 || lng < 124 || lng > 132.5) return null;
  const sourceId = String(item.FCLT_CD || item.MNG_SN || item.SN || '').trim()
    || crypto.createHash('sha1').update(`${name}|${address}`).digest('hex').slice(0, 40);
  const type = [item.GRND_UDGD_SE, item.FCLT_SE_NM, item.ORTM_UTLZ_TYPE].filter(Boolean).join(' · ') || null;
  return {
    source: 'CIVIL_DEFENSE', source_id: sourceId, name: name.slice(0, 255), address: address.slice(0, 300) || null,
    shelter_type: type ? String(type).slice(0, 60) : null, latitude: lat, longitude: lng,
  };
}

async function importShelters({ fetchImpl = globalThis.fetch, maxPages = 50, pageSize = 1000, log = console.log } = {}) {
  if (!config.shelter.apiKey) throw new Error('SHELTER_API_KEY(또는 DISASTER_API_KEY)가 설정되지 않았습니다.');
  let imported = 0; let skipped = 0; let total = 0;

  for (let page = 1; page <= maxPages; page += 1) {
    const url = new URL(config.shelter.url);
    url.searchParams.set('serviceKey', normalizeServiceKey(config.shelter.apiKey));
    url.searchParams.set('returnType', 'json');
    url.searchParams.set('pageNo', String(page));
    url.searchParams.set('numOfRows', String(pageSize));

    const res = await fetchImpl(url, { signal: AbortSignal.timeout(30000) });
    if (!res.ok) throw new Error(`대피소 API HTTP ${res.status}`);
    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      throw new Error(`대피소 API 응답이 JSON 이 아닙니다: ${text.slice(0, 300)}`);
    }
    const header = data?.header || data?.response?.header || {};
    const resultCode = header.resultCode ?? null;
    if (resultCode !== null && !['00', '0', 0].includes(resultCode)) {
      throw new Error(`대피소 API 오류 ${resultCode}: ${header.resultMsg || header.errorMsg || ''}`);
    }
    let items = data?.body ?? data?.response?.body;
    if (items && !Array.isArray(items)) items = items.items?.item || items.items || items.item || [];
    if (!Array.isArray(items)) items = items ? [items] : [];
    total = Number(data?.totalCount ?? data?.body?.totalCount ?? header.totalCount ?? total) || total;
    if (page === 1 && items.length === 0) {
      // 원인 확인용: 응답 원문 일부 출력 (요청 주소에는 키를 넣지 않음)
      log(`[대피소] 1페이지가 비어 있습니다. 요청: ${config.shelter.url}?returnType=json&pageNo=1&numOfRows=${pageSize}`);
      log(`[대피소] 응답 원문(앞 500자): ${text.slice(0, 500)}`);
    }

    const rows = items.map(mapShelter).filter(Boolean);
    skipped += items.length - rows.length;
    if (rows.length) {
      await pool.query(
        `INSERT INTO shelters (source, source_id, name, address, shelter_type, latitude, longitude) VALUES ?
         ON DUPLICATE KEY UPDATE name = VALUES(name), address = VALUES(address),
           shelter_type = VALUES(shelter_type), latitude = VALUES(latitude), longitude = VALUES(longitude)`,
        [rows.map((r) => [r.source, r.source_id, r.name, r.address, r.shelter_type, r.latitude, r.longitude])],
      );
      imported += rows.length;
    }
    log(`[대피소] ${page}페이지: ${items.length}건 (누적 저장 ${imported})`);
    if (items.length < pageSize || (total && page * pageSize >= total)) break;
  }
  return { imported, skipped, total };
}

module.exports = { importShelters, mapShelter, dmsToDecimal };
