/**
 * 재난문자 분류기 (순수 함수 → 단위 테스트 가능)
 *
 * 원천: 행정안전부_긴급재난문자 API (재난안전데이터공유플랫폼 DSSP-IF-00247)
 * 응답 필드: SN(일련번호), CRT_DT(생성일시), MSG_CN(메시지내용), RCPTN_RGN_NM(수신지역명),
 *           EMRG_STEP_NM(긴급단계명), DST_SE_NM(재해구분명)
 *
 * 기존 disasterController.js 의 키워드 분류 로직을 기반으로,
 *  - 재해구분명/긴급단계명 공식 필드를 우선 사용하고
 *  - 여러 지역 대상 문자를 모든 지역에 매핑하도록 확장했습니다.
 */

// 재난 유형 키워드 (위에서부터 우선) — 기존 categoryMap 순서 유지 + 폭염/한파 추가
const CATEGORY_RULES = [
  { category: 'EARTHQUAKE', keywords: ['지진', '해일'] },
  { category: 'RAIN', keywords: ['호우', '폭우', '강수', '태풍', '강풍', '풍랑', '바람'] },
  { category: 'FLOOD', keywords: ['홍수', '침수', '범람'] },
  { category: 'LANDSLIDE', keywords: ['산사태', '토사', '급경사지', '낙석'] },
  { category: 'FIRE', keywords: ['화재', '산불'] },
  // 기존 '눈' 단독 키워드는 '눈'(eye) 등 오분류가 많아 구체 표현으로 교체
  { category: 'SNOW', keywords: ['대설', '폭설', '적설', '눈길', '빙판'] },
  { category: 'HEAT', keywords: ['폭염', '무더위', '온열질환', '열사병'] },
  { category: 'COLD', keywords: ['한파', '동파', '저체온'] },
];

// 기존 severityMap (긴급단계명이 없을 때만 사용하는 보조 규칙)
const SEVERITY_KEYWORDS = [
  { severity: 'CRITICAL', keywords: ['경보', '위기', '긴급'] },
  { severity: 'HIGH', keywords: ['주의보', '경계'] },
  { severity: 'MEDIUM', keywords: ['주의'] },
];

// 일반 재난 키워드 (기존 disasterKeywords 일부 + 확장)
const GENERAL_DISASTER_KEYWORDS = [
  '재난', '대피', '경보', '주의보', '긴급재난', '민방공', '붕괴', '폭발', '정전', '단수', '가스누출', '방사능', '방사성',
];

// 실종자 찾기 문자 등은 재난 알림 목적에 맞지 않고 개인정보가 포함되어 제외
const EXCLUDE_KEYWORDS = ['실종', '배회', '찾습니다'];

// 시·도 (수신지역 각 구간의 첫 단어로 판별 → '경기도 광주시' 를 광주광역시로 오인하지 않음)
const SIDO_PREFIXES = [
  ['서울', 'SEOUL'], ['부산', 'BUSAN'], ['대구', 'DAEGU'], ['인천', 'INCHEON'],
  ['광주', 'GWANGJU'], ['대전', 'DAEJEON'], ['울산', 'ULSAN'], ['세종', 'SEJONG'],
  ['경기', 'GYEONGGI'], ['강원', 'GANGWON'],
  ['충청북', 'CHUNGBUK'], ['충북', 'CHUNGBUK'], ['충청남', 'CHUNGNAM'], ['충남', 'CHUNGNAM'],
  ['전라북', 'JEONBUK'], ['전북', 'JEONBUK'], ['전라남', 'JEONNAM'], ['전남', 'JEONNAM'],
  ['경상북', 'GYEONGBUK'], ['경북', 'GYEONGBUK'], ['경상남', 'GYEONGNAM'], ['경남', 'GYEONGNAM'],
  ['제주', 'JEJU'], ['전국', 'KR'],
];

// 시·도보다 세부 지역 (앱에서 별도 선택지로 제공하는 지역)
const CITY_KEYWORDS = [['천안', 'CHEONAN', 'CHUNGNAM']];

function includesAny(text, keywords) {
  return keywords.some((k) => text.includes(k));
}

function classifyCategory(message = '', disasterType = '') {
  for (const source of [disasterType || '', message || '']) {
    for (const rule of CATEGORY_RULES) {
      if (includesAny(source, rule.keywords)) return rule.category;
    }
  }
  return 'OTHER';
}

function classifySeverity(message = '', emergencyStep = '') {
  const step = emergencyStep || '';
  if (step.includes('위급')) return 'CRITICAL';
  if (step.includes('긴급')) return 'HIGH';
  if (step.includes('안전안내')) return 'MEDIUM';
  for (const rule of SEVERITY_KEYWORDS) {
    if (includesAny(message || '', rule.keywords)) return rule.severity;
  }
  return 'LOW';
}

/**
 * 수신지역명 → 지역 코드 배열. 첫 번째 값이 대표 지역.
 * 예) '충청남도 천안시 동남구,경기도 광주시' → ['CHEONAN','CHUNGNAM','GYEONGGI']
 */
function classifyRegions(regionText = '') {
  const text = String(regionText || '').trim();
  if (!text) return ['KR'];

  const codes = [];
  const add = (c) => { if (c && !codes.includes(c)) codes.push(c); };

  const segments = text.split(/[,，·/]/).map((s) => s.trim()).filter(Boolean);
  for (const seg of segments) {
    const first = seg.split(/\s+/)[0];
    const sido = SIDO_PREFIXES.find(([p]) => first.startsWith(p));

    for (const [kw, code, parent] of CITY_KEYWORDS) {
      if (seg.includes(kw) && (!sido || sido[1] === parent)) add(code);
    }
    if (sido) {
      add(sido[1]);
    } else {
      // 시·도 표기가 없는 구간은 기존처럼 포함 여부로 판별
      const loose = SIDO_PREFIXES.find(([p]) => seg.includes(p));
      if (loose) add(loose[1]);
    }
  }

  if (codes.length === 0) return ['KR'];
  // 세부 지역(천안)을 대표 지역으로
  const cityFirst = codes.filter((c) => CITY_KEYWORDS.some(([, code]) => code === c));
  return [...cityFirst, ...codes.filter((c) => !cityFirst.includes(c))];
}

function isDisasterMessage(message = '', { disasterType = '', emergencyStep = '' } = {}) {
  const msg = message || '';
  const category = classifyCategory(msg, disasterType);
  const isAlarmed = /위급|긴급/.test(emergencyStep || '');
  if (category === 'OTHER' && !isAlarmed && includesAny(msg, EXCLUDE_KEYWORDS)) return false;
  if (category !== 'OTHER' || isAlarmed) return true;
  return includesAny(msg, GENERAL_DISASTER_KEYWORDS);
}

/** 목록 제목: 앞의 [발신기관] 표기를 떼고 첫 문장(최대 60자) */
function makeTitle(message = '') {
  const body = String(message || '').replace(/^\s*\[[^\]]{1,30}\]\s*/, '').trim();
  const firstSentence = body.split(/(?<=[.!?。])\s|\n/)[0] || body;
  const t = firstSentence.trim();
  return t.length > 60 ? `${t.slice(0, 59)}…` : t;
}

module.exports = {
  classifyCategory,
  classifySeverity,
  classifyRegions,
  isDisasterMessage,
  makeTitle,
  SIDO_PREFIXES,
  CITY_KEYWORDS,
};
