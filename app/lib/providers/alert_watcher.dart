import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/alert_service.dart';

/// 새 재난 알림 감시 (웹 데모용 앱 내 실시간 배너)
/// 60초마다 내 지역의 발령 중 알림을 확인하고, 처음 보는 알림이면 newAlert 로 알려줍니다.
/// (푸시 알림(FCM) 대신 사용 — 웹·2주 일정 조건)
class AlertWatcher extends ChangeNotifier {
  static const _kLastSeen = 'alert_last_seen_id';
  static const pollInterval = Duration(seconds: 60);

  Timer? _timer;
  int _lastSeenId = 0;
  String _lang = 'en';
  String? _region;
  bool _enabled = true;
  AlertModel? _newAlert;
  int _refreshTick = 0;
  bool _primed = false; // 첫 확인 완료 여부

  AlertModel? get newAlert => _newAlert;

  /// 새 알림이 도착할 때마다 증가 → 홈/알림 화면이 목록을 새로고침
  int get refreshTick => _refreshTick;

  Future<void> start({required String lang, String? region, required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeenId = prefs.getInt(_kLastSeen) ?? 0;
    configure(lang: lang, region: region, enabled: enabled);
  }

  void configure({required String lang, String? region, required bool enabled}) {
    final changed = lang != _lang || region != _region || enabled != _enabled;
    _lang = lang;
    _region = region;
    _enabled = enabled;
    if (_timer == null || changed) {
      _timer?.cancel();
      _timer = Timer.periodic(pollInterval, (_) => check());
      check();
    }
  }

  /// 즉시 확인 (데모 알림을 보낸 직후 등)
  Future<void> check() async {
    try {
      final alerts = await AlertService.fetchRecent(
        lang: _lang,
        regionCode: _region,
        limit: 5,
        sinceId: _lastSeenId > 0 ? _lastSeenId : null,
      );
      final fresh = alerts.where((a) => a.id > _lastSeenId).toList();
      if (fresh.isEmpty) {
        _primed = true;
        return;
      }
      final latest = fresh.first; // 발송 시각 최신순
      final maxId = fresh.map((a) => a.id).reduce((a, b) => a > b ? a : b);
      // 앱을 처음 설치하고 첫 확인 때 이미 있던 알림은 배너로 띄우지 않음 (목록에는 표시)
      final showBanner = _enabled && (_primed || _lastSeenId > 0);
      _primed = true;
      _lastSeenId = maxId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSeen, maxId);
      _refreshTick++;
      if (showBanner) _newAlert = latest;
      notifyListeners();
    } catch (_) {
      // 오프라인 등 → 다음 주기에 재시도
    }
  }

  void dismiss() {
    _newAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
