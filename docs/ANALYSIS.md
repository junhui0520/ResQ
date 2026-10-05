# 기존 코드 분석 및 수정 내역

분석 대상: `resq-backend-main.zip`(백엔드 브랜치), `resq-backend-front.zip`(프론트엔드 브랜치) — 2026-10-05 기준.
"근거"는 원본 파일과 줄 번호(원본 기준)입니다. 모든 항목은 이 저장소에서 수정했고, 백엔드 항목은 자동 테스트로 검증했습니다.

## 1. 원본 구조

| 영역 | 내용 |
|---|---|
| 백엔드 | Node.js · Express 5.2 · mysql2 3.22 · axios · node-cron 4, 라우터 8개(alerts, users, qr, embassies, emergency-numbers, safety-manuals, regions, disaster), Railway 배포 |
| 프론트 | Flutter(Dart ^3.11.4) · provider · http · shared_preferences · url_launcher · csv · uuid, 화면 4탭(홈·알림·대사관·설정) + My Info·119·안전가이드, Firebase Hosting(`resq-396fc`) |
| 앱이 실제 호출한 API | `/users`, `/users/:id/settings`, `/users/:id/qr-profile`, `/alerts`, `/regions` |
| 앱이 호출하지 않은 API | `/embassies`, `/emergency-numbers`, `/safety-manuals`, `/alerts/nearby`, `/alerts/:id`, `/alerts/categories` (대사관은 앱 내부 txt 사용) |

## 2. 발견한 결함과 수정

### 백엔드

| # | 결함 | 근거 | 수정 |
|---|---|---|---|
| B1 | DB 스키마(.sql) 없음 → 서버 재현 불가 | 저장소에 .sql 파일 없음 | `db/schema.sql`·`seed.sql`·`scripts/db-init.js` (기존 쿼리의 14개 테이블·컬럼 그대로 + 신규) |
| B2 | 내 정보 API 인증 없음 → userId 만 바꾸면 타인 의료정보 조회(IDOR) | `routes/users.js` 전체 | `X-Device-Id`(기기 UUID) 검증 미들웨어 `requireDeviceOwner` |
| B3 | 재난문자 수동 수집 API 누구나 호출 | `routes/disaster.js:6` | `X-Admin-Key` 필요 |
| B4 | qr-profile 이 연락처·의료정보를 저장하지 않음 (앱은 함께 보내지만 서버가 무시) | `qrController.js:8`, 앱 `qr_result_screen.dart:687` | 배열을 받아 트랜잭션으로 일괄 저장 |
| B5 | 재난문자 중복 판정이 `발송시각+지역` → 같은 시각 다른 문자 유실 | `disasterController.js:121` | 원천 일련번호 `SN` 유니크 |
| B6 | 다지역 문자를 한 지역만 매핑, '경기도 광주시'↔'광주광역시' 같은 오분류 위험 | `disasterController.js:74` | 수신지역 구간별 시·도 판별 + `alert_regions` 다대다 |
| B7 | 공식 필드 미사용(키워드만으로 심각도·유형 추정) | `disasterController.js:116` | `EMRG_STEP_NM`(위급/긴급/안전안내)·`DST_SE_NM` 우선 |
| B8 | 한국어 원문을 `language_code='en'` 으로 저장 | `disasterController.js:138` | 원문은 `ko`, 번역은 언어별 행 |
| B9 | 1페이지 20건만 조회 | `disasterController.js:93` | `crtDt`(오늘) 기준 전체 페이지 |
| B10 | 요청 로그 미들웨어가 라우터 뒤에 있어 동작 안 함 | `index.js:33` | 라우터 앞으로 |
| B11 | 서버 시간대 미설정 → UTC 서버에서 KST 시각 9시간 오차 가능 | `db/db.js` | mysql2 `timezone:'+09:00'` + 세션 `time_zone` |
| B12 | `/alerts` 결과 무제한 | `alertsController.js:47` | `limit`(기본 50, 최대 200) |
| B13 | axios 1.17 취약점 다수(npm audit high) | `package.json` | axios 제거, Node 내장 fetch 사용 → audit 0건 |

### 프론트엔드

