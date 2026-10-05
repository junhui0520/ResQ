const { resetDatabase, makeFakeTranslator, fakeDisasterFetch } = require('./helpers');
const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const pool = require('../src/db/db');
const config = require('../src/config');
const { createApp } = require('../src/app');
const { setTranslator, Translator } = require('../src/services/translator');
const { fetchAndSaveDisasterAlerts } = require('../src/controllers/disasterController');

const ADMIN = { 'X-Admin-Key': 'test-admin-key' };
const DEVICE = 'device-uuid-aaaaaaaaaaaaaaaaaaaa';
const OTHER_DEVICE = 'device-uuid-bbbbbbbbbbbbbbbbbbbb';

let app;
let fake;

const SAMPLE_ITEMS = [
  { SN: 1001, CRT_DT: '2026/10/05 09:00:00', MSG_CN: '[천안시청] 천안시 전역 호우경보 발효. 하천변 접근을 금지합니다.', RCPTN_RGN_NM: '충청남도 천안시', EMRG_STEP_NM: '긴급재난', DST_SE_NM: '호우' },
  // 같은 시각·같은 지역의 다른 문자 (기존 코드는 중복으로 버렸음)
  { SN: 1002, CRT_DT: '2026/10/05 09:00:00', MSG_CN: '[천안시청] 저지대 주민은 대피소로 대피 바랍니다.', RCPTN_RGN_NM: '충청남도 천안시', EMRG_STEP_NM: '안전안내', DST_SE_NM: '호우' },
  { SN: 1003, CRT_DT: '2026/10/05 08:00:00', MSG_CN: '[서울시청] 폭염경보 발효 중. 야외활동 자제', RCPTN_RGN_NM: '서울특별시 전체', EMRG_STEP_NM: '안전안내', DST_SE_NM: '폭염' },
  { SN: 1004, CRT_DT: '2026/10/05 07:00:00', MSG_CN: '[행정안전부] 규모 4.0 지진 발생', RCPTN_RGN_NM: '충청남도 전체,충청북도 전체', EMRG_STEP_NM: '위급재난', DST_SE_NM: '지진' },
  // 제외 대상 (실종자)
  { SN: 1005, CRT_DT: '2026/10/05 06:00:00', MSG_CN: '[경찰청] 홍길동씨(80세)를 찾습니다. 실종', RCPTN_RGN_NM: '서울특별시 전체', EMRG_STEP_NM: '안전안내', DST_SE_NM: '기타' },
];

test.before(async () => {
  await resetDatabase();
  const { importEmbassies } = require('../scripts/import-embassies');
  await importEmbassies();
  app = createApp();
});

test.after(async () => {
  await pool.end();
});

test.beforeEach(() => {
  fake = makeFakeTranslator();
  setTranslator(fake);
});

