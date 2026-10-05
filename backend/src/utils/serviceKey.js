/**
 * 공공데이터 인증키는 '인코딩' 키(%2B 등 포함)와 '디코딩' 키 두 형태로 발급됩니다.
 * URLSearchParams 가 다시 인코딩하므로, 인코딩된 키가 들어오면 먼저 디코딩합니다.
 */
function normalizeServiceKey(key) {
  if (!key) return '';
  if (/%[0-9A-Fa-f]{2}/.test(key)) {
    try { return decodeURIComponent(key); } catch { return key; }
  }
  return key;
}

module.exports = { normalizeServiceKey };
