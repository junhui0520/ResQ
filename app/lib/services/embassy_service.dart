import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../core/api_client.dart';

// ── 모델 ──────────────────────────────────────────────────────
class EmbassyModel {
  final String flag;
  final String countryCode;
  final String nameEn;
  final String nameTranslated;
  final String addressEn;
  final String phone; // 원문 표기 (예: '3785-1427, 749-8982/3')
  final String? phoneDial; // 바로 걸 수 있는 번호 (예: '02-3785-1427')
  final String? email;

  const EmbassyModel({
    required this.flag,
    required this.countryCode,
    required this.nameEn,
    required this.nameTranslated,
    required this.addressEn,
    required this.phone,
    this.phoneDial,
    this.email,
  });

  factory EmbassyModel.fromJson(Map<String, dynamic> j) => EmbassyModel(
        flag: j['flag'] ?? '',
        countryCode: j['country_code'] ?? '',
        nameEn: j['name_en'] ?? '',
        nameTranslated: j['name_translated'] ?? j['name_en'] ?? '',
        addressEn: j['address_en'] ?? '',
        phone: j['phone'] ?? '',
        phoneDial: j['phone_dial'],
        email: (j['email'] as String?)?.isNotEmpty == true ? j['email'] : null,
      );
}

class EmergencyNumber {
  final String label;
  final String number;
  final String descriptionEn;

  const EmergencyNumber({required this.label, required this.number, required this.descriptionEn});

  factory EmergencyNumber.fromJson(Map<String, dynamic> j) => EmergencyNumber(
        label: j['label'] ?? '',
        number: j['number'] ?? '',
        descriptionEn: j['description_en'] ?? '',
      );
}

// ── 서비스 ────────────────────────────────────────────────────
class EmbassyService {
  static bool lastFromAsset = false;

  /// 대사관 목록: 서버(번역된 국가명 포함) → 실패 시 앱에 내장된 목록
  static Future<List<EmbassyModel>> fetchEmbassies({required String lang}) async {
    try {
      final res = await ApiClient.get('/embassies', queryParams: {'lang': lang});
      final list = (res['embassies'] as List<dynamic>? ?? [])
          .map((e) => EmbassyModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        lastFromAsset = false;
        return list;
      }
    } catch (_) {}
    lastFromAsset = true;
    return loadFromAsset();
  }

  /// 기존 앱의 내장 파일 (탭 구분) — 오프라인 대비
  static Future<List<EmbassyModel>> loadFromAsset() async {
    final rawData = await rootBundle.loadString('assets/embassy_utf8_C.txt');
    final table = const CsvToListConverter(fieldDelimiter: '\t', shouldParseNumbers: false, eol: '\n')
        .convert(rawData.replaceAll('\r\n', '\n'));
    final list = <EmbassyModel>[];
    for (int i = 1; i < table.length; i++) {
      final row = table[i];
      if (row.length < 5) continue;
      final flag = row[0].toString().trim();
      if (flag == '🌐') continue; // 국제기구 제외 (기존과 동일)
      final name = row[1].toString().trim();
      final address = row[2].toString().trim();
      final phone = row[4].toString().trim();
      list.add(EmbassyModel(
        flag: flag,
        countryCode: '',
        nameEn: name,
        nameTranslated: name,
        addressEn: address,
        phone: phone,
        phoneDial: normalizePhone(phone, address),
        email: row.length > 5 && row[5].toString().trim().isNotEmpty ? row[5].toString().trim() : null,
      ));
    }
    list.sort((a, b) => a.nameEn.compareTo(b.nameEn));
    return list;
  }

  /// 서버 utils/phone.js 와 같은 규칙 (첫 번호만, 서울 주소면 02 추가)
  static String? normalizePhone(String raw, String address) {
    final first = raw.split(RegExp(r'[,/~]')).first.trim();
    final area = RegExp(r'^\(?(0\d{1,2})\)\s*(\d{3,4})-?(\d{4})$').firstMatch(first);
    if (area != null) return '${area.group(1)}-${area.group(2)}-${area.group(3)}';
    final full = RegExp(r'^(0\d{1,2})-(\d{3,4})-(\d{4})$').firstMatch(first);
    if (full != null) return first;
    final local = RegExp(r'^(\d{3,4})-(\d{4})$').firstMatch(first);
    if (local != null && address.toLowerCase().contains('seoul')) return '02-$first';
    return null;
  }

  /// 긴급전화 목록 조회
  static Future<List<EmergencyNumber>> fetchEmergencyNumbers() async {
    final res = await ApiClient.get('/emergency-numbers');
    final list = res['numbers'] as List<dynamic>? ?? [];
    return list.map((e) => EmergencyNumber.fromJson(e as Map<String, dynamic>)).toList();
  }
}
