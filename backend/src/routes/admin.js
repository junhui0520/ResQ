const express = require('express');
const router = express.Router();
const { requireAdmin } = require('../middleware/auth');
const {
  getDemoPresets, createDemoAlert, clearDemoAlerts, runShelterImport, getStats,
} = require('../controllers/adminController');

router.use(requireAdmin);
router.get('/stats', getStats);
router.get('/demo-presets', getDemoPresets);
router.post('/demo-alert', createDemoAlert);
router.delete('/demo-alerts', clearDemoAlerts);
router.post('/import-shelters', runShelterImport);

module.exports = router;
