import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';

/// 앱 최초 실행 시 device_uuid 생성 + 서버 유저 등록
/// device_uuid 는 이 기기만 아는 값이라 내 정보 API 요청 인증(X-Device-Id)에도 사용합니다.
class UserSession {
  static const _uuidKey = 'device_uuid';
  static const _userIdKey = 'user_id';

  static String? _deviceUuid;
  static int? _userId;

  static String? get deviceUuid => _deviceUuid;
  static int? get userId => _userId;

  /// 앱 시작 시 한 번만 호출
  static Future<void> init({String languageCode = 'en'}) async {
    final prefs = await SharedPreferences.getInstance();

    _deviceUuid = prefs.getString(_uuidKey);
    if (_deviceUuid == null) {
      _deviceUuid = const Uuid().v4();
      await prefs.setString(_uuidKey, _deviceUuid!);
    }
    ApiClient.deviceId = _deviceUuid;

    _userId = prefs.getInt(_userIdKey);
    await register(languageCode: languageCode);
  }

  /// 서버 등록 (이미 등록됐으면 기존 userId 반환). 실패해도 앱은 계속 실행.
  static Future<bool> register({String languageCode = 'en'}) async {
    if (_deviceUuid == null) return false;
    try {
      final res = await ApiClient.post('/users', {
        'device_uuid': _deviceUuid,
        'language_code': languageCode,
      });
      final id = res['user_id'];
      if (id is int) {
        _userId = id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_userIdKey, id);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 서버 연결이 늦게 된 경우 필요할 때 다시 등록 시도
  static Future<int?> ensureUserId() async {
    if (_userId != null) return _userId;
    await register();
    return _userId;
  }
}
