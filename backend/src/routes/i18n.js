const express = require('express');
const router = express.Router();
const { getLanguages, getStrings } = require('../controllers/i18nController');

router.get('/languages', getLanguages);
router.get('/:lang', getStrings);

module.exports = router;
