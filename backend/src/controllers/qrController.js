const crypto = require('crypto');
const pool = require('../db/db');
const config = require('../config');
const { getTranslator } = require('../services/translator');
const { renderResponderPage } = require('../views/responderPage');

/*
 * My Info (QR 응급정보)
 * 기존 엔드포인트 유지 + 버그 수정:
 *  - POST qr-profile 이 emergency_contacts / medical_infos 배열도 함께 저장 (기존: 무시되어 서버에 안 남음)
 *  - DELETE qr-profile 추가 (기존 앱은 name='' 로 POST → 400 으로 삭제 실패)
 *  - /api/users/:userId/... 는 기기 인증(X-Device-Id) 필요
 */

const BLOOD_TYPES = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
const MAX_CONTACTS = 3;
const MAX_MEDICAL = 20;

const str = (v, max) => (v === undefined || v === null ? null : String(v).trim().slice(0, max));
const qrUrl = (token) => `${config.publicBaseUrl}/e/${token}`;

function validateProfile(body) {
  const name = str(body.name, 100);
  if (!name) return { error: 'name은 필수입니다.' };
  const ageNum = body.age === undefined || body.age === null || body.age === '' ? null : Number(body.age);
  if (ageNum !== null && (!Number.isInteger(ageNum) || ageNum < 0 || ageNum > 130)) return { error: 'age 값이 올바르지 않습니다.' };
  const blood = str(body.blood_type, 5);
  if (blood && !BLOOD_TYPES.includes(blood)) return { error: 'blood_type 값이 올바르지 않습니다.' };
  const gender = str(body.gender, 10);
  return {
    value: {
      name,
      gender: gender || null,
      age: ageNum === 0 ? null : ageNum,
      blood_type: blood || null,
      nationality: str(body.nationality, 60) || null,
      language_code: str(body.language_code, 10) || null,
    },
  };
}

function normalizeContacts(list) {
  if (!Array.isArray(list)) return null;
  return list
    .map((c, i) => ({
      name: str(c?.name, 100), relationship: str(c?.relationship, 60) || null, phone: str(c?.phone, 40),
      priority: Number.isInteger(c?.priority) ? c.priority : i + 1,
    }))
    .filter((c) => c.name && c.phone)
    .slice(0, MAX_CONTACTS);
}

function normalizeMedical(list) {
  if (!Array.isArray(list)) return null;
  return list
    .map((m) => ({ category: str(m?.category, 20), value: str(m?.value, 200) }))
    .filter((m) => ['allergy', 'condition'].includes(m.category) && m.value)
    .slice(0, MAX_MEDICAL);
}

async function loadProfile(userId, { includeIds = true } = {}) {
  const [profiles] = await pool.query(
    `SELECT qr_token, name, gender, age, blood_type, nationality, language_code, updated_at
       FROM qr_profiles WHERE user_id = ? AND is_active = TRUE`,
    [userId],
  );
  if (profiles.length === 0) return null;
  const [contacts] = await pool.query(
    `SELECT ${includeIds ? 'id, ' : ''}name, relationship, phone, priority
       FROM emergency_contacts WHERE user_id = ? ORDER BY priority ASC, id ASC`,
    [userId],
  );
  const [medicals] = await pool.query(
    `SELECT ${includeIds ? 'id, ' : ''}category, value FROM medical_infos WHERE user_id = ? ORDER BY id ASC`,
    [userId],
  );
  return { ...profiles[0], emergency_contacts: contacts, medical_infos: medicals };
}

