import 'dart:convert';
import 'package:http/http.dart' as http;

/// 서버 오류를 구분하기 위한 예외 (statusCode 로 404 등 판별)
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API 오류 $statusCode: $message';
}

class ApiClient {
  /// 서버 주소는 빌드할 때 지정합니다. (코드 수정 불필요)
  ///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
  ///   flutter build web --dart-define=API_BASE_URL=https://<배포주소>/api
  ///   flutter build web --dart-define=API_BASE_URL=/api   ← 백엔드가 앱 화면도 함께 제공할 때 (Railway 한 링크)
  /// Android 에뮬레이터에서 로컬 서버: http://10.0.2.2:3000/api
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  /// '/api' 처럼 상대 경로면 지금 열려 있는 페이지 주소 기준으로 바꿈
  /// (예: https://resq.up.railway.app 에서 열면 https://resq.up.railway.app/api)
  static final String baseUrl = _configuredBaseUrl.startsWith('/')
      ? Uri.base.resolve(_configuredBaseUrl).toString()
      : _configuredBaseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  /// 기기 식별값 (UserSession 이 설정). /users/:id/... 요청 인증에 사용.
  static String? deviceId;

  static Map<String, String> _headers({bool json = false, Map<String, String>? extra}) => {
        if (json) 'Content-Type': 'application/json',
        if (deviceId != null) 'X-Device-Id': deviceId!,
        ...?extra,
      };

  static Uri _uri(String path, [Map<String, String>? queryParams]) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams == null || queryParams.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...queryParams});
  }

  // ── GET ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final res = await http.get(_uri(path, queryParams), headers: _headers(extra: headers)).timeout(_timeout);
    return _handle(res);
  }

  // ── POST ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final res = await http
        .post(_uri(path), headers: _headers(json: true, extra: headers), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(res);
  }

  // ── PUT ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final res = await http
        .put(_uri(path), headers: _headers(json: true), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(res);
  }

  // ── DELETE ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> delete(String path, {Map<String, String>? headers}) async {
    final res = await http.delete(_uri(path), headers: _headers(extra: headers)).timeout(_timeout);
    return _handle(res);
  }

  // ── 공통 응답 처리 ─────────────────────────────────────────
  static Map<String, dynamic> _handle(http.Response res) {
    dynamic decoded;
    try {
      decoded = json.decode(utf8.decode(res.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    final msg = decoded is Map && decoded['error'] != null ? decoded['error'].toString() : res.reasonPhrase ?? '';
    throw ApiException(res.statusCode, msg);
  }

  /// 서버 루트 주소 (예: QR 응답 페이지 링크 생성 등)
  static String get serverOrigin => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
}
