require('./helpers');
const test = require('node:test');
const assert = require('node:assert/strict');

const c = require('../src/services/disasterClassifier');
const { normalizeEmbassyPhone, flagToCountryCode } = require('../src/utils/phone');
const { parseKstDateTime, kstYmd } = require('../src/utils/time');
const { normalizeServiceKey } = require('../src/utils/serviceKey');
const { extractItems } = require('../src/controllers/disasterController');
const { mapShelter, dmsToDecimal } = require('../src/services/shelterImporter');
const { regionFromAddress, buildKoreanAddress } = require('../src/services/geocoder');

test('지역 분류: 여러 지역 + 세부 지역(천안) 우선', () => {
  assert.deepEqual(c.classifyRegions('충청남도 천안시 동남구,경기도 광주시'), ['CHEONAN', 'CHUNGNAM', 'GYEONGGI']);
  assert.deepEqual(c.classifyRegions('서울특별시 전체'), ['SEOUL']);
  assert.deepEqual(c.classifyRegions('전국'), ['KR']);
  assert.deepEqual(c.classifyRegions(''), ['KR']);
  // 경기도 광주시를 광주광역시로 오인하지 않음
  assert.deepEqual(c.classifyRegions('경기도 광주시'), ['GYEONGGI']);
  assert.deepEqual(c.classifyRegions('광주광역시 북구'), ['GWANGJU']);
  // 개편된 명칭
  assert.deepEqual(c.classifyRegions('전북특별자치도 전주시'), ['JEONBUK']);
  assert.deepEqual(c.classifyRegions('강원특별자치도 춘천시'), ['GANGWON']);
});

test('재난 유형: 재해구분명 우선, 없으면 본문 키워드', () => {
  assert.equal(c.classifyCategory('하천 범람 우려', '호우'), 'RAIN');
  assert.equal(c.classifyCategory('규모 3.1 지진 발생'), 'EARTHQUAKE');
  assert.equal(c.classifyCategory('폭염경보 발효 중'), 'HEAT');
  assert.equal(c.classifyCategory('내일 아침 한파 예상'), 'COLD');
  assert.equal(c.classifyCategory('눈이 아프면 병원 방문'), 'OTHER'); // '눈'(eye) 오분류 방지
  assert.equal(c.classifyCategory('대설주의보 발효'), 'SNOW');
});

test('심각도: 긴급단계명 우선', () => {
  assert.equal(c.classifySeverity('아무 내용', '위급재난'), 'CRITICAL');
  assert.equal(c.classifySeverity('아무 내용', '긴급재난'), 'HIGH');
  assert.equal(c.classifySeverity('호우경보', '안전안내'), 'MEDIUM');
  assert.equal(c.classifySeverity('호우주의보 발효'), 'HIGH');
  assert.equal(c.classifySeverity('일반 안내'), 'LOW');
});

test('재난 문자 여부: 실종자 찾기 문자는 제외', () => {
  assert.equal(c.isDisasterMessage('○○○씨(80세)를 찾습니다. 실종'), false);
  assert.equal(c.isDisasterMessage('호우경보 발효, 대피 바랍니다'), true);
  assert.equal(c.isDisasterMessage('일반 공지', { emergencyStep: '위급재난' }), true);
});

test('제목 생성: [발신기관] 제거 + 첫 문장', () => {
  assert.equal(c.makeTitle('[천안시청] 호우경보 발효. 하천변 접근 금지'), '호우경보 발효.');
  assert.ok(c.makeTitle('가'.repeat(100)).length <= 60);
});

test('대사관 전화번호 정규화', () => {
  assert.equal(normalizeEmbassyPhone('3785-1427, 749-8982/3', 'Jung-gu, Seoul'), '02-3785-1427');
  assert.equal(normalizeEmbassyPhone('051)465-5104/5/6', 'Busan'), '051-465-5104');
  assert.equal(normalizeEmbassyPhone('010-6639-1150', ''), '010-6639-1150');
  assert.equal(normalizeEmbassyPhone('3785-1427', 'Busan'), null); // 서울이 아니면 추측하지 않음
  assert.equal(flagToCountryCode('🇺🇸'), 'US');
  assert.equal(flagToCountryCode('🌐'), null);
});

