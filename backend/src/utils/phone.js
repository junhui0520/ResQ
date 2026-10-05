/**
 * 대사관 전화번호 원문(예: '3785-1427, 749-8982/3', '051)465-5104/5/6')을
 * 바로 걸 수 있는 대표번호(예: '02-3785-1427', '051-465-5104')로 정규화합니다.
 * - 여러 번호가 있으면 첫 번호만 사용
 * - 지역번호가 없고 주소가 서울이면 02 를 붙임 (주소가 서울이 아니면 추측하지 않고 null)
 */
function normalizeEmbassyPhone(raw, address = '') {
  if (!raw) return null;
  const first = String(raw).split(/[,/~]| \/ /)[0].trim();
  if (!first) return null;

  const withArea = first.match(/^\(?(0\d{1,2})\)\s*(\d{3,4})-?(\d{4})$/); // 051)465-5104
  if (withArea) return `${withArea[1]}-${withArea[2]}-${withArea[3]}`;

  const full = first.match(/^(0\d{1,2})-(\d{3,4})-(\d{4})$/); // 010-6639-1150, 02-123-4567
  if (full) return `${full[1]}-${full[2]}-${full[3]}`;

  const local = first.match(/^(\d{3,4})-(\d{4})$/); // 3785-1427
  if (local && /seoul/i.test(address)) return `02-${local[1]}-${local[2]}`;

  return null;
}

/** 국기 이모지(지역 표시 문자 2개) → ISO 3166-1 alpha-2 */
function flagToCountryCode(flag) {
  const cps = [...String(flag || '')].map((c) => c.codePointAt(0));
  if (cps.length !== 2 || cps.some((cp) => cp < 0x1f1e6 || cp > 0x1f1ff)) return null;
  return cps.map((cp) => String.fromCharCode(cp - 0x1f1e6 + 65)).join('');
}

module.exports = { normalizeEmbassyPhone, flagToCountryCode };
