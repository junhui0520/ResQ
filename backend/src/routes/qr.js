const express = require('express');
const router = express.Router();
const { getQrProfile } = require('../controllers/qrController');

// QR 토큰(추측 불가능한 UUID)을 아는 사람만 조회 가능
router.get('/:qrToken', getQrProfile);

module.exports = router;
