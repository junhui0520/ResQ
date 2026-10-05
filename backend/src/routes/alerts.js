const express = require('express');
const router = express.Router();
const { getAlerts, getCategories, getAlertById, getRecentAlerts, getNearbyAlerts } = require('../controllers/alertsController');

router.get('/categories', getCategories);
router.get('/recent', getRecentAlerts);
router.get('/nearby', getNearbyAlerts); // ✅ 추가
router.get('/:id', getAlertById);
router.get('/', getAlerts);

module.exports = router;