const express = require('express');
const router = express.Router();
const { getEmergencyNumbers } = require('../controllers/embassyController');

router.get('/', getEmergencyNumbers);

module.exports = router;