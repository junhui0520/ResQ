import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/user_session.dart';

/// 알림 지역·알림 표시 설정 (기존 settings_page 의 SharedPreferences 키를 그대로 사용)
/// 홈/알림 화면이 지역 변경을 즉시 반영하도록 Provider 로 분리했습니다.
class SettingsProvider extends ChangeNotifier {
  static const _kAlert = 'setting_alert';
  static const _kSound = 'setting_sound';
  static const _kRegion = 'setting_region';
  static const _kRegionName = 'setting_region_name';

  bool _alertBanner = true; // 기존 'Emergency alerts' 토글
  bool _readAloud = true; // 기존 'Alert sound' 토글 → 위급·긴급 알림 음성 안내
  String _regionCode = 'ALL';
  String _regionNameEn = 'All Regions';

  bool get alertBanner => _alertBanner;
  bool get readAloud => _readAloud;
  String get regionCode => _regionCode;
  String get regionNameEn => _regionNameEn;
  String? get regionFilter => _regionCode == 'ALL' ? null : _regionCode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _alertBanner = prefs.getBool(_kAlert) ?? true;
    _readAloud = prefs.getBool(_kSound) ?? true;
    _regionCode = prefs.getString(_kRegion) ?? 'ALL';
    _regionNameEn = prefs.getString(_kRegionName) ?? 'All Regions';
    notifyListeners();
  }

  /// 서버에 저장된 설정 반영 (다른 기기·재설치 대비)
  Future<void> syncFromServer() async {
    final userId = UserSession.userId;
    if (userId == null) return;
    try {
      final data = await ApiClient.get('/users/$userId/settings');
      final prefs = await SharedPreferences.getInstance();
      _alertBanner = data['alert_enabled'] as bool? ?? _alertBanner;
      _readAloud = data['sound_enabled'] as bool? ?? _readAloud;
      _regionCode = data['selected_region_code'] as String? ?? 'ALL';
      await prefs.setBool(_kAlert, _alertBanner);
      await prefs.setBool(_kSound, _readAloud);
      await prefs.setString(_kRegion, _regionCode);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setAlertBanner(bool v) async {
    _alertBanner = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlert, v);
    _push({'alert_enabled': v});
  }

  Future<void> setReadAloud(bool v) async {
    _readAloud = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSound, v);
    _push({'sound_enabled': v});
  }

  Future<void> setRegion(String code, String nameEn, {double? lat, double? lng}) async {
    _regionCode = code;
    _regionNameEn = nameEn;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRegion, code);
    await prefs.setString(_kRegionName, nameEn);
    if (lat != null) await prefs.setDouble('setting_lat', lat);
    if (lng != null) await prefs.setDouble('setting_lng', lng);
    _push({'selected_region_code': code});
  }

  Future<void> syncLanguage(String lang) async => _push({'language_code': lang});

  Future<void> _push(Map<String, dynamic> body) async {
    final userId = UserSession.userId;
    if (userId == null) return;
    try {
      await ApiClient.put('/users/$userId/settings', body);
    } catch (_) {}
  }
}
