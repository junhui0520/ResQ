# ResQ REST API

기본 주소: `http://localhost:3000` (배포 시 `PUBLIC_BASE_URL`). 모든 응답은 JSON(UTF-8), 오류는 `{ "error": "메시지" }`.
`lang` 지원값: `en ko zh vi th uz ru ja ne id mn km tl my de` (그 외 → `en`).

## 인증

| 헤더 | 대상 | 설명 |
|---|---|---|
| `X-Device-Id` | `/api/users/:userId/...` | 앱이 처음 실행 때 만든 `device_uuid`. 해당 userId 와 일치해야 함 (401/403) |
| `X-Admin-Key` | `/api/admin/*`, `/api/disaster/fetch` | 서버 `ADMIN_KEY`. 미설정 시 503 |

요청 제한: `/api/*` IP 당 15분 600회.

## 재난 알림 (기존 경로 유지)

| 메서드·경로 | 설명 |
|---|---|
| `GET /api/alerts?lang=&region_code=&category_code=&status=&limit=&offset=` | 목록. `region_code` 는 상위 지역(천안→충남)과 전국(KR) 알림 포함 |
| `GET /api/alerts/recent?lang=&region_code=&limit=&since_id=` | 발령 중(ACTIVE) 최신 알림. `since_id` 이후 새 알림만 → 앱 실시간 배너 |
| `GET /api/alerts/nearby?lat=&lng=&radius=&lang=` | 좌표 반경(km) 내 지역 알림, `distance` 포함 |
| `GET /api/alerts/:id?lang=` | 단건 |
| `GET /api/alerts/categories` | 유형 코드·색상 |

알림 객체 (기존 필드 + 신규):

```json
{
  "id": 12, "region_code": "CHEONAN", "region_name": "Cheonan", "region_codes": ["CHEONAN","CHUNGNAM"],
  "region_text": "충청남도 천안시", "category_code": "RAIN", "category_label": "Rain / Typhoon", "color_hex": "#1565C0",
  "severity_code": "HIGH", "severity_label": "Emergency alert", "severity_level": 3,
  "emergency_step": "긴급재난", "disaster_type": "호우",
  "title": "(요청 언어 번역)", "content": "(요청 언어 번역)", "action_guide": "",
  "original_title": "(한국어 원문)", "original_content": "(한국어 원문)",
  "language": "vi", "translated": true, "translation_provider": "google",
  "status": "ACTIVE", "source": "SAFETYDATA", "issued_at": "2026-10-05T00:00:00.000Z", "resolved_at": null
}
```

- 번역 키가 없거나 일일 상한 초과 시 `translated:false`, `language:"ko"` 로 원문 반환
- `source`: `SAFETYDATA`(실제 재난문자) | `DEMO`(발표용, 본문 앞 `[ResQ 데모]`)
- `status`: 발송 후 `ALERT_ACTIVE_HOURS`(기본 24시간) 지나면 `RESOLVED`

## 사용자·설정·My Info

| 메서드·경로 | 설명 |
|---|---|
| `POST /api/users` `{device_uuid, language_code?, nationality?}` | 등록(이미 있으면 기존 user_id 반환) |
| `GET/PUT /api/users/:userId/settings` 🔒 | `alert_enabled, sound_enabled, location_enabled, selected_region_code, language_code` (PUT 은 보낸 항목만 수정, `ALL`=전체) |
| `POST /api/users/:userId/qr-profile` 🔒 | 응급정보 등록/수정. `emergency_contacts[]`(최대 3), `medical_infos[]`(`allergy`/`condition`) 를 보내면 전체 교체. 응답 `{qr_token, qr_url}` |
| `GET /api/users/:userId/qr-profile` 🔒 | 내 정보 (+`qr_url`) |
| `DELETE /api/users/:userId/qr-profile` 🔒 | 응급정보 전체 삭제 **[신규]** |
| `POST/PUT/DELETE /api/users/:userId/emergency-contacts[/:id]` 🔒 | 개별 연락처 (하위 호환) |
| `POST/DELETE /api/users/:userId/medical-infos[/:id]` 🔒 | 개별 의료정보 (하위 호환) |
| `GET /api/qr/:qrToken?lang=ko` | QR 응급정보 JSON (`lang=ko` 면 `value_ko`, `relationship_ko`, `nationality_ko` 추가) |
| `GET /e/:qrToken` | **구조대원용 웹페이지** (한국어 + 원문 병기, 전화 링크) **[신규]** |

🔒 = `X-Device-Id` 필요

## 장소·주소 [신규]

| 메서드·경로 | 설명 |
|---|---|
| `GET /api/shelters/nearby?lat=&lng=&radius_km=3&limit=20` | 주변 민방위 대피시설 (`distance_km` 순). `data_loaded:false` 면 서버에 데이터 미적재 |
| `GET /api/geo/reverse?lat=&lng=` | 한국어 주소(`address_ko`) + 알림 지역 코드(`region_code`). 대한민국 범위 밖이면 422 |

## 기타

| 메서드·경로 | 설명 |
|---|---|
| `GET /api/embassies?country=&lang=` | 대사관 (+`flag`, `phone_dial`, `email`, `name_translated`) |
| `GET /api/emergency-numbers` | 긴급전화 (+`hours`, `source_url`) |
| `GET /api/safety-manuals?lang=&category_code=` | 행동요령 (번역 없으면 영어) |
| `GET /api/regions` | 지역 목록 (+`parent_code`) |
| `GET /api/i18n/languages` | 지원 언어 목록 |
| `GET /api/i18n/:lang?keys=a,b` | 앱 UI 문구를 해당 언어로 (서버 캐시, `{n}` 자리표시자 보존, `keys` 로 일부만) **[신규]** |
| `GET /api/health` | 서버·DB 상태 |

## 관리자 🔑 (`X-Admin-Key`)

| 메서드·경로 | 설명 |
|---|---|
| `POST /api/disaster/fetch` | 재난문자 즉시 수집 |
| `GET /api/admin/stats` | 알림 수, 오늘 번역 글자 수, 대피소 수, 사용자 수 |
| `GET /api/admin/demo-presets` | 데모 알림 프리셋 (지진·호우·산불·폭염) |
| `POST /api/admin/demo-alert` `{preset}` 또는 `{message_ko, region_text|region_code, category_code, severity_code}` | 데모 알림 생성 |
| `DELETE /api/admin/demo-alerts` | 데모 알림 전체 삭제 |
| `POST /api/admin/import-shelters` | 민방위 대피시설 가져오기 |
