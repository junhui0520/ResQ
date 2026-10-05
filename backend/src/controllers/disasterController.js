const cron = require('node-cron');
const config = require('../config');
const { isDisasterMessage } = require('../services/disasterClassifier');
const { saveAlert, resolveExpiredAlerts } = require('../services/alertStore');
const { kstYmd, kstHour, parseKstDateTime } = require('../utils/time');
const { normalizeServiceKey } = require('../utils/serviceKey');

/*
 * 재난문자 수집기 (행정안전부_긴급재난문자, 재난안전데이터공유플랫폼 DSSP-IF-00247)
 * 요청: serviceKey, returnType=json, pageNo, numOfRows, crtDt(YYYYMMDD 조회시작일)
 * 응답: body[] 의 SN, CRT_DT, MSG_CN, RCPTN_RGN_NM, EMRG_STEP_NM, DST_SE_NM
 *
 * 기존 코드 대비 변경점
 *  - 1페이지 20건 → crtDt(오늘, 자정 직후엔 어제 포함) 기준 전체 페이지 수집
 *  - 중복판정: (발송시각+지역) → 원천 일련번호 SN
 *  - 분류: 키워드만 → 긴급단계명·재해구분명 우선 + 키워드 보조
 */

/** API 응답에서 목록/전체건수를 꺼냄 (응답 구조 차이에 관대하게) */
function extractItems(data) {
  if (!data || typeof data !== 'object') return { items: [], total: 0, resultCode: null, resultMsg: null };
  const header = data.header || data.response?.header || {};
  let items = data.body;
  if (items && !Array.isArray(items)) items = items.items?.item || items.items || items.item || [];
  if (!Array.isArray(items)) items = items ? [items] : [];
  const total = Number(data.totalCount ?? data.body?.totalCount ?? header.totalCount ?? data.response?.body?.totalCount ?? items.length) || 0;
  return { items, total, resultCode: header.resultCode ?? null, resultMsg: header.resultMsg ?? null };
}

async function fetchPage(crtDt, pageNo, fetchImpl = globalThis.fetch) {
  const url = new URL(config.disaster.url);
  url.searchParams.set('serviceKey', normalizeServiceKey(config.disaster.apiKey));
  url.searchParams.set('returnType', 'json');
  url.searchParams.set('pageNo', String(pageNo));
  url.searchParams.set('numOfRows', String(config.disaster.pageSize));
  url.searchParams.set('crtDt', crtDt);

  const res = await fetchImpl(url, { signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`재난문자 API HTTP ${res.status}`);
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`재난문자 API 응답이 JSON 이 아닙니다: ${text.slice(0, 200)}`);
  }
}

/**
 * 재난문자 가져와서 저장
 * @returns {{fetched:number, saved:number, skipped:number}}
 */
async function fetchAndSaveDisasterAlerts({ fetchImpl } = {}) {
  if (!config.disaster.apiKey) {
    console.warn('[재난문자] DISASTER_API_KEY 가 없어 수집을 건너뜁니다.');
    return { fetched: 0, saved: 0, skipped: 0, error: 'NO_API_KEY' };
  }

  const dates = kstHour() === 0 ? [kstYmd(new Date(), -1), kstYmd()] : [kstYmd()];
  let fetched = 0; let saved = 0; let skipped = 0;

  for (const crtDt of dates) {
    for (let page = 1; page <= config.disaster.maxPages; page += 1) {
      const data = await fetchPage(crtDt, page, fetchImpl);
      const { items, total, resultCode, resultMsg } = extractItems(data);
      if (resultCode && !['00', '0', 0].includes(resultCode)) {
        throw new Error(`재난문자 API 오류 ${resultCode}: ${resultMsg}`);
      }
      fetched += items.length;

      for (const item of items) {
        const message = item.MSG_CN || '';
        const meta = { disasterType: item.DST_SE_NM || '', emergencyStep: item.EMRG_STEP_NM || '' };
        if (!message || !isDisasterMessage(message, meta)) { skipped += 1; continue; }

        const { created } = await saveAlert({
          source: 'SAFETYDATA',
          sourceSn: item.SN,
          message,
          regionText: item.RCPTN_RGN_NM || '전국',
          emergencyStep: meta.emergencyStep,
          disasterType: meta.disasterType,
          issuedAt: parseKstDateTime(item.CRT_DT) || new Date(),
        });
        if (created) saved += 1; else skipped += 1;
      }

      if (items.length < config.disaster.pageSize || page * config.disaster.pageSize >= total) break;
    }
  }

  console.log(`[재난문자] 조회 ${fetched}건 / 신규 저장 ${saved}건 / 제외·중복 ${skipped}건`);
  return { fetched, saved, skipped };
}

let tasks = [];
function startDisasterScheduler() {
  if (!config.disaster.schedulerEnabled) {
    console.log('[재난문자] 스케줄러 비활성화 (DISASTER_SCHEDULER_ENABLED=false)');
    return;
  }
  console.log(`[재난문자] 스케줄러 시작 (${config.disaster.cron})`);
  const run = () => fetchAndSaveDisasterAlerts().catch((e) => console.error('[재난문자] 수집 실패:', e.message));
  tasks.push(cron.schedule(config.disaster.cron, run));
  tasks.push(cron.schedule('7 * * * *', () => resolveExpiredAlerts(config.disaster.activeHours)
    .then((n) => n && console.log(`[재난문자] ${n}건 종료 처리`))
    .catch((e) => console.error('[재난문자] 종료 처리 실패:', e.message))));
  run();
}

function stopDisasterScheduler() {
  tasks.forEach((t) => t.stop());
  tasks = [];
}

module.exports = { fetchAndSaveDisasterAlerts, startDisasterScheduler, stopDisasterScheduler, extractItems };
