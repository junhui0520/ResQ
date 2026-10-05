import '../core/api_client.dart';

class ShelterModel {
  final int id;
  final String name;
  final String address;
  final String type;
  final double latitude;
  final double longitude;
  final double distanceKm;

  const ShelterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  factory ShelterModel.fromJson(Map<String, dynamic> j) => ShelterModel(
        id: (j['id'] as num).toInt(),
        name: j['name'] ?? '',
        address: j['address'] ?? '',
        type: j['shelter_type'] ?? '',
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      );
}

class ShelterResult {
  final List<ShelterModel> shelters;
  final bool dataLoaded;

  /// 서버가 시연용 [샘플] 대피소를 보낸 경우 (실제 대피소 아님)
  final bool isSample;
  const ShelterResult(this.shelters, this.dataLoaded, {this.isSample = false});
}

class ReverseGeocode {
  final String? addressKo;
  final String? regionCode;
  final String? regionNameEn;
  final String? attribution;
  const ReverseGeocode({this.addressKo, this.regionCode, this.regionNameEn, this.attribution});
}

/// 대피소·주소 (서버 경유: 공공데이터 키와 Nominatim 이용정책 준수는 서버가 담당)
class PlaceService {
  static Future<ShelterResult> nearbyShelters(double lat, double lng, {double radiusKm = 3}) async {
    final res = await ApiClient.get('/shelters/nearby', queryParams: {
      'lat': lat.toStringAsFixed(6),
      'lng': lng.toStringAsFixed(6),
      'radius_km': '$radiusKm',
      'limit': '30',
    });
    final list = (res['shelters'] as List<dynamic>? ?? [])
        .map((e) => ShelterModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return ShelterResult(list, res['data_loaded'] == true, isSample: res['sample'] == true);
  }

  static Future<ReverseGeocode> reverse(double lat, double lng) async {
    final res = await ApiClient.get('/geo/reverse', queryParams: {
      'lat': lat.toStringAsFixed(6),
      'lng': lng.toStringAsFixed(6),
    });
    final region = res['region'] as Map<String, dynamic>?;
    return ReverseGeocode(
      addressKo: res['address_ko'] as String?,
      regionCode: res['region_code'] as String?,
      regionNameEn: region?['name_en'] as String?,
      attribution: res['attribution'] as String?,
    );
  }
}
