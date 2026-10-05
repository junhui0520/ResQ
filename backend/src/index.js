const fs = require('fs');
const path = require('path');
const config = require('./config');
const { createApp } = require('./app');
const { startDisasterScheduler } = require('./controllers/disasterController');
const { getTranslator } = require('./services/translator');
const { autoInitDatabase } = require('./db/initDb');

async function main() {
  // 테이블이 없으면 자동 초기화 (Railway 첫 배포 등). 이미 있으면 아무것도 하지 않음
  if (config.dbAutoInit) await autoInitDatabase();

  const app = createApp();
  app.listen(config.port, () => {
    const hasWeb = fs.existsSync(path.join(config.webDir, 'index.html'));
    console.log(`✅ 서버 실행 중: http://localhost:${config.port}`);
    console.log(`   앱 화면: ${hasWeb ? `제공 중 (${config.webDir})` : '없음 (backend/public 에 Flutter 웹 빌드를 넣으면 / 에서 앱 제공)'}`);
    console.log(`   번역: ${getTranslator().isEnabled() ? 'Google Cloud Translation' : '비활성화 (GOOGLE_TRANSLATE_API_KEY 없음 → 원문 표시)'}`);
    console.log(`   관리자 기능: ${config.adminKey ? '활성화' : '비활성화 (ADMIN_KEY 없음)'}`);
    startDisasterScheduler();
  });
}

main();
