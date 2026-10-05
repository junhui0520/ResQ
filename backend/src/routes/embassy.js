const express = require('express');
const router = express.Router();
const { getEmbassies } = require('../controllers/embassyController');

router.get('/', getEmbassies);

module.exports = router;
