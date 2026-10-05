/**
 * 지원 언어 (앱 설정 화면과 동일한 목록)
 * 선정 근거: 국내 체류외국인 국적 상위(중국·베트남·미국·태국·우즈베키스탄 …) +
 *            외국인종합안내센터(1345) 상담 언어 + 기존 앱 언어(ja, de) 유지
 * curated: 앱 assets/i18n/<code>.json 에 사람이 검수한 번역이 있는 언어
 */
const LANGUAGES = [
  { code: 'en', name: 'English', flag: '🇺🇸', curated: true },
  { code: 'ko', name: '한국어', flag: '🇰🇷', curated: true },
  { code: 'zh', name: '中文(简体)', flag: '🇨🇳', curated: true },
  { code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳', curated: true },
  { code: 'th', name: 'ไทย', flag: '🇹🇭', curated: false },
  { code: 'uz', name: 'Oʻzbekcha', flag: '🇺🇿', curated: false },
  { code: 'ru', name: 'Русский', flag: '🇷🇺', curated: false },
  { code: 'ja', name: '日本語', flag: '🇯🇵', curated: true },
  { code: 'ne', name: 'नेपाली', flag: '🇳🇵', curated: false },
  { code: 'id', name: 'Bahasa Indonesia', flag: '🇮🇩', curated: false },
  { code: 'mn', name: 'Монгол', flag: '🇲🇳', curated: false },
  { code: 'km', name: 'ខ្មែរ', flag: '🇰🇭', curated: false },
  { code: 'tl', name: 'Filipino', flag: '🇵🇭', curated: false },
  { code: 'my', name: 'မြန်မာ', flag: '🇲🇲', curated: false },
  { code: 'de', name: 'Deutsch', flag: '🇩🇪', curated: true },
];

const CODES = new Set(LANGUAGES.map((l) => l.code));
const isSupported = (code) => CODES.has(code);

module.exports = { LANGUAGES, isSupported };
