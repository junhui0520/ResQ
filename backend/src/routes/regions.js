const express = require('express');
const router = express.Router();
const { getRegions } = require('../controllers/safetyController');

router.get('/', getRegions);

module.exports = router;