# 남은 2주 팀 할 일 (4명 기준 제안)

## 1주차 — 실행 환경·데이터·키

| 담당 | 할 일 | 완료 기준 |
|---|---|---|
| 백엔드 | `backend/.env` 작성, `docker compose up`, `npm run db:init`, `npm test` | `/api/health` ok, 테스트 27개 통과 |
| 백엔드 | 재난안전데이터 키로 `POST /api/disaster/fetch` 실행 | 실제 재난문자가 `/api/alerts?lang=ko` 에 보임 |
| 백엔드 | 민방위 대피시설 활용신청 → `npm run db:import-shelters` | 저장 건수 > 0 (0건이면 응답 예시 공유) |
| 앱 | `flutter pub get` → `flutter analyze` → `flutter test` → `flutter run -d chrome` | 오류 0, 모든 탭 동작 (오류 메시지는 리뷰 때 공유) |
| 데이터·번역 | Google Cloud 결제 연결 + Translation API 키 발급 | 알림 상세에 🌐 기계 번역 표시 |
| 데이터·번역 | `assets/i18n/ja·zh·vi·de.json` 에 신규 문구(약 100개) 추가 검수 (현재는 서버 기계 번역으로 채워짐) | 각 언어 원어민·유학생 1명 이상 검토 |
| 발표 | 정부 Emergency Ready App 설치·기능 조사, 차별점 표 작성 | 발표 슬라이드 1장 |

## 2주차 — 배포·촬영·발표

| 담당 | 할 일 |
|---|---|
| 백엔드 | Railway(또는 로컬) 배포, `PUBLIC_BASE_URL`·`CORS_ORIGINS` 설정 |
| 앱 | `flutter build web` → Firebase Hosting 배포, 휴대폰 브라우저에서 QR 스캔 확인 |
| 전원 | `docs/DEMO_SCENARIO.md` 순서로 리허설 2회, 촬영 |
| 발표 | 슬라이드: 문제 → 해결 → 데모 → 기술 → 차별점 → 한계와 향후 계획 |

## 발표 때 정직하게 말할 한계 (질문 대비)

- 번역은 기계 번역 → 한국어 원문을 항상 함께 제공
- 푸시 알림(앱이 꺼져 있을 때)은 미구현 — 웹은 앱이 열려 있을 때 60초 주기 확인
- 응급정보는 본인 입력 정보로 의학적으로 확인되지 않음 (화면에 명시)
- 대사관 목록은 기존 팀 자료 기반 — 최신 여부는 외교부 자료로 재확인 필요

## 향후 계획 아이디어 (발표용)

- FCM 푸시(Android), 오프라인 지도, 국립중앙의료원 응급실 실시간 병상 API 연동, 지자체 다국어 안내문 연계
