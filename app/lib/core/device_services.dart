import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ── 위치 ──────────────────────────────────────────────────────
enum LocationFailure { serviceDisabled, denied, unavailable }

class LocationResult {
  final double? lat;
  final double? lng;
  final LocationFailure? failure;
  const LocationResult.ok(double this.lat, double this.lng) : failure = null;
  const LocationResult.fail(LocationFailure this.failure)
      : lat = null,
        lng = null;
  bool get ok => failure == null;
}

class LocationService {
  /// 현재 위치 (권한 요청 포함). 웹에서는 브라우저 위치 권한 팝업이 뜹니다.
  static Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.fail(LocationFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return const LocationResult.fail(LocationFailure.denied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult.ok(pos.latitude, pos.longitude);
    } catch (_) {
      return const LocationResult.fail(LocationFailure.unavailable);
    }
  }
}

// ── 음성 읽기 (TTS) ───────────────────────────────────────────
class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static final ValueNotifier<bool> speaking = ValueNotifier(false);
  static bool _initialized = false;

  static void _init() {
    if (_initialized) return;
    _initialized = true;
    _tts.setCompletionHandler(() => speaking.value = false);
    _tts.setCancelHandler(() => speaking.value = false);
    _tts.setErrorHandler((_) => speaking.value = false);
  }

  /// [locale] 예: 'ko-KR'. 성공하면 true.
  static Future<bool> speak(String text, String locale) async {
    _init();
    if (text.trim().isEmpty) return false;
    try {
      await _tts.stop();
      await _tts.setLanguage(locale);
      // 웹(Web Speech API)은 1.0 이 보통 속도, 모바일 플러그인은 0.5 가 보통 속도
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
      speaking.value = true;
      await _tts.speak(text);
      return true;
    } catch (_) {
      speaking.value = false;
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking.value = false;
  }
}

// ── 외부 앱 열기 (전화·지도·메일) ──────────────────────────────
class Launch {
  /// 전화 키패드 열기 (숫자와 + 만 남김)
  static Future<bool> call(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return false;
    return _open(Uri(scheme: 'tel', path: cleaned));
  }

  static Future<bool> email(String address) => _open(Uri(scheme: 'mailto', path: address));

  /// Google Maps URL (키 불필요) — https://developers.google.com/maps/documentation/urls/get-started
  static Future<bool> mapSearch(String query) => _open(Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      }));

  static Future<bool> directions(double lat, double lng) => _open(Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$lat,$lng',
        'travelmode': 'walking',
      }));

  static Future<bool> url(String url) => _open(Uri.parse(url));

  static Future<bool> _open(Uri uri) async {
    try {
      // 웹은 브라우저 기본 동작(전화·메일은 현재 창, 지도는 새 탭), 모바일은 외부 앱
      return await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
