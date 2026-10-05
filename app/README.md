# ResQ 앱 (Flutter)

전체 설명은 저장소 루트의 [README.md](../README.md)를 보세요.

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
flutter analyze && flutter test
```

- `lib/core` — API 클라이언트, 기기 세션, 테마, 위치·음성·외부 앱 열기
- `lib/providers` — 언어(LanguageProvider), 설정(SettingsProvider), 새 알림 감시(AlertWatcher)
- `lib/services` — 서버 API 호출 (알림, 대사관, My Info, 대피소·주소, 데모)
- `lib/screens`, `lib/pages` — 화면 (기존 화면 디자인 유지 + 신규: 알림 상세, 긴급 문장, 대피소 지도, 첫 실행 언어 선택, 데모 모드)
- `assets/i18n` — UI 문구 (en 기준, ko·ja·zh·vi·de 검수본). 새 문구는 en.json 에 추가 후 `cd ../backend && npm run i18n:sync`