test('헬스체크', async () => {
  const res = await request(app).get('/api/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.db, 'ok');
});

test('재난문자 수집: SN 중복 제거, 같은 시각 다른 문자 저장, 실종 문자 제외, 다중 지역', async () => {
  const r1 = await fetchAndSaveDisasterAlerts({ fetchImpl: fakeDisasterFetch(SAMPLE_ITEMS) });
  assert.equal(r1.saved, 4);
  const r2 = await fetchAndSaveDisasterAlerts({ fetchImpl: fakeDisasterFetch(SAMPLE_ITEMS) });
  assert.equal(r2.saved, 0);

  const [[eq]] = await pool.query("SELECT id, severity_code, category_code FROM alerts WHERE source_sn = '1004'");
  assert.equal(eq.severity_code, 'CRITICAL');
  assert.equal(eq.category_code, 'EARTHQUAKE');
  const [regions] = await pool.query('SELECT region_code FROM alert_regions WHERE alert_id = ? ORDER BY region_code', [eq.id]);
  assert.deepEqual(regions.map((r) => r.region_code), ['CHUNGBUK', 'CHUNGNAM']);

  const [[issued]] = await pool.query("SELECT DATE_FORMAT(issued_at, '%Y-%m-%d %H:%i') AS t FROM alerts WHERE source_sn = '1001'");
  assert.equal(issued.t, '2026-10-05 09:00'); // KST 그대로 저장
});

test('알림 조회: 한국어 원문 / 번역 + 캐시', async () => {
  const ko = await request(app).get('/api/alerts?lang=ko');
  assert.equal(ko.status, 200);
  assert.equal(ko.body.alerts.length, 4);
  assert.equal(ko.body.alerts[0].translated, false);
  assert.match(ko.body.alerts[0].content, /천안시/);

  const vi = await request(app).get('/api/alerts?lang=vi');
  assert.ok(vi.body.alerts.every((a) => a.translated && a.content.startsWith('[vi] ')));
  assert.ok(vi.body.alerts[0].original_content.startsWith('['));
  assert.equal(fake.calls.length, 1);

  // 두 번째 요청은 DB 캐시 사용 → 번역 API 호출 없음
  const fake2 = makeFakeTranslator();
  setTranslator(fake2);
  const again = await request(app).get('/api/alerts?lang=vi');
  assert.equal(again.body.alerts[0].content, vi.body.alerts[0].content);
  assert.equal(fake2.calls.length, 0);
});

test('알림 조회: 번역 키가 없으면 원문 + translated=false', async () => {
  setTranslator(new Translator({ providerName: 'none', provider: null, dailyCharLimit: 0 }));
  const res = await request(app).get('/api/alerts?lang=th');
  assert.equal(res.status, 200);
  assert.ok(res.body.alerts.every((a) => a.translated === false && a.language === 'ko'));
});

test('알림 필터: 지역(천안 → 천안·충남·전국 포함, 서울 제외) / 유형 RAIN', async () => {
  const cheonan = await request(app).get('/api/alerts?lang=ko&region_code=CHEONAN');
  const sns = cheonan.body.alerts.map((a) => a.original_content);
  assert.equal(cheonan.body.alerts.length, 3);
  assert.ok(!sns.some((s) => s.includes('서울시청')));

  const rain = await request(app).get('/api/alerts?lang=ko&category_code=RAIN');
  assert.equal(rain.body.alerts.length, 2);
});

test('최근 알림 since_id 폴링 / 단건 조회 / 주변 알림', async () => {
  const all = await request(app).get('/api/alerts/recent?lang=ko&limit=10');
  const maxId = Math.max(...all.body.alerts.map((a) => a.id));
  const none = await request(app).get(`/api/alerts/recent?lang=ko&since_id=${maxId}`);
  assert.equal(none.body.alerts.length, 0);

  const one = await request(app).get(`/api/alerts/${maxId}?lang=en`);
  assert.equal(one.status, 200);
  assert.equal(one.body.id, maxId);
  assert.equal((await request(app).get('/api/alerts/999999')).status, 404);

  // 천안 근처 좌표 → 천안/충남 알림
  const near = await request(app).get('/api/alerts/nearby?lat=36.81&lng=127.11&radius=30&lang=ko');
  assert.equal(near.status, 200);
  assert.ok(near.body.count >= 2);
  assert.ok(near.body.alerts.every((a) => typeof a.distance === 'number'));
  assert.equal((await request(app).get('/api/alerts/nearby')).status, 400);
});

test('유저 등록 + 설정: 기기 인증(X-Device-Id) 필수', async () => {
  const created = await request(app).post('/api/users').send({ device_uuid: DEVICE, language_code: 'vi' });
  assert.equal(created.status, 201);
  const userId = created.body.user_id;
  const again = await request(app).post('/api/users').send({ device_uuid: DEVICE });
  assert.equal(again.status, 200);
  assert.equal(again.body.user_id, userId);

  assert.equal((await request(app).get(`/api/users/${userId}/settings`)).status, 401);
  assert.equal((await request(app).get(`/api/users/${userId}/settings`).set('X-Device-Id', OTHER_DEVICE)).status, 403);

  const put = await request(app).put(`/api/users/${userId}/settings`).set('X-Device-Id', DEVICE)
    .send({ selected_region_code: 'CHEONAN', alert_enabled: false });
  assert.equal(put.status, 200);
  const got = await request(app).get(`/api/users/${userId}/settings`).set('X-Device-Id', DEVICE);
  assert.equal(got.body.selected_region_code, 'CHEONAN');
  assert.equal(got.body.alert_enabled, false);
  assert.equal(got.body.sound_enabled, true);
  assert.equal(got.body.language_code, 'vi');

  const bad = await request(app).put(`/api/users/${userId}/settings`).set('X-Device-Id', DEVICE).send({ selected_region_code: 'NOWHERE' });
  assert.equal(bad.status, 400);
  const all = await request(app).put(`/api/users/${userId}/settings`).set('X-Device-Id', DEVICE).send({ selected_region_code: 'ALL' });
  assert.equal(all.status, 200);
});

test('My Info: 연락처·의료정보 저장, 타인 조회 차단, 구조대원 페이지, 삭제', async () => {
  const { body: { user_id: userId } } = await request(app).post('/api/users').send({ device_uuid: DEVICE });
  await request(app).post('/api/users').send({ device_uuid: OTHER_DEVICE });

  const profile = {
    name: 'Nguyen Van A', gender: 'male', age: 28, blood_type: 'O+', nationality: 'Vietnam', language_code: 'vi',
    emergency_contacts: [{ name: 'Tran Thi B', relationship: 'Mẹ', phone: '+84-90-000-0000' }],
    medical_infos: [{ category: 'allergy', value: 'Penicillin' }, { category: 'condition', value: 'Asthma' }],
  };
  const saved = await request(app).post(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE).send(profile);
  assert.equal(saved.status, 201);
  assert.match(saved.body.qr_url, /^https:\/\/resq\.example\/e\/[0-9a-f-]{36}$/);
  const token = saved.body.qr_token;

  const mine = await request(app).get(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE);
  assert.equal(mine.body.emergency_contacts.length, 1);
  assert.equal(mine.body.medical_infos.length, 2);

  // 다른 기기로 남의 의료정보 조회 시도 → 차단
  assert.equal((await request(app).get(`/api/users/${userId}/qr-profile`).set('X-Device-Id', OTHER_DEVICE)).status, 403);

  // 수정 시 배열 전체 교체
  const upd = await request(app).post(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE)
    .send({ ...profile, medical_infos: [{ category: 'allergy', value: 'Peanuts' }] });
  assert.equal(upd.body.qr_token, token);
  const mine2 = await request(app).get(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE);
  assert.deepEqual(mine2.body.medical_infos.map((m) => m.value), ['Peanuts']);

  // 입력 검증
  assert.equal((await request(app).post(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE).send({ name: '' })).status, 400);
  assert.equal((await request(app).post(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE).send({ name: 'x', blood_type: 'Z' })).status, 400);

  // QR JSON (한국어 번역 포함)
  const qr = await request(app).get(`/api/qr/${token}?lang=ko`);
  assert.equal(qr.status, 200);
  assert.equal(qr.body.medical_infos[0].value_ko, '[ko] Peanuts');
  assert.equal(qr.body.user_id, undefined); // 내부 id 노출 안 함

  // 구조대원 페이지 (HTML, 한국어 + 원문, XSS 방지)
  const page = await request(app).get(`/e/${token}`);
  assert.equal(page.status, 200);
  assert.match(page.headers['content-type'], /html/);
  assert.match(page.text, /혈액형/);
  assert.match(page.text, /\[ko\] Peanuts/);
  assert.match(page.text, /tel:\+84900000000/);

  await request(app).post(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE).send({ ...profile, name: '<script>alert(1)</script>' });
  const xss = await request(app).get(`/e/${token}`);
  assert.ok(!xss.text.includes('<script>alert(1)</script>'));
  assert.ok(xss.text.includes('&lt;script&gt;'));

  // 삭제
  const del = await request(app).delete(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE);
  assert.equal(del.status, 200);
  assert.equal((await request(app).get(`/api/users/${userId}/qr-profile`).set('X-Device-Id', DEVICE)).status, 404);
  assert.equal((await request(app).get(`/e/${token}`)).status, 404);
  assert.equal((await request(app).get('/api/qr/not-a-token')).status, 404);
});

test('관리자: 키 없으면 거부, 데모 알림 생성/삭제', async () => {
  assert.equal((await request(app).post('/api/disaster/fetch')).status, 401);
  assert.equal((await request(app).get('/api/admin/stats')).status, 401);

  const created = await request(app).post('/api/admin/demo-alert').set(ADMIN).send({ preset: 'earthquake' });
  assert.equal(created.status, 201);
  assert.match(created.body.message, /^\[ResQ 데모\]/);

  const list = await request(app).get('/api/alerts?lang=ko&region_code=CHEONAN');
  const demo = list.body.alerts.find((a) => a.source === 'DEMO');
  assert.ok(demo);
  assert.equal(demo.category_code, 'EARTHQUAKE');
  assert.equal(demo.severity_code, 'HIGH');

  const stats = await request(app).get('/api/admin/stats').set(ADMIN);
  assert.equal(stats.body.alerts.demo, 1);

  const cleared = await request(app).delete('/api/admin/demo-alerts').set(ADMIN);
  assert.equal(cleared.body.deleted, 1);
});

test('대사관 / 긴급전화 / 행동요령 / 지역', async () => {
  const emb = await request(app).get('/api/embassies?country=Japan&lang=ja');
  assert.equal(emb.status, 200);
  const japan = emb.body.embassies.find((e) => e.name_en === 'Japan');
  assert.equal(japan.phone_dial, '02-2170-5200');
  assert.equal(japan.name_translated, '[ja] Japan');

  const nums = await request(app).get('/api/emergency-numbers');
  assert.deepEqual(nums.body.numbers.map((n) => n.number), ['119', '112', '1345', '1339', '1330']);

  const vi = await request(app).get('/api/safety-manuals?lang=vi&category_code=FIRE');
  assert.equal(vi.body.manuals.length, 4);
  assert.equal(vi.body.manuals[0].language_code, 'en'); // 베트남어 없음 → 영어 대체
  const ko = await request(app).get('/api/safety-manuals?lang=ko&category_code=FIRE');
  assert.equal(ko.body.manuals[0].language_code, 'ko');

  const regions = await request(app).get('/api/regions');
  assert.equal(regions.body.regions.length, 18);
  assert.equal(regions.body.regions.find((r) => r.code === 'CHEONAN').parent_code, 'CHUNGNAM');
});

test('UI 다국어: 자리표시자 보존 + 지원 언어 확인', async () => {
  const langs = await request(app).get('/api/i18n/languages');
  assert.equal(langs.body.languages.length, 15);

  const vi = await request(app).get('/api/i18n/vi');
  assert.equal(vi.status, 200);
  assert.equal(vi.body.strings.time_min_ago, '[vi] {n} min ago');
  assert.equal(vi.body.machine_translated, true);
  assert.equal((await request(app).get('/api/i18n/xx')).status, 404);
  const some = await request(app).get('/api/i18n/ja?keys=new_alert,unknown_key');
  assert.deepEqual(Object.keys(some.body.strings), ['new_alert']);
  const en = await request(app).get('/api/i18n/en');
  assert.equal(en.body.machine_translated, false);
});

test('대피소 주변 검색 + 역지오코딩(공급자 없음 → 가까운 지역)', async () => {
  const empty = await request(app).get('/api/shelters/nearby?lat=36.83&lng=127.18');
  assert.equal(empty.body.data_loaded, false);
  assert.equal(empty.body.sample, false);

  // 샘플 모드: 데이터가 없을 때만 [샘플] 대피소
  config.shelter.sampleMode = true;
  const sample = await request(app).get('/api/shelters/nearby?lat=36.83&lng=127.18&radius_km=2');
  assert.equal(sample.body.sample, true);
  assert.equal(sample.body.data_loaded, true);
  assert.ok(sample.body.shelters.length >= 3);
  assert.ok(sample.body.shelters.every((x) => x.name.startsWith('[샘플]') && x.distance_km <= 2));
  assert.ok(sample.body.shelters[0].distance_km <= sample.body.shelters[1].distance_km);

  await pool.query(
    `INSERT INTO shelters (source, source_id, name, address, latitude, longitude) VALUES
      ('TEST','1','가까운 대피소','충남 천안시',36.8300,127.1800),
      ('TEST','2','먼 대피소','서울',37.5600,126.9700)`,
  );
  const near = await request(app).get('/api/shelters/nearby?lat=36.831&lng=127.181&radius_km=3');
  assert.equal(near.body.sample, false); // 실제 데이터가 있으면 샘플 모드여도 실제 데이터
  config.shelter.sampleMode = false;
  assert.equal(near.body.shelters.length, 1);
  assert.equal(near.body.shelters[0].name, '가까운 대피소');
  assert.ok(near.body.shelters[0].distance_km < 0.5);

  assert.equal((await request(app).get('/api/shelters/nearby?lat=10&lng=10')).status, 422);

  const geo = await request(app).get('/api/geo/reverse?lat=37.57&lng=126.98');
  assert.equal(geo.status, 200);
  assert.equal(geo.body.region_code, 'SEOUL');
});

test('번역 일일 상한: 초과 시 번역하지 않고 원문 유지', async () => {
  const calls = [];
  const limited = new Translator({
    providerName: 'fake', dailyCharLimit: 5, provider: async (t) => { calls.push(t); return t.map((x) => `X${x}`); },
  });
  const out = await limited.translateMany(['아주 긴 문장입니다'], 'en', 'ko');
  assert.deepEqual(out, [null]);
  assert.equal(calls.length, 0);
});

test('잘못된 JSON / 없는 경로', async () => {
  const bad = await request(app).post('/api/users').set('Content-Type', 'application/json').send('{bad');
  assert.equal(bad.status, 400);
  assert.equal((await request(app).get('/api/nope')).status, 404);
});

test('앱 화면 제공: backend/public 에 웹 빌드가 있으면 / 는 앱, /api 는 그대로', async () => {
  const fs = require('fs');
  const os = require('os');
  const path = require('path');

  // 웹 빌드가 없으면 / 는 서버 상태 JSON
  const original = config.webDir;
  config.webDir = path.join(os.tmpdir(), `resq-noweb-${Date.now()}`);
  const plain = await request(createApp()).get('/');
  assert.equal(plain.status, 200);
  assert.match(plain.body.message, /resQ API/);

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'resq-web-'));
  fs.writeFileSync(path.join(dir, 'index.html'), '<!DOCTYPE html><title>ResQ</title>');
  fs.writeFileSync(path.join(dir, 'main.dart.js'), 'console.log(1)');
  config.webDir = dir;
  const web = createApp();
  config.webDir = original;

  const home = await request(web).get('/');
  assert.equal(home.status, 200);
  assert.match(home.text, /<title>ResQ<\/title>/);
  assert.equal(home.headers['content-security-policy'], undefined); // 앱 화면은 CSP 없음
  assert.equal(home.headers['cache-control'], 'no-cache');

  const js = await request(web).get('/main.dart.js');
  assert.equal(js.status, 200);

  const deep = await request(web).get('/settings').set('Accept', 'text/html');
  assert.match(deep.text, /<title>ResQ<\/title>/);

  const health = await request(web).get('/api/health');
  assert.equal(health.body.status, 'ok');
  assert.ok(health.headers['content-security-policy']); // API 는 CSP 유지

  const missing = await request(web).get('/api/nothing').set('Accept', 'text/html');
  assert.equal(missing.status, 404);
  assert.equal(missing.body.error, '존재하지 않는 경로입니다.');

  fs.rmSync(dir, { recursive: true, force: true });
});
