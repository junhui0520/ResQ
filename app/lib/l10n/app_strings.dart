/// 지원 언어 목록
/// - 기존 5개(en, ja, zh, vi, de) + 한국어 + 국내 체류외국인 주요 국적·1345 상담 언어 기준 9개 추가
/// - UI 문구는 assets/i18n/<언어>.json (사람이 검수한 번역) 을 우선 사용하고,
///   파일이 없거나 빠진 문구는 서버(/api/i18n/<언어>)의 기계 번역으로 채웁니다.
class AppStrings {
  static const String baseLanguage = 'en';

  /// assets/i18n 에 파일이 있는 언어 (검수 번역)
  static const Set<String> curatedLanguages = {'en', 'ko', 'ja', 'zh', 'vi', 'de'};

  static const Map<String, String> languageNames = {
    'en': 'English',
    'ko': '한국어',
    'zh': '中文(简体)',
    'vi': 'Tiếng Việt',
    'th': 'ไทย',
    'uz': 'Oʻzbekcha',
    'ru': 'Русский',
    'ja': '日本語',
    'ne': 'नेपाली',
    'id': 'Bahasa Indonesia',
    'mn': 'Монгол',
    'km': 'ខ្មែរ',
    'tl': 'Filipino',
    'my': 'မြန်မာ',
    'de': 'Deutsch',
  };

  static const Map<String, String> languageFlags = {
    'en': '🇺🇸',
    'ko': '🇰🇷',
    'zh': '🇨🇳',
    'vi': '🇻🇳',
    'th': '🇹🇭',
    'uz': '🇺🇿',
    'ru': '🇷🇺',
    'ja': '🇯🇵',
    'ne': '🇳🇵',
    'id': '🇮🇩',
    'mn': '🇲🇳',
    'km': '🇰🇭',
    'tl': '🇵🇭',
    'my': '🇲🇲',
    'de': '🇩🇪',
  };

  /// 음성 읽기(TTS)용 로캘
  static const Map<String, String> ttsLocales = {
    'en': 'en-US',
    'ko': 'ko-KR',
    'zh': 'zh-CN',
    'vi': 'vi-VN',
    'th': 'th-TH',
    'uz': 'uz-UZ',
    'ru': 'ru-RU',
    'ja': 'ja-JP',
    'ne': 'ne-NP',
    'id': 'id-ID',
    'mn': 'mn-MN',
    'km': 'km-KH',
    'tl': 'fil-PH',
    'my': 'my-MM',
    'de': 'de-DE',
  };
}