// POST /api/users/:userId/qr-profile - QR 프로필 등록/수정 (+ 연락처·의료정보 일괄 저장)
const upsertQrProfile = async (req, res) => {
  const userId = req.userId;
  const body = req.body || {};
  const { error, value } = validateProfile(body);
  if (error) return res.status(400).json({ error });

  const contacts = normalizeContacts(body.emergency_contacts);
  const medicals = normalizeMedical(body.medical_infos);

  const conn = await pool.getConnection();
  let qrToken;
  try {
    await conn.beginTransaction();
    const [existing] = await conn.query('SELECT qr_token FROM qr_profiles WHERE user_id = ? FOR UPDATE', [userId]);
    if (existing.length > 0) {
      qrToken = existing[0].qr_token;
      await conn.query(
        `UPDATE qr_profiles SET name = ?, gender = ?, age = ?, blood_type = ?, nationality = ?,
                language_code = ?, is_active = TRUE WHERE user_id = ?`,
        [value.name, value.gender, value.age, value.blood_type, value.nationality, value.language_code, userId],
      );
    } else {
      qrToken = crypto.randomUUID();
      await conn.query(
        `INSERT INTO qr_profiles (user_id, qr_token, name, gender, age, blood_type, nationality, language_code)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [userId, qrToken, value.name, value.gender, value.age, value.blood_type, value.nationality, value.language_code],
      );
    }

    // 배열을 보낸 경우에만 전체 교체 (보내지 않으면 기존 개별 API 로 관리된 값 유지 → 하위 호환)
    if (contacts) {
      await conn.query('DELETE FROM emergency_contacts WHERE user_id = ?', [userId]);
      if (contacts.length) {
        await conn.query(
          'INSERT INTO emergency_contacts (user_id, name, relationship, phone, priority) VALUES ?',
          [contacts.map((c) => [userId, c.name, c.relationship, c.phone, c.priority])],
        );
      }
    }
    if (medicals) {
      await conn.query('DELETE FROM medical_infos WHERE user_id = ?', [userId]);
      if (medicals.length) {
        await conn.query(
          'INSERT INTO medical_infos (user_id, category, value) VALUES ?',
          [medicals.map((m) => [userId, m.category, m.value])],
        );
      }
    }
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }

  res.status(201).json({ qr_token: qrToken, qr_url: qrUrl(qrToken) });
};

// GET /api/users/:userId/qr-profile - 내 정보 조회
const getMyProfile = async (req, res) => {
  const profile = await loadProfile(req.userId);
  if (!profile) return res.status(404).json({ error: '등록된 프로필이 없습니다.' });
  res.json({ ...profile, qr_url: qrUrl(profile.qr_token) });
};

// DELETE /api/users/:userId/qr-profile - 내 응급정보 전체 삭제 [NEW]
const deleteMyProfile = async (req, res) => {
  const userId = req.userId;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query('DELETE FROM emergency_contacts WHERE user_id = ?', [userId]);
    await conn.query('DELETE FROM medical_infos WHERE user_id = ?', [userId]);
    await conn.query('DELETE FROM qr_profiles WHERE user_id = ?', [userId]);
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
  res.json({ deleted: true });
};

async function loadByToken(qrToken) {
  if (!/^[0-9a-f-]{36}$/i.test(qrToken || '')) return null;
  const [rows] = await pool.query('SELECT user_id FROM qr_profiles WHERE qr_token = ? AND is_active = TRUE', [qrToken]);
  if (rows.length === 0) return null;
  const profile = await loadProfile(rows[0].user_id, { includeIds: false });
  if (profile) delete profile.qr_token;
  return profile;
}

/** 구조대원용: 자유 입력값(알레르기·질환·관계)을 한국어로 번역 (원문도 함께 표시) */
async function addKoreanTranslations(profile) {
  const texts = [
    ...profile.medical_infos.map((m) => m.value),
    ...profile.emergency_contacts.map((c) => c.relationship || ''),
    profile.nationality || '',
  ];
  const translated = await getTranslator().translateMany(texts, 'ko', 'auto');
  let i = 0;
  profile.medical_infos.forEach((m) => { m.value_ko = translated[i++] || null; });
  profile.emergency_contacts.forEach((c) => { c.relationship_ko = translated[i++] || null; });
  profile.nationality_ko = translated[i] || null;
  return profile;
}

// GET /api/qr/:qrToken - QR 스캔 결과 조회 (JSON, ?lang=ko 이면 한국어 번역 포함)
const getQrProfile = async (req, res) => {
  const profile = await loadByToken(req.params.qrToken);
  if (!profile) return res.status(404).json({ error: 'QR 정보를 찾을 수 없습니다.' });
  if (req.query.lang === 'ko') await addKoreanTranslations(profile);
  res.json(profile);
};

// GET /e/:qrToken - 구조대원용 웹페이지 (한국어 우선 + 영어 병기) [NEW]
const getResponderPage = async (req, res) => {
  const profile = await loadByToken(req.params.qrToken);
  res.set('Cache-Control', 'no-store');
  res.set('X-Robots-Tag', 'noindex, nofollow');
  if (!profile) return res.status(404).type('html').send(renderResponderPage(null));
  await addKoreanTranslations(profile);
  res.type('html').send(renderResponderPage(profile));
};

// ── 기존 개별 CRUD (하위 호환 유지) ─────────────────────────────
const addEmergencyContact = async (req, res) => {
  const { name, relationship, phone, priority } = req.body || {};
  if (!name || !phone) return res.status(400).json({ error: 'name과 phone은 필수입니다.' });
  const [[{ cnt }]] = await pool.query('SELECT COUNT(*) AS cnt FROM emergency_contacts WHERE user_id = ?', [req.userId]);
  if (cnt >= MAX_CONTACTS) return res.status(400).json({ error: `긴급 연락처는 최대 ${MAX_CONTACTS}개입니다.` });
  const [result] = await pool.query(
    'INSERT INTO emergency_contacts (user_id, name, relationship, phone, priority) VALUES (?, ?, ?, ?, ?)',
    [req.userId, str(name, 100), str(relationship, 60), str(phone, 40), priority || 1],
  );
  res.status(201).json({ id: result.insertId, name, phone });
};

const updateEmergencyContact = async (req, res) => {
  const { name, relationship, phone, priority } = req.body || {};
  const [result] = await pool.query(
    `UPDATE emergency_contacts
        SET name = COALESCE(?, name), relationship = COALESCE(?, relationship),
            phone = COALESCE(?, phone), priority = COALESCE(?, priority)
      WHERE id = ? AND user_id = ?`,
    [str(name, 100), str(relationship, 60), str(phone, 40), priority ?? null, req.params.id, req.userId],
  );
  if (result.affectedRows === 0) return res.status(404).json({ error: '연락처를 찾을 수 없습니다.' });
  res.json({ updated: true });
};

const deleteEmergencyContact = async (req, res) => {
  const [result] = await pool.query('DELETE FROM emergency_contacts WHERE id = ? AND user_id = ?', [req.params.id, req.userId]);
  if (result.affectedRows === 0) return res.status(404).json({ error: '연락처를 찾을 수 없습니다.' });
  res.json({ deleted: true });
};

const addMedicalInfo = async (req, res) => {
  const { category, value } = req.body || {};
  if (!category || !value) return res.status(400).json({ error: 'category와 value는 필수입니다.' });
  if (!['allergy', 'condition'].includes(category)) return res.status(400).json({ error: 'category는 allergy 또는 condition 입니다.' });
  const [result] = await pool.query(
    'INSERT INTO medical_infos (user_id, category, value) VALUES (?, ?, ?)',
    [req.userId, category, str(value, 200)],
  );
  res.status(201).json({ id: result.insertId, category, value });
};

const deleteMedicalInfo = async (req, res) => {
  const [result] = await pool.query('DELETE FROM medical_infos WHERE id = ? AND user_id = ?', [req.params.id, req.userId]);
  if (result.affectedRows === 0) return res.status(404).json({ error: '의료 정보를 찾을 수 없습니다.' });
  res.json({ deleted: true });
};

module.exports = {
  upsertQrProfile,
  getMyProfile,
  deleteMyProfile,
  getQrProfile,
  getResponderPage,
  addEmergencyContact,
  updateEmergencyContact,
  deleteEmergencyContact,
  addMedicalInfo,
  deleteMedicalInfo,
};
