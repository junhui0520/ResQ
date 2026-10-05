import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../l10n/app_strings.dart';

/// 앱 언어 관리
/// 기존 구조(t(key) 로 번역 문구 조회, setLanguage, currentLang …)는 그대로 두고
/// 하드코딩 맵 대신 언어별 JSON 파일 + 서버 기계 번역을 사용하도록 바꿨습니다.
///
/// 우선순위: 검수 번역(assets) > 서버 기계 번역 > 영어 원문
class LanguageProvider extends ChangeNotifier {
  static const _prefLang = 'app_language';
  static const _prefOnboarded = 'onboarding_done';

  String _currentLang = AppStrings.baseLanguage;
  bool _isLoading = false;
  bool _usesMachineTranslation = false;
  bool _onboarded = true;
  Map<String, String> _base = {};
  Map<String, String> _strings = {};

  String get currentLang => _currentLang;
  bool get isLoading => _isLoading;
  bool get usesMachineTranslation => _usesMachineTranslation;
  bool get onboarded => _onboarded;
  String get currentLangName => AppStrings.languageNames[_currentLang] ?? 'English';
  String get currentFlag => AppStrings.languageFlags[_currentLang] ?? '🇺🇸';
  String get ttsLocale => AppStrings.ttsLocales[_currentLang] ?? 'en-US';

  /// 번역된 텍스트 반환 (키 없으면 영어 → 키 자체)
  String t(String key) => _strings[key] ?? _base[key] ?? key;

  /// 자리표시자 치환: tf('time_min_ago', {'n': 5}) → "5 min ago"
  String tf(String key, Map<String, Object> args) {
    var s = t(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  /// 테스트용: 기준 문구 직접 주입
  @visibleForTesting
  void debugSetStrings(Map<String, String> base, {Map<String, String>? overrides}) {
    _base = Map.of(base);
    _strings = {...base, ...?overrides};
  }

  /// 앱 시작 시 저장된 언어 불러오기
  Future<void> init() async {
    _base = await _loadAsset(AppStrings.baseLanguage) ?? {};
    _strings = Map.of(_base);
    final prefs = await SharedPreferences.getInstance();
    _onboarded = prefs.getBool(_prefOnboarded) ?? prefs.containsKey(_prefLang);
    final savedLang = prefs.getString(_prefLang) ?? AppStrings.baseLanguage;
    if (savedLang != AppStrings.baseLanguage) {
      await setLanguage(savedLang, force: true);
    }
  }

  Future<void> completeOnboarding() async {
    _onboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefOnboarded, true);
    await prefs.setString(_prefLang, _currentLang);
    notifyListeners();
  }

  /// 언어 변경
  Future<void> setLanguage(String langCode, {bool force = false}) async {
    if (!force && langCode == _currentLang) return;
    if (!AppStrings.languageNames.containsKey(langCode)) return;

    _isLoading = true;
    notifyListeners();

    try {
      final curated = await _loadAsset(langCode) ?? {};
      Map<String, String> machine = {};
      final missing = _base.keys.where((k) => !curated.containsKey(k)).toList();
      if (langCode != AppStrings.baseLanguage && missing.isNotEmpty) {
        // 검수 번역이 있는 언어는 빠진 문구만 요청 (번역 비용 절감)
        machine = await _loadMachineTranslation(langCode, keys: curated.isEmpty ? null : missing);
      }
      _strings = {..._base, ...machine, ...curated};
      _usesMachineTranslation = missing.any((k) => machine.containsKey(k));
      _currentLang = langCode;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLang, langCode);
    } catch (_) {
      // 실패 시 영어 유지
      _strings = Map.of(_base);
      _currentLang = AppStrings.baseLanguage;
      _usesMachineTranslation = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, String>?> _loadAsset(String lang) async {
    if (!AppStrings.curatedLanguages.contains(lang)) return null;
    try {
      final raw = await rootBundle.loadString('assets/i18n/$lang.json');
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// 서버 기계 번역 (기기에 캐시 → 오프라인에서도 사용)
  /// 캐시가 있으면 바로 쓰고 서버 최신본은 뒤에서 받아 반영합니다. (서버가 느려도 앱 시작이 막히지 않음)
  Future<Map<String, String>> _loadMachineTranslation(String lang, {List<String>? keys}) async {
    final cached = await _readCache(lang);
    if (cached.isNotEmpty) {
      _refreshInBackground(lang, keys: keys);
      return cached;
    }
    return await _fetchAndCache(lang, keys: keys) ?? {};
  }

  Future<Map<String, String>> _readCache(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('i18n_cache_$lang');
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return Map<String, String>.from(m['strings'] as Map);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>?> _fetchAndCache(String lang, {List<String>? keys}) async {
    try {
      final res = await ApiClient.get('/i18n/$lang', queryParams: keys == null ? null : {'keys': keys.join(',')});
      final strings = Map<String, String>.from(res['strings'] as Map? ?? {});
      if (strings.isEmpty) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('i18n_cache_$lang', jsonEncode({'version': res['base_version'], 'strings': strings}));
      return strings;
    } catch (_) {
      return null; // 서버 연결 실패
    }
  }

  Future<void> _refreshInBackground(String lang, {List<String>? keys}) async {
    final fresh = await _fetchAndCache(lang, keys: keys);
    if (fresh == null || lang != _currentLang) return;
    final curated = await _loadAsset(lang) ?? {};
    _strings = {..._base, ...fresh, ...curated};
    notifyListeners();
  }
}
