const express = require('express');
const router = express.Router();
const { getNearbyShelters } = require('../controllers/shelterController');

router.get('/nearby', getNearbyShelters);

module.exports = router;
