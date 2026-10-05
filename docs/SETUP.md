# 키 발급 · 환경변수 · 배포

## 1. 필요한 키

| 키 | 용도 | 없으면 |
|---|---|---|
| `DISASTER_API_KEY` | 재난문자 수집 (재난안전데이터공유플랫폼 DSSP-IF-00247) | 실제 재난문자 수집 안 됨 (데모 알림은 동작) |
| `SHELTER_API_KEY` | 민방위 대피시설 (DSSP-IF-00195) — 비우면 위 키 사용 | 대피소 지도 목록이 비어 있음 |
| `SHELTER_SAMPLE_MODE` | `true` 이면 대피소 데이터가 없을 때 사용자 위치 주변에 **[샘플] 대피소 6곳**을 표시 (시연용, 화면에 '실제 대피소 아님' 표시) | — |
| `GOOGLE_TRANSLATE_API_KEY` | 재난문자·UI·응급정보 번역 | 한국어 원문 + "번역 불가" 안내, UI 는 검수 6개 언어만 |
| `ADMIN_KEY` | 데모 알림·수동 수집 (직접 정하는 비밀 문자열) | 관리자/데모 기능 꺼짐 |

### 1-1. 재난안전데이터공유플랫폼 (재난문자·대피소)

1. https://www.safetydata.go.kr 회원가입·로그인
2. 데이터 검색에서 **행정안전부_긴급재난문자**(기존 팀 키가 있으면 재사용), **민방위 대피시설** 각각 활용신청
3. 발급된 인증키를 `backend/.env` 에 입력 — '인코딩 키'(%2B 등 포함)를 넣어도 서버가 자동으로 처리합니다.
4. 확인: 서버 실행 후 `curl -X POST -H "X-Admin-Key: <ADMIN_KEY>" http://localhost:3000/api/disaster/fetch`