test('시간: CRT_DT 형식들을 KST 로 해석', () => {
  const d = parseKstDateTime('2026/07/10 13:22:05');
  assert.equal(d.toISOString(), '2026-07-10T04:22:05.000Z');
  assert.equal(parseKstDateTime('20260710132205').toISOString(), '2026-07-10T04:22:05.000Z');
  assert.equal(parseKstDateTime('잘못된 값'), null);
  assert.equal(kstYmd(new Date('2026-10-05T16:00:00Z')), '20261006'); // UTC 16시 = KST 다음날 1시
});

test('공공데이터 인증키: 인코딩 키 자동 디코딩', () => {
  assert.equal(normalizeServiceKey('abc%2Bdef%3D%3D'), 'abc+def==');
  assert.equal(normalizeServiceKey('abc+def=='), 'abc+def==');
});

test('재난문자 응답 파싱: body 배열 / 중첩 구조 모두 허용', () => {
  assert.equal(extractItems({ body: [{ SN: 1 }], totalCount: 1 }).items.length, 1);
  assert.equal(extractItems({ body: { items: { item: [{ SN: 1 }, { SN: 2 }] } } }).items.length, 2);
  assert.equal(extractItems(null).items.length, 0);
});

test('대피소 매핑: 도분초 → 십진 좌표', () => {
  assert.ok(Math.abs(dmsToDecimal(36, 50, 0) - 36.8333333) < 1e-6);
  const s = mapShelter({ FCLT_NM: '테스트 대피소', FCLT_ADDR_RONA: '충남 천안시', LAT_PROVIN: 36, LAT_MIN: 49, LAT_SEC: 0, LOT_PROVIN: 127, LOT_MIN: 9, LOT_SEC: 0 });
  assert.equal(s.name, '테스트 대피소');
  assert.ok(s.latitude > 36.8 && s.longitude > 127.1);
  assert.equal(mapShelter({ FCLT_NM: 'x', LAT_PROVIN: 0, LOT_PROVIN: 0 }), null);
});

test('주소 → 지역 코드', () => {
  assert.equal(regionFromAddress('충청남도 천안시 동남구 안서동'), 'CHEONAN');
  assert.equal(regionFromAddress('서울특별시 중구 세종대로'), 'SEOUL');
  assert.equal(regionFromAddress('경기도 광주시 경안동'), 'GYEONGGI');
  assert.equal(regionFromAddress(null), null);
  assert.equal(
    buildKoreanAddress({ address: { province: '충청남도', city: '천안시', borough: '동남구', quarter: '안서동', road: '문암로' } }),
    '충청남도 천안시 동남구 안서동 문암로',
  );
});

test('UI 기준 문구: 백엔드 사본(en.base.json)이 앱 en.json 과 같음 (다르면 npm run i18n:sync)', () => {
  const fs = require('fs');
  const path = require('path');
  const appFile = path.resolve(__dirname, '../../app/assets/i18n/en.json');
  if (!fs.existsSync(appFile)) return; // 백엔드만 배포된 환경
  assert.deepEqual(require('../src/i18n/en.base.json'), JSON.parse(fs.readFileSync(appFile, 'utf8')));
});

test('Google 번역 요청 형식 (공식 v2 REST: q 배열, target, format=text, key)', async () => {
  const { createGoogleProvider } = require('../src/services/translator');
  let captured;
  const fakeFetch = async (url, opts) => {
    captured = { url: String(url), body: JSON.parse(opts.body) };
    return { ok: true, json: async () => ({ data: { translations: [{ translatedText: '你好' }, { translatedText: '世界' }] } }) };
  };
  const provider = createGoogleProvider('KEY+1', fakeFetch);
  const out = await provider(['안녕', '세계'], 'zh', 'ko');
  assert.deepEqual(out, ['你好', '世界']);
  assert.equal(captured.url, 'https://translation.googleapis.com/language/translate/v2?key=KEY%2B1');
  assert.deepEqual(captured.body, { q: ['안녕', '세계'], target: 'zh-CN', format: 'text', source: 'ko' });

  const auto = createGoogleProvider('K', fakeFetch);
  await auto(['x'], 'ko', 'auto').catch(() => {});
  assert.equal(captured.body.source, undefined); // 자동 감지
});
