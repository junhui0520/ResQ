import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/user_session.dart';

// ── 모델 (기존 qr_result_screen.dart 의 모델을 이 파일로 통합) ─────────────
class EmergencyContact {
  String name;
  String relationship;
  String phone;

  EmergencyContact({required this.name, required this.relationship, required this.phone});

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        name: j['name'] ?? '',
        relationship: j['relationship'] ?? '',
        phone: j['phone'] ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'relationship': relationship, 'phone': phone};
}

class MedicalInfo {
  String category; // 'allergy' | 'condition'
  String value;

  MedicalInfo({required this.category, required this.value});

  factory MedicalInfo.fromJson(Map<String, dynamic> j) =>
      MedicalInfo(category: j['category'] ?? '', value: j['value'] ?? '');

  Map<String, dynamic> toJson() => {'category': category, 'value': value};
}

class QrProfile {
  final String name;
  final String gender;
  final int age;
  final String bloodType;
  final String nationality;
  final List<EmergencyContact> contacts;
  final List<MedicalInfo> medicalInfos;
  final String? qrUrl;

  const QrProfile({
    required this.name,
    required this.gender,
    required this.age,
    required this.bloodType,
    required this.nationality,
    required this.contacts,
    required this.medicalInfos,
    this.qrUrl,
  });

  factory QrProfile.fromJson(Map<String, dynamic> j) => QrProfile(
        name: j['name'] ?? '',
        gender: j['gender'] ?? '',
        age: (j['age'] as num?)?.toInt() ?? 0,
        bloodType: j['blood_type'] ?? '',
        nationality: j['nationality'] ?? '',
        contacts: (j['emergency_contacts'] as List<dynamic>? ?? [])
            .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
            .toList(),
        medicalInfos: (j['medical_infos'] as List<dynamic>? ?? [])
            .map((e) => MedicalInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        qrUrl: j['qr_url'] as String?,
      );

  Map<String, dynamic> toJson({String? languageCode}) => {
        'name': name,
        'gender': gender,
        'age': age,
        'blood_type': bloodType,
        'nationality': nationality,
        if (languageCode != null) 'language_code': languageCode,
        'emergency_contacts': contacts.map((c) => c.toJson()).toList(),
        'medical_infos': medicalInfos.map((m) => m.toJson()).toList(),
        if (qrUrl != null) 'qr_url': qrUrl,
      };

  QrProfile copyWith({String? qrUrl}) => QrProfile(
        name: name,
        gender: gender,
        age: age,
        bloodType: bloodType,
        nationality: nationality,
        contacts: contacts,
        medicalInfos: medicalInfos,
        qrUrl: qrUrl ?? this.qrUrl,
      );

  List<MedicalInfo> get allergies => medicalInfos.where((m) => m.category == 'allergy').toList();
  List<MedicalInfo> get conditions => medicalInfos.where((m) => m.category == 'condition').toList();
}

enum SaveResult { synced, localOnly }

// ── 서비스 ────────────────────────────────────────────────────
/// 내 응급정보: 기기에 먼저 저장(오프라인 대비) + 서버 동기화
class QrService {
  static const _kProfile = 'qr_profile';
  static const _kDeleted = 'qr_deleted';
  static const _kPending = 'qr_pending_sync';

  static Future<QrProfile?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kDeleted) ?? false) return null;
    final raw = prefs.getString(_kProfile);
    if (raw == null) return null;
    try {
      final p = QrProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return p.name.isEmpty ? null : p;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveLocal(QrProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDeleted);
    await prefs.setString(_kProfile, jsonEncode(p.toJson()));
  }

  /// 서버 프로필 (없으면 null). 실패 시 예외.
  static Future<QrProfile?> fetchRemote() async {
    final userId = await UserSession.ensureUserId();
    if (userId == null) throw const ApiException(0, 'offline');
    try {
      final data = await ApiClient.get('/users/$userId/qr-profile');
      return QrProfile.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 기기 → 서버 순으로 불러오기. 기기에 동기화 안 된 변경이 있으면 먼저 업로드.
  static Future<QrProfile?> load() async {
    final local = await loadLocal();
    final prefs = await SharedPreferences.getInstance();
    try {
      if (local != null && (prefs.getBool(_kPending) ?? false)) {
        final r = await save(local);
        if (r.$1 == SaveResult.synced) return r.$2;
      }
      final remote = await fetchRemote();
      if (remote != null) {
        await _saveLocal(remote);
        return remote;
      }
      // 서버에 없고 기기에만 있으면 업로드
      if (local != null) return (await save(local)).$2;
      return null;
    } catch (_) {
      return local;
    }
  }

  /// 저장: 기기에 먼저 저장하고 서버로 전송 (연락처·의료정보 포함)
  static Future<(SaveResult, QrProfile)> save(QrProfile profile, {String? languageCode}) async {
    await _saveLocal(profile);
    final prefs = await SharedPreferences.getInstance();
    try {
      final userId = await UserSession.ensureUserId();
      if (userId == null) throw const ApiException(0, 'offline');
      final res = await ApiClient.post('/users/$userId/qr-profile', profile.toJson(languageCode: languageCode));
      final saved = profile.copyWith(qrUrl: res['qr_url'] as String?);
      await _saveLocal(saved);
      await prefs.setBool(_kPending, false);
      return (SaveResult.synced, saved);
    } catch (_) {
      await prefs.setBool(_kPending, true);
      return (SaveResult.localOnly, profile);
    }
  }

  /// 삭제: 기기 + 서버 (기존: 빈 이름으로 POST 해서 서버가 400 으로 거부하던 버그 수정)
  static Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfile);
    await prefs.setBool(_kDeleted, true);
    await prefs.setBool(_kPending, false);
    final userId = UserSession.userId;
    if (userId == null) return;
    try {
      await ApiClient.delete('/users/$userId/qr-profile');
    } catch (_) {}
  }
}
