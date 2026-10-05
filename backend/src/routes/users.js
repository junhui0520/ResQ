const express = require('express');
const router = express.Router();
const { createUser, getSettings, updateSettings } = require('../controllers/usersController');
const {
  upsertQrProfile,
  getMyProfile,
  deleteMyProfile,
  addEmergencyContact,
  updateEmergencyContact,
  deleteEmergencyContact,
  addMedicalInfo,
  deleteMedicalInfo,
} = require('../controllers/qrController');
const { requireDeviceOwner } = require('../middleware/auth');

router.post('/', createUser);

// 아래는 모두 본인 기기만 접근 가능 (X-Device-Id 헤더)
router.get('/:userId/settings', requireDeviceOwner, getSettings);
router.put('/:userId/settings', requireDeviceOwner, updateSettings);
router.post('/:userId/qr-profile', requireDeviceOwner, upsertQrProfile);
router.get('/:userId/qr-profile', requireDeviceOwner, getMyProfile);
router.delete('/:userId/qr-profile', requireDeviceOwner, deleteMyProfile);
router.post('/:userId/emergency-contacts', requireDeviceOwner, addEmergencyContact);
router.put('/:userId/emergency-contacts/:id', requireDeviceOwner, updateEmergencyContact);
router.delete('/:userId/emergency-contacts/:id', requireDeviceOwner, deleteEmergencyContact);
router.post('/:userId/medical-infos', requireDeviceOwner, addMedicalInfo);
router.delete('/:userId/medical-infos/:id', requireDeviceOwner, deleteMedicalInfo);

module.exports = router;
