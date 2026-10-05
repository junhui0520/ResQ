require('dotenv').config({ quiet: true });

const num = (v, d) => (v === undefined || v === '' || Number.isNaN(Number(v)) ? d : Number(v));
const bool = (v, d) => (v === undefined || v === '' ? d : ['1', 'true', 'yes', 'on'].includes(String(v).toLowerCase()));

/**
 * 모든 환경변수는 이 파일에서만 읽습니다. (.env.example 참고)
 */
const config = {
  env: process.env.NODE_ENV || 'development',
  port: num(process.env.PORT, 3000),
  // QR 응급정보 페이지 링크에 쓰이는 "외부에서 접속 가능한" 서버 주소
  publicBaseUrl: (process.env.PUBLIC_BASE_URL || process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, ''),
  corsOrigins: (process.env.CORS_ORIGINS || '*').split(',').map((s) => s.trim()).filter(Boolean),

  // DB_* 가 없으면 Railway MySQL 서비스 변수(MYSQLHOST 등)를 사용
  db: {
    host: process.env.DB_HOST || process.env.MYSQLHOST || '127.0.0.1',
    port: num(process.env.DB_PORT || process.env.MYSQLPORT, 3306),
    user: process.env.DB_USER || process.env.MYSQLUSER || 'resq',
    password: process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
    database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'resq',
  },

  // 서버 시작 시 테이블이 없으면 자동으로 db:init 실행 (Railway 처럼 명령 실행이 번거로운 환경용)
  dbAutoInit: bool(process.env.DB_AUTO_INIT, true),

  // Flutter 웹 빌드 결과 폴더. index.html 이 있으면 서버가 앱 화면도 함께 제공 (링크 하나로 앱+API)
  webDir: process.env.WEB_DIR || require('path').resolve(__dirname, '..', 'public'),

  adminKey: process.env.ADMIN_KEY || '',

  disaster: {
    apiKey: process.env.DISASTER_API_KEY || '',
    url: process.env.DISASTER_API_URL || 'https://www.safetydata.go.kr/V2/api/DSSP-IF-00247',
    schedulerEnabled: bool(process.env.DISASTER_SCHEDULER_ENABLED, true),
    cron: process.env.DISASTER_CRON || '*/5 * * * *',
    pageSize: num(process.env.DISASTER_PAGE_SIZE, 100),
    maxPages: num(process.env.DISASTER_MAX_PAGES, 10),
    activeHours: num(process.env.ALERT_ACTIVE_HOURS, 24),
  },

  shelter: {
    apiKey: process.env.SHELTER_API_KEY || process.env.DISASTER_API_KEY || '',
    url: process.env.SHELTER_API_URL || 'https://www.safetydata.go.kr/V2/api/DSSP-IF-00195',
    // 대피소 데이터가 비어 있을 때 사용자 위치 주변에 [샘플] 대피소를 보여줄지 (시연용)
    sampleMode: String(process.env.SHELTER_SAMPLE_MODE || 'false').toLowerCase() === 'true',
  },

  translation: {
    // google | none
    provider: process.env.TRANSLATE_PROVIDER || (process.env.GOOGLE_TRANSLATE_API_KEY ? 'google' : 'none'),
    googleApiKey: process.env.GOOGLE_TRANSLATE_API_KEY || '',
    // 무료 크레딧(월 50만 자)을 넘지 않도록 하루 상한 (기본 15,000자 × 30일 = 45만 자)
    dailyCharLimit: num(process.env.TRANSLATE_DAILY_CHAR_LIMIT, 15000),
  },

  geocoder: {
    // nominatim | none
    provider: process.env.GEOCODER_PROVIDER || 'nominatim',
    nominatimUrl: process.env.NOMINATIM_URL || 'https://nominatim.openstreetmap.org/reverse',
    contactEmail: process.env.CONTACT_EMAIL || '',
  },
};

module.exports = config;
