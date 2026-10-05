import '../core/api_client.dart';

/// 발표용 데모 기능 (서버 ADMIN_KEY 필요). 설정 화면의 숨은 메뉴에서만 사용합니다.
class AdminService {
  static Map<String, String> _h(String key) => {'X-Admin-Key': key};

  static Future<List<Map<String, dynamic>>> presets(String key) async {
    final res = await ApiClient.get('/admin/demo-presets', headers: _h(key));
    return (res['presets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  static Future<void> sendDemoAlert(String key, String preset) async {
    await ApiClient.post('/admin/demo-alert', {'preset': preset}, headers: _h(key));
  }

  static Future<int> clearDemoAlerts(String key) async {
    final res = await ApiClient.delete('/admin/demo-alerts', headers: _h(key));
    return (res['deleted'] as num?)?.toInt() ?? 0;
  }

  static Future<Map<String, dynamic>> fetchNow(String key) =>
      ApiClient.post('/disaster/fetch', {}, headers: _h(key));

  static Future<Map<String, dynamic>> stats(String key) => ApiClient.get('/admin/stats', headers: _h(key));
}
