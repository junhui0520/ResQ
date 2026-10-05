@echo off
REM ResQ: build the Flutter web app and copy it to backend\public
REM The backend then serves the app at / and the API at /api (one link on Railway).
REM Usage: double-click, or run "build-web.cmd" in the ResQ-complete folder.
setlocal
cd /d "%~dp0app" || exit /b 1
call flutter build web --release --dart-define=API_BASE_URL=/api
if errorlevel 1 (
  echo [ERROR] flutter build web failed.
  exit /b 1
)
cd /d "%~dp0"
if exist backend\public rmdir /s /q backend\public
xcopy /e /i /q /y app\build\web backend\public >nul
if errorlevel 1 (
  echo [ERROR] copy to backend\public failed.
  exit /b 1
)
echo.
echo [OK] Web app copied to backend\public
echo Next: docker compose up -d --build api  then open http://localhost:3000
endlocal
