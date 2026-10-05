const express = require('express');
const router = express.Router();
const { fetchAndSaveDisasterAlerts } = require('../controllers/disasterController');
const { requireAdmin } = require('../middleware/auth');

// 수동으로 즉시 재난문자 데이터 가져오기 (관리자 키 필요: X-Admin-Key)
router.post('/fetch', requireAdmin, async (req, res) => {
  try {
    const result = await fetchAndSaveDisasterAlerts();
    res.json({ success: true, message: '재난문자 데이터 가져오기 완료', ...result });
  } catch (error) {
    res.status(502).json({ success: false, message: error.message });
  }
});

module.exports = router;
