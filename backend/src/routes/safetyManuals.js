const express = require('express');
const router = express.Router();
const { getSafetyManuals } = require('../controllers/safetyController');

router.get('/', getSafetyManuals);

module.exports = router;