> 응답 필드 근거: [공공데이터포털 행정안전부_긴급재난문자](https://www.data.go.kr/data/15134001/openapi.do) (SN, CRT_DT, MSG_CN, RCPTN_RGN_NM, EMRG_STEP_NM, DST_SE_NM).
> 대피소 API 의 실제 응답 필드가 코드(`src/services/shelterImporter.js`)의 가정(FCLT_NM, FCLT_ADDR_RONA, LAT_PROVIN/LAT_MIN/LAT_SEC …)과 다르면 `npm run db:import-shelters` 결과에 저장 0건이 나옵니다. 그때 응답 예시를 공유해 주세요.

### 1-2. Google Cloud Translation (Basic v2, API 키 방식)

공식 문서: Basic(v2)의 모든 메서드는 API 키를 지원합니다([인증 문서](https://docs.cloud.google.com/translate/docs/authentication)).

1. Google Cloud 콘솔에서 프로젝트 생성 → **결제 계정 연결**(필수, [설정 문서](https://docs.cloud.google.com/translate/docs/setup))
2. "Cloud Translation API" 사용 설정
3. API 및 서비스 → 사용자 인증 정보 → **API 키 만들기** → 키 제한에서 *Cloud Translation API* 만 허용
4. `backend/.env` 의 `GOOGLE_TRANSLATE_API_KEY` 에 입력
5. 비용: 매월 50만 자까지 무료 크레딧, 이후 100만 자당 $20([요금](https://cloud.google.com/translate/pricing)). 서버는 `TRANSLATE_DAILY_CHAR_LIMIT`(기본 15,000자/일 ≈ 월 45만 자)를 넘으면 번역을 멈추고 원문을 보여줍니다. 같은 문장은 DB 캐시로 다시 과금되지 않습니다.
6. (권장) 콘솔의 할당량 메뉴에서 일일 문자 수 상한도 설정
7. 발표 전날: `npm run i18n:prewarm` — 영어 외 14개 언어 UI 문구(언어당 약 5,500자)를 미리 번역해 캐시. 이 실행분도 그날 사용량에 합산되므로 **촬영 전날** 실행하세요.

⚠️ API 키는 **서버 `.env` 에만** 넣습니다. 앱(Flutter) 코드나 GitHub 에 올리지 마세요. (`.gitignore` 에 `.env` 포함)

## 2. 환경변수 전체

`backend/.env.example` 참고. 자주 바꾸는 값:

| 변수 | 설명 |
|---|---|
| `PUBLIC_BASE_URL` | QR 링크에 들어가는 서버 주소. **휴대폰으로 QR 을 스캔하려면 외부에서 접속 가능한 주소**(배포 주소)여야 함 |
| `CORS_ORIGINS` | 웹 앱 주소. 예: `https://resq-396fc.web.app` (기본 `*`) |
| `ALERT_ACTIVE_HOURS` | 몇 시간 동안 '발령 중'으로 볼지 (기본 24) |
| `DISASTER_SCHEDULER_ENABLED` | 5분마다 자동 수집 (기본 true) |

## 3. 배포 — Railway 한 곳에 앱 + API + MySQL (링크 하나)

구조: 백엔드가 `backend/public`(Flutter 웹 빌드)을 `/` 에서, API 를 `/api` 에서 함께 제공합니다. 앱은 `API_BASE_URL=/api` 로 빌드되어 **자기가 열린 주소의 /api** 를 호출하므로 주소를 따로 맞출 필요가 없습니다.

### 3-1. 앱 화면 빌드 (앱 코드를 바꿀 때마다)

```powershell
cd C:\Users\junhu\ResQ\ResQ-complete
.\build-web.cmd          # flutter build web --release --dart-define=API_BASE_URL=/api → backend\public 로 복사
docker compose up -d --build api   # 로컬 확인: http://localhost:3000 에서 앱이 열림
```
Railway 는 Flutter 를 설치하지 않으므로 **빌드 결과(`backend/public`)를 커밋**해서 올립니다.

### 3-2. Railway 설정 (최초 1회)

1. New Project → Deploy from GitHub repo → 이 저장소 선택
2. 서비스 Settings → **Root Directory = `/backend`** ([모노레포 문서](https://docs.railway.com/guides/monorepo)) → `backend/Dockerfile` 로 빌드됨([Dockerfile 문서](https://docs.railway.com/guides/dockerfiles))
3. 같은 프로젝트에 + New → Database → **MySQL** ([MySQL 문서](https://docs.railway.com/guides/mysql))
4. 백엔드 서비스 Variables → Raw Editor 에 입력 (참조 문법 `${{서비스이름.변수}}`, [변수 문서](https://docs.railway.com/variables))
   ```
   PORT=3000
   MYSQLHOST=${{MySQL.MYSQLHOST}}
   MYSQLPORT=${{MySQL.MYSQLPORT}}
   MYSQLUSER=${{MySQL.MYSQLUSER}}
   MYSQLPASSWORD=${{MySQL.MYSQLPASSWORD}}
   MYSQLDATABASE=${{MySQL.MYSQLDATABASE}}
   ADMIN_KEY=<직접 정한 값>
   DISASTER_API_KEY=<키>
   GOOGLE_TRANSLATE_API_KEY=<있으면>
   SHELTER_SAMPLE_MODE=true
   CORS_ORIGINS=*
   PUBLIC_BASE_URL=https://<5번에서 생성한 도메인>
   ```
5. Settings → Networking → **Generate Domain** (포트 3000) → 4번의 `PUBLIC_BASE_URL` 에 넣기
6. 첫 실행 시 테이블이 없으면 서버가 **자동으로 DB 초기화**합니다(`DB_AUTO_INIT`, 기본 true). Deploy Logs 에서 `DB 초기화 완료`, `앱 화면: 제공 중` 확인
7. `https://<도메인>` = 앱, `https://<도메인>/api/health` = `{"status":"ok","db":"ok"}`

요금: Railway 플랜별 크레딧은 [요금 문서](https://docs.railway.com/pricing/plans) 참고. 실제 사용량은 Railway 대시보드 Usage 에서 확인하세요.

### 로컬 실행 (무료, 영상 촬영용)

`docker compose up -d --build` → `http://localhost:3000` (앱 빌드를 넣었을 때) 또는 `cd app; flutter run -d chrome` (개발 중).
로컬에서는 QR 을 같은 PC 브라우저의 "구조대원 화면 미리보기" 버튼으로 시연하세요(휴대폰은 localhost 접속 불가).

## 4. 웹에서 동작 차이 (발표 전 확인)

| 기능 | 웹 브라우저 | 비고 |
|---|---|---|
| 위치 | 브라우저 위치 권한 팝업 | `localhost` 또는 HTTPS 에서만 허용 (브라우저 보안 정책) |
| 전화(tel:) | 휴대폰 브라우저는 다이얼 화면, PC 는 연결 앱 없음 | 영상은 휴대폰 브라우저 또는 Android 실행 권장 |
| 음성(TTS) | Web Speech API — 브라우저·OS 에 해당 언어 음성이 있어야 함 | Chrome 에는 한국어 음성이 기본 제공되는 경우가 많음. 촬영 전 확인 |
| 새 알림 | 앱이 열려 있을 때 60초마다 확인해 배너 표시 | 푸시(앱이 닫혀 있을 때)는 범위 밖 |
