const express = require('express');
const router = express.Router();
const { getReverse } = require('../controllers/geoController');

router.get('/reverse', getReverse);

module.exports = router;
