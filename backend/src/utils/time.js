/**
 * KST(UTC+9) 날짜 유틸. 서버 OS 시간대와 무관하게 동작합니다.
 */
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** 현재 KST 기준 YYYYMMDD */
function kstYmd(date = new Date(), dayOffset = 0) {
  const d = new Date(date.getTime() + KST_OFFSET_MS + dayOffset * 86400000);
  return d.toISOString().slice(0, 10).replace(/-/g, '');
}

/** 현재 KST 시(0~23) */
function kstHour(date = new Date()) {
  return new Date(date.getTime() + KST_OFFSET_MS).getUTCHours();
}

/** KST 기준 YYYY-MM-DD */
function kstDate(date = new Date()) {
  return new Date(date.getTime() + KST_OFFSET_MS).toISOString().slice(0, 10);
}

/**
 * 재난문자 API 의 생성일시(CRT_DT) 문자열을 Date 로 변환.
 * '2026/07/10 13:22:05', '2026-07-10 13:22:05', '20260710132205' 등 숫자만 뽑아 KST 로 해석.
 * 해석할 수 없으면 null.
 */
function parseKstDateTime(value) {
  if (value instanceof Date) return value;
  if (value === undefined || value === null) return null;
  const digits = String(value).replace(/\D/g, '');
  if (digits.length < 12) return null;
  const [y, mo, d, h, mi] = [digits.slice(0, 4), digits.slice(4, 6), digits.slice(6, 8), digits.slice(8, 10), digits.slice(10, 12)];
  const s = digits.length >= 14 ? digits.slice(12, 14) : '00';
  const iso = `${y}-${mo}-${d}T${h}:${mi}:${s}+09:00`;
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? null : date;
}

module.exports = { kstYmd, kstHour, kstDate, parseKstDateTime };
