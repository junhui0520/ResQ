const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const config = require('./config');
const pool = require('./db/db');
const { getResponderPage } = require('./controllers/qrController');

/**
 * Express 앱 생성 (서버 실행은 index.js, 테스트는 이 함수를 직접 사용)
 */
function createApp() {
  const app = express();
  app.set('trust proxy', 1); // Railway 등 프록시 뒤에서 실제 IP 로 요청 제한

  // API·구조대원 페이지: helmet 기본 보안 헤더(CSP 포함)
  // 앱 화면(Flutter 웹): CanvasKit(WebAssembly)·글꼴·지도 타일을 외부에서 불러오므로 CSP 만 끄고 나머지 헤더 유지
  const apiHelmet = helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } });
  const webHelmet = helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } });
  const isServerPath = (p) => p.startsWith('/api') || p.startsWith('/e/');
  app.use((req, res, next) => (isServerPath(req.path) ? apiHelmet : webHelmet)(req, res, next));
  app.use(cors({
    origin: config.corsOrigins.includes('*') ? true : config.corsOrigins,
    allowedHeaders: ['Content-Type', 'X-Device-Id', 'X-Admin-Key'],
  }));
  app.use(express.json({ limit: '100kb' }));

  // 요청 로그 (기존 코드는 라우터 뒤에 등록되어 실제로 동작하지 않았음)
  if (config.env !== 'test') {
    app.use((req, res, next) => {
      const started = Date.now();
      res.on('finish', () => {
        console.log(`[${new Date().toLocaleTimeString('ko-KR', { timeZone: 'Asia/Seoul' })}] ${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - started}ms`);
      });
      next();
    });
  }

  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: config.env === 'test' ? 10000 : 600,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
  });
  app.use('/api', limiter);

  const webDir = config.webDir;
  const hasWeb = fs.existsSync(path.join(webDir, 'index.html'));

  // 앱 화면이 없을 때만 / 에서 서버 상태 안내 (앱이 있으면 / 는 앱 화면)
  if (!hasWeb) {
    app.get('/', (req, res) => {
      res.json({ message: 'resQ API 서버 정상 작동 중 🚀', version: '2.0.0' });
    });
  }

  app.get('/api/health', async (req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({ status: 'ok', db: 'ok' });
    } catch (err) {
      res.status(503).json({ status: 'error', db: 'unreachable' });
    }
  });

  // 기존 라우터 (경로 유지)
  app.use('/api/alerts', require('./routes/alerts'));
  app.use('/api/users', require('./routes/users'));
  app.use('/api/qr', require('./routes/qr'));
  app.use('/api/embassies', require('./routes/embassy'));
  app.use('/api/emergency-numbers', require('./routes/emergencyNumbers'));
  app.use('/api/safety-manuals', require('./routes/safetyManuals'));
  app.use('/api/regions', require('./routes/regions'));
  app.use('/api/disaster', require('./routes/disaster'));

  // 신규 라우터
  app.use('/api/shelters', require('./routes/shelters'));
  app.use('/api/geo', require('./routes/geo'));
  app.use('/api/i18n', require('./routes/i18n'));
  app.use('/api/admin', require('./routes/admin'));
  app.get('/e/:qrToken', getResponderPage); // 구조대원용 응급정보 페이지

  // Flutter 웹 앱 (backend/public). 같은 주소에서 앱과 API 를 함께 제공 → 링크 하나로 공유
  if (hasWeb) {
    // 새로 배포하면 바로 반영되도록 시작 파일은 캐시하지 않음
    const noCache = new Set(['index.html', 'flutter_bootstrap.js', 'flutter_service_worker.js', 'version.json', 'manifest.json']);
    app.use(express.static(webDir, {
      index: 'index.html',
      setHeaders: (res, filePath) => {
        if (noCache.has(path.basename(filePath))) res.setHeader('Cache-Control', 'no-cache');
      },
    }));
    // 그 밖의 화면 주소는 앱(index.html)으로 (API·QR 경로 제외)
    app.get(/^(?!\/api(?:\/|$)|\/e\/).*/, (req, res, next) => {
      if (!req.accepts('html')) return next();
      res.setHeader('Cache-Control', 'no-cache');
      res.sendFile(path.join(webDir, 'index.html'));
    });
  }

  app.use((req, res) => res.status(404).json({ error: '존재하지 않는 경로입니다.' }));

  // Express 5: async 핸들러의 예외도 여기로 전달됨
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: '잘못된 JSON 형식입니다.' });
    console.error(err);
    res.status(500).json({ error: '서버 오류가 발생했습니다.' });
  });

  return app;
}

module.exports = { createApp };
