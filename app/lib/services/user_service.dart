import '../core/api_client.dart';

class RegionModel {
  final String code;
  final String nameEn;
  final String nameKo;
  final double? latitude;
  final double? longitude;

  const RegionModel({
    required this.code,
    required this.nameEn,
    required this.nameKo,
    this.latitude,
    this.longitude,
  });

  factory RegionModel.fromJson(Map<String, dynamic> j) => RegionModel(
        code: j['code'] ?? '',
        nameEn: j['name_en'] ?? '',
        nameKo: j['name_ko'] ?? '',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
      );
}

class UserService {
  /// 지역 목록 조회
  static Future<List<RegionModel>> fetchRegions() async {
    final res = await ApiClient.get('/regions');
    final list = res['regions'] as List<dynamic>? ?? [];
    return list.map((e) => RegionModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
