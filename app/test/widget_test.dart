import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq/core/time_format.dart';
import 'package:resq/providers/language_provider.dart';
import 'package:resq/services/alert_service.dart';
import 'package:resq/services/embassy_service.dart';
import 'package:resq/widgets/alert_card.dart';

Map<String, String> _loadJson(String lang) =>
    Map<String, String>.from(jsonDecode(File('assets/i18n/$lang.json').readAsStringSync()) as Map);

void main() {
  final en = _loadJson('en');

  test('모든 검수 번역 파일은 영어 기준 키만 사용하고 자리표시자를 유지한다', () {
    for (final lang in ['ko', 'ja', 'zh', 'vi', 'de']) {
      final m = _loadJson(lang);
      for (final entry in m.entries) {
        expect(en.containsKey(entry.key), isTrue, reason: '$lang: 알 수 없는 키 ${entry.key}');
        final placeholders = RegExp(r'\{\w+\}').allMatches(en[entry.key]!).map((x) => x.group(0)).toSet();
        for (final p in placeholders) {
          expect(entry.value.contains(p!), isTrue, reason: '$lang.${entry.key} 에 $p 없음');
        }
      }
    }
    // 한국어는 모든 키를 번역
    expect(_loadJson('ko').keys.toSet(), en.keys.toSet());
  });

  test('대사관 전화번호 정규화 (서버와 같은 규칙)', () {
    expect(EmbassyService.normalizePhone('3785-1427, 749-8982/3', 'Jung-gu, Seoul'), '02-3785-1427');
    expect(EmbassyService.normalizePhone('051)465-5104/5/6', 'Busan'), '051-465-5104');
    expect(EmbassyService.normalizePhone('010-6639-1150', ''), '010-6639-1150');
    expect(EmbassyService.normalizePhone('3785-1427', 'Busan'), isNull);
  });

  test('상대 시간 다국어 표시', () {
    final lang = LanguageProvider()..debugSetStrings(en);
    final now = DateTime(2026, 10, 5, 12, 0);
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), lang, now: now), '5 min ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), lang, now: now), '3 h ago');
    expect(timeAgo(now.subtract(const Duration(days: 1, hours: 2)), lang, now: now), 'Yesterday');

    final ko = LanguageProvider()..debugSetStrings(en, overrides: _loadJson('ko'));
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), ko, now: now), '5분 전');
  });

  test('알림 JSON 파싱 (서버 응답 형식)', () {
    final a = AlertModel.fromJson({
      'id': 7,
      'region_code': 'CHEONAN',
      'region_name': 'Cheonan',
      'region_codes': ['CHEONAN', 'CHUNGNAM'],
      'category_code': 'RAIN',
      'category_label': 'Rain / Typhoon',
      'color_hex': '#1565C0',
      'severity_code': 'HIGH',
      'severity_label': 'Emergency alert',
      'severity_level': 3,
      'title': 'Heavy rain warning',
      'content': 'Stay away from rivers.',
      'original_title': '호우경보',
      'original_content': '하천 접근 금지',
      'translated': true,
      'status': 'ACTIVE',
      'source': 'DEMO',
      'issued_at': '2026-10-05T00:00:00.000Z',
    });
    expect(a.isUrgent, isTrue);
    expect(a.isDemo, isTrue);
    expect(a.regionCodes, ['CHEONAN', 'CHUNGNAM']);
    expect(a.issuedAtLocal!.toUtc(), DateTime.utc(2026, 10, 5));
  });

  testWidgets('알림 카드 렌더링', (tester) async {
    final lang = LanguageProvider()..debugSetStrings(en);
    final alert = AlertModel.fromJson({
      'id': 1,
      'region_code': 'SEOUL',
      'category_code': 'FIRE',
      'severity_code': 'CRITICAL',
      'title': 'Forest fire',
      'content': 'Evacuate now.',
      'status': 'ACTIVE',
      'issued_at': DateTime.now().toUtc().toIso8601String(),
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AlertCard(alert: alert, lang: lang))));
    expect(find.text('Forest fire'), findsOneWidget);
    expect(find.text('Extreme alert'), findsOneWidget);
    expect(find.text('Seoul'), findsOneWidget);
  });
}