| # | 결함 | 근거 | 수정 |
|---|---|---|---|
| F1 | UI 번역이 Dart 코드에 하드코딩(4개 언어) | `services/translation_service.dart` | 언어별 JSON(기존 번역 그대로 이전) + 서버 자동 번역 → 15개 언어 |
| F2 | 재난문자·대사관을 비공식 주소 `translate.googleapis.com/translate_a/single?client=gtx` 로 앱에서 직접 번역 | `alert_service.dart:120`, `embassy_page.dart:122` | 서버에서 공식 Google Cloud Translation 호출 + DB 캐시 |
| F3 | 호우·태풍 필터 항상 빈 목록 (앱 `RAIN` ≠ 서버 `RAIN/TYPHOON`) | `alerts_page.dart:18`, `disasterController.js:8` | 코드 통일(`RAIN`) + 폭염·한파 추가 |
| F4 | My Info 삭제 실패 (`name:''` 로 POST → 서버 400) | `qr_result_screen.dart:196` | `DELETE /users/:id/qr-profile` |
| F5 | QR 코드가 화면에 없음, 연락처 "Call" 버튼 동작 없음 | `qr_result_screen.dart:501` | `qr_flutter` QR + 전화 연결 |
| F6 | 1339 를 "Medical Helpline" 으로 안내 | `app_strings.dart:94` | 1339 응급의료정보센터는 2012.6 119로 통합, 2013.6.22 번호 폐지([아주경제](https://www.ajunews.com/view/20130620000692)). 현재 1339 는 질병관리청 감염병 콜센터([질병관리청](https://kdca.go.kr/kdca/2777/subview.do)) → 문구 정정 |
| F7 | "Operators speak basic English" — 근거 미확인 | `app_strings.dart:99` | 삭제 |
| F8 | 대사관 전화번호 `3785-1427, 749-8982/3` 그대로 다이얼 → 연결 불가 | `embassy_page.dart:252` | 첫 번호 + 서울 주소면 `02-` (122곳 모두 정규화) |
| F9 | 홈 "All clear · Cheonan" 고정, 3일 내 아무 알림이나 위험 카드 | `home_screen.dart:60`, `app_strings.dart:41` | 선택 지역 표시, 발령 중(ACTIVE) 알림 기준 |
| F10 | 독일어 `scanned_from` 에 베트남어 문장 | `translation_service.dart:298` | 수정 |
| F11 | 테스트 컴파일 실패(존재하지 않는 `MyApp`) | `test/widget_test.dart:16` | 테스트 재작성 |
| F12 | 빈 파일 4개(widgets), 미사용 서비스·모델·목업 페이지 | `widgets/*.dart`, `pages/myinfo/myinfo.dart` 등 | 공용 위젯으로 구현 또는 삭제 |
| F13 | 지역 변경이 홈·알림에 바로 반영 안 됨 | `settings_page.dart` 가 prefs 만 저장 | `SettingsProvider` |
| F14 | 안전 가이드 이미지 12장 15.6MB (웹 로딩 느림) | `assets/images` | 900px·256색 PNG → 2.9MB (같은 파일명·그림) |

## 3. 경쟁 서비스와 차별점 (발표 근거)

행정안전부 외국인용 앱 **Emergency Ready App** 은 2026-06-15 개편으로 지원 언어 3개 → 22개, 현위치 재난문자, 대피소 지도·길안내를 제공합니다([뉴시스 2026-06-14](https://www.newsis.com/view/NISX20260614_0003668232), [한국다문화뉴스 2026-09-21](https://www.kmcn.kr/news/article.html?no=9411)).
→ "다국어 재난문자" 자체는 차별점이 될 수 없으므로, ResQ 는 아래를 강조합니다. (공식 발표 자료에서 확인되지 않은 기능 기준이며, 발표 전 최신 앱을 직접 확인하세요.)

1. **구조대원용 응급정보 QR** — 외국인이 입력한 알레르기·질환·연락처를 한국어로 번역해 구급대원에게 보여줌 (원문 병기)
2. **119/112 신고 도우미** — 한국어 문장 카드 + 음성 재생 + 현재 위치 한국어 주소
3. **알림 → 행동요령 → 대피소 → 신고**를 한 흐름으로 연결
4. 대사관 연락처를 응급 흐름 안에서 바로 사용

참고 통계: 국내 체류외국인 273만 2,797명(2025년 6월 말), 국적 상위 중국·베트남·미국·태국·우즈베키스탄([헤럴드경제 2025-07-26](https://www.heraldk.com/article/2025072621211091744)).
