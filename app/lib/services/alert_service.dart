import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

// ── 모델 ──────────────────────────────────────────────────────
class AlertModel {
  final int id;
  final String regionCode;
  final String regionName;
  final List<String> regionCodes;
  final String regionText;
  final String categoryCode;
  final String categoryLabel;
  final String colorHex;
  final String severityCode;
  final String severityLabel;
  final int severityLevel;
  final String title;
  final String content;
  final String actionGuide;
  final String originalTitle;
  final String originalContent;
  final bool translated;
  final String status;
  final String source;
  final String issuedAt;

  const AlertModel({
    required this.id,
    required this.regionCode,
    required this.regionName,
    this.regionCodes = const [],
    this.regionText = '',
    required this.categoryCode,
    required this.categoryLabel,
    required this.colorHex,
    required this.severityCode,
    required this.severityLabel,
    this.severityLevel = 1,
    required this.title,
    required this.content,
    required this.actionGuide,
    this.originalTitle = '',
    this.originalContent = '',
    this.translated = false,
    required this.status,
    this.source = 'SAFETYDATA',
    required this.issuedAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
        id: (j['id'] as num).toInt(),
        regionCode: j['region_code'] ?? '',
        regionName: j['region_name'] ?? '',
        regionCodes: (j['region_codes'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        regionText: j['region_text'] ?? '',
        categoryCode: j['category_code'] ?? 'OTHER',
        categoryLabel: j['category_label'] ?? '',
        colorHex: j['color_hex'] ?? '#9AA5B4',
        severityCode: j['severity_code'] ?? 'LOW',
        severityLabel: j['severity_label'] ?? '',
        severityLevel: (j['severity_level'] as num?)?.toInt() ?? 1,
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        actionGuide: j['action_guide'] ?? '',
        originalTitle: j['original_title'] ?? j['title'] ?? '',
        originalContent: j['original_content'] ?? j['content'] ?? '',
        translated: j['translated'] == true,
        status: j['status'] ?? '',
        source: j['source'] ?? 'SAFETYDATA',
        issuedAt: j['issued_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'region_code': regionCode,
        'region_name': regionName,
        'region_codes': regionCodes,
        'region_text': regionText,
        'category_code': categoryCode,
        'category_label': categoryLabel,
        'color_hex': colorHex,
        'severity_code': severityCode,
        'severity_label': severityLabel,
        'severity_level': severityLevel,
        'title': title,
        'content': content,
        'action_guide': actionGuide,
        'original_title': originalTitle,
        'original_content': originalContent,
        'translated': translated,
        'status': status,
        'source': source,
        'issued_at': issuedAt,
      };

  bool get isActive => status == 'ACTIVE';
  bool get isDemo => source == 'DEMO';

  /// 위급·긴급 재난문자 (경보음 동반 단계)
  bool get isUrgent => severityCode == 'CRITICAL' || severityCode == 'HIGH';

  /// 서버는 UTC ISO 문자열을 보냄 → 기기 현지 시각으로 변환
  DateTime? get issuedAtLocal {
    final dt = DateTime.tryParse(issuedAt);
    return dt?.toLocal();
  }

  /// 제목이 비어 있으면 본문 앞부분
  String get displayTitle {
    if (title.trim().isNotEmpty) return title;
    final c = content.trim();
    return c.length > 60 ? '${c.substring(0, 59)}…' : c;
  }
}

class AlertCategory {
  final String code;
  final String labelEn;
  final String colorHex;

  const AlertCategory({required this.code, required this.labelEn, required this.colorHex});

  factory AlertCategory.fromJson(Map<String, dynamic> j) => AlertCategory(
        code: j['code'] ?? '',
        labelEn: j['label_en'] ?? '',
        colorHex: j['color_hex'] ?? '#9AA5B4',
      );
}

// ── 서비스 ────────────────────────────────────────────────────
/// 번역은 이제 서버가 담당합니다. (기존: 앱이 비공식 번역 주소를 직접 호출)
class AlertService {
  /// 마지막 목록 요청이 오프라인 캐시에서 왔는지
  static bool lastFromCache = false;

  static Map<String, String> _params(Map<String, String?> m) =>
      {for (final e in m.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};

  /// 알림 목록 (서버 번역 포함). 실패하면 마지막으로 받은 목록(기기 캐시)을 돌려줍니다.
  static Future<List<AlertModel>> fetchAlerts({
    required String lang,
    String? regionCode,
    String? categoryCode,
    String? status,
    int limit = 50,
  }) async {
    final cacheKey = 'alerts_cache_${lang}_${regionCode ?? 'ALL'}';
    try {
      final res = await ApiClient.get('/alerts',
          queryParams: _params({
            'lang': lang,
            'region_code': regionCode,
            'category_code': categoryCode,
            'status': status,
            'limit': '$limit',
          }));
      final list = (res['alerts'] as List<dynamic>? ?? [])
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList();
      lastFromCache = false;
      if (categoryCode == null && status == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(list.map((a) => a.toJson()).toList()));
      }
      return list;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null) rethrow;
      lastFromCache = true;
      final cached = (jsonDecode(raw) as List<dynamic>)
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return categoryCode == null ? cached : cached.where((a) => a.categoryCode == categoryCode).toList();
    }
  }

  /// 발령 중(ACTIVE) 최근 알림. sinceId 를 주면 그 이후 새 알림만.
  static Future<List<AlertModel>> fetchRecent({
    required String lang,
    String? regionCode,
    int limit = 5,
    int? sinceId,
  }) async {
    final res = await ApiClient.get('/alerts/recent',
        queryParams: _params({
          'lang': lang,
          'region_code': regionCode,
          'limit': '$limit',
          'since_id': sinceId?.toString(),
        }));
    return (res['alerts'] as List<dynamic>? ?? [])
        .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AlertModel> fetchAlertDetail(int id, {String lang = 'en'}) async {
    final res = await ApiClient.get('/alerts/$id', queryParams: {'lang': lang});
    return AlertModel.fromJson(res);
  }

  static Future<List<AlertCategory>> fetchCategories() async {
    final res = await ApiClient.get('/alerts/categories');
    final list = res['categories'] as List<dynamic>? ?? [];
    return list.map((e) => AlertCategory.fromJson(e as Map<String, dynamic>)).toList();
  }
}
