# ResQ — 외국인을 위한 재난 알림·긴급 대응 앱

한국어 재난문자를 이해하기 어려운 외국인을 위해 **다국어 재난 알림, 긴급 신고 도우미, 응급정보 QR, 대피소 안내, 대사관 정보**를 제공합니다.
2026-1 캡스톤 프로젝트(백엔드·프론트엔드 브랜치)를 하나의 저장소로 합치고 완성한 버전입니다.

```
ResQ-complete/
├─ backend/              Node.js 22 · Express 5 · MySQL 8 (mysql2) · node-cron
│  ├─ db/                schema.sql · seed.sql · embassies.tsv
│  ├─ scripts/           db-init · import-embassies · import-shelters · sync-i18n
│  ├─ src/               app.js(Express) · index.js(실행) · controllers · routes · services · views
│  └─ tests/             node:test + supertest (단위 13 · API 14)
├─ app/                  Flutter (Web 우선, Android/iOS 빌드 가능)
│  ├─ assets/i18n/       언어별 UI 문구 (en·ko·ja·zh·vi·de 검수본)
│  └─ lib/               core · providers · services · screens · pages · widgets
├─ docs/                 분석·API·설정·발표 시나리오·팀 할 일
└─ docker-compose.yml    로컬 MySQL + API
```

## 주요 기능

| 구분 | 기능 | 비고 |
|---|---|---|
| 기존 | 실시간 재난문자 수신·유형 필터, 다국어 UI, 119/112 전화, My Info 응급정보, 대사관 검색, 안전 가이드 | 화면·문구·이미지 유지 |
| 개선 | 재난문자 **서버 번역**(Google Cloud Translation) + DB 캐시, 원문↔번역 토글 | 앱의 비공식 번역 호출 제거 |
| 개선 | UI **15개 언어** (검수 6 + 서버 자동번역 9) | en·ko·zh·vi·th·uz·ru·ja·ne·id·mn·km·tl·my·de |
| 신규 | **구조대원용 응급정보 QR** → 스캔하면 한국어로 번역된 응급정보 웹페이지 | `/e/:token` |
| 신규 | **119 신고 도우미**: 한국어 문장 카드 + 음성 재생 + 현재 위치 한국어 주소 | Nominatim 역지오코딩 |
| 신규 | 알림 상세: 유형별 행동요령, 음성 읽기, 대피소 찾기 | |
| 신규 | 내 위치 기반 지역 자동 설정, **주변 대피소 지도**(민방위 대피시설) + 길찾기 | OpenStreetMap |
| 신규 | 새 알림 실시간 배너(60초 확인) + 위급·긴급 알림 음성 안내 | 웹 데모용 |
| 신규 | **발표용 데모 모드**: `[ResQ 데모]` 가상 알림 주입 | 설정 > 앱 버전 5번 탭 |

변경 근거와 기존 코드 결함 목록은 [docs/ANALYSIS.md](docs/ANALYSIS.md)에 정리했습니다.

## 빠른 시작 (로컬)

### 1) 백엔드 + DB

```bash
cd backend
cp .env.example .env          # ADMIN_KEY, DISASTER_API_KEY, GOOGLE_TRANSLATE_API_KEY 입력 (docs/SETUP.md)
cd ..
docker compose up -d --build  # MySQL 8.4 + API (http://localhost:3000)
docker compose exec api npm run db:init        # 테이블·기본데이터·대사관 122곳
docker compose exec api npm run db:import-shelters   # (선택) 민방위 대피시설 — 키 필요
```

Docker 없이 실행하려면 MySQL 8을 직접 설치한 뒤 `backend/.env` 의 `DB_*` 를 맞추고:

```bash
cd backend && npm install && npm run db:init && npm run dev
```

확인: `http://localhost:3000/api/health` → `{"status":"ok","db":"ok"}`

### 2) 앱 (Flutter Web)

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

배포(링크 하나로 공유): `build-web.cmd` 로 앱을 `backend/public` 에 빌드 → 백엔드가 `/` 에서 앱, `/api` 에서 API 제공 → Railway 에 백엔드+MySQL 배포. 자세한 절차는 [docs/SETUP.md](docs/SETUP.md) 3절.

### 3) 테스트

```bash
cd backend && npm test          # MySQL 필요 (resq_test DB 를 자동 생성/삭제)
cd app && flutter analyze && flutter test
```

## 데이터 출처 (앱 화면에도 표시)

- 재난문자: 행정안전부_긴급재난문자 (재난안전데이터공유플랫폼 DSSP-IF-00247) — [공공데이터포털](https://www.data.go.kr/data/15134001/openapi.do), 이용허락: 공공누리 제4유형(출처표시·상업적 이용금지·변경금지). 앱은 출처를 표시하고 번역문과 함께 **한국어 원문을 항상 볼 수 있게** 했습니다. 번역 제공이 '변경금지'에 해당하는지는 제공기관(행정안전부 재난안전데이터과, 044-205-4467)에 확인하는 것을 권장합니다.
- 대피소: 행정안전부 민방위 대피시설 (재난안전데이터공유플랫폼 DSSP-IF-00195)
- 지도·주소: © OpenStreetMap contributors (타일·Nominatim 이용정책 준수: 앱 식별 User-Agent, 초당 1회, 결과 캐시)
- 번역: Google Cloud Translation Basic(v2)
- 긴급전화 안내: 질병관리청(1339), 법무부 외국인종합안내센터(1345) 등 — 출처 URL 을 DB(`emergency_numbers.source_url`)에 함께 저장

## 문서

- [docs/ANALYSIS.md](docs/ANALYSIS.md) — 기존 코드 분석, 발견한 결함과 수정 내역
- [docs/API.md](docs/API.md) — REST API 명세
- [docs/SETUP.md](docs/SETUP.md) — API 키 발급, 환경변수, Railway 배포(앱+API 한 링크)
- [docs/DEMO_SCENARIO.md](docs/DEMO_SCENARIO.md) — 경진대회 영상·발표 시나리오
- [docs/TEAM_TODO.md](docs/TEAM_TODO.md) — 남은 2주 팀 할 일 체크리스트
