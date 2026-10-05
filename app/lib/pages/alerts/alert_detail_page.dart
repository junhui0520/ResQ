import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/device_services.dart';
import '../../core/time_format.dart';
import '../../providers/language_provider.dart';
import '../../screens/safetyguide.dart';
import '../../services/alert_service.dart';
import '../../widgets/alert_card.dart';
import '../shelters/shelter_map_page.dart';

/// 알림 상세: 번역문 ↔ 한국어 원문, 음성 읽기, 유형별 행동요령, 대피소 찾기
class AlertDetailPage extends StatefulWidget {
  final AlertModel alert;
  const AlertDetailPage({super.key, required this.alert});

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

/// 유형별 행동요령 (기존 안전 가이드 문구 키 재사용)
const Map<String, List<(String, String)>> _guideTips = {
  'EARTHQUAKE': [
    ('Drop & Stay Calm', 'When shaking starts, drop down and watch for falling objects'),
    ('Cover & Hold On', 'Take cover under a sturdy piece of furniture and hold on until the shaking stops'),
    ('Secure an exit', 'Once shaking stops, open a door and move calmly, protecting your head'),
    ('Evacuate safely', 'Use the stairs, not elevators, and head to a safe assembly point'),
    ('If you are outdoors', 'Move away from buildings, power lines, and signs to an open area, and protect your head'),
  ],
  'RAIN': [
    ('Pack emergency supplies', 'Gather water, food, and essentials in a bag before water rises'),
    ('Call 119', 'Call 119 to report flooding and ask for help if you are in danger'),
    ('Move to high ground', 'Move to higher floors or ground immediately and stay away from submerged cars'),
    ('Go to a shelter', 'Head to a designated shelter and never cross flooded roads or bridges'),
  ],
  'FIRE': [
    ('Sound the alarm', 'If you see a fire, press the alarm and shout to alert others nearby'),
    ('Call for help', 'Call 119 (fire department) and report the location clearly'),
    ('Stay low, cover your nose', 'Cover your nose and mouth with a cloth and stay low to avoid smoke'),
    ('Use the stairs', 'NEVER use elevators-take the stairs and evacuate to a safe place outside'),
  ],
};

/// 안전 가이드 화면의 섹션 id
String? guideSectionFor(String category) {
  switch (category) {
    case 'EARTHQUAKE':
      return 'earthquake';
    case 'RAIN':
    case 'FLOOD':
      return 'rain';
    case 'FIRE':
      return 'fire';
    default:
      return null;
  }
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  late AlertModel _alert;
  bool _showOriginal = false;
  String? _loadedLang;

  @override
  void initState() {
    super.initState();
    _alert = widget.alert;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Provider.of<LanguageProvider>(context).currentLang;
    if (_loadedLang != lang) {
      _loadedLang = lang;
      _reload(lang);
    }
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  /// 현재 언어로 다시 받아오기 (목록을 다른 언어로 본 경우 등)
  Future<void> _reload(String lang) async {
    try {
      final fresh = await AlertService.fetchAlertDetail(_alert.id, lang: lang);
      if (mounted) setState(() => _alert = fresh);
    } catch (_) {}
  }

  Future<void> _speak(LanguageProvider lang) async {
    if (TtsService.speaking.value) {
      await TtsService.stop();
      return;
    }
    final useOriginal = _showOriginal || !_alert.translated;
    final text = useOriginal
        ? '${_alert.originalTitle}. ${_alert.originalContent}'
        : '${_alert.displayTitle}. ${_alert.content}';
    final ok = await TtsService.speak(text, useOriginal ? 'ko-KR' : lang.ttsLocale);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('tts_unavailable'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final cat = CategoryStyle.of(_alert.categoryCode);
    final color = hexColor(_alert.colorHex, fallback: cat.color);
    final needsTranslationNotice = lang.currentLang != 'ko' && !_alert.translated;
    final showingOriginal = _showOriginal || !_alert.translated;
    final title = showingOriginal ? _alert.originalTitle : _alert.displayTitle;
    final body = showingOriginal ? _alert.originalContent : _alert.content;
    final tips = _guideTips[_alert.categoryCode == 'FLOOD' ? 'RAIN' : _alert.categoryCode];
    final regions = (_alert.regionCodes.isEmpty ? [_alert.regionCode] : _alert.regionCodes)
        .map((c) => lang.t('region_${c.toLowerCase()}'))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(lang.t('alert_detail'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: color, width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  SeverityBadge(code: _alert.severityCode, lang: lang),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(cat.icon, size: 16, color: color),
                    label: Text(lang.t(cat.labelKey), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    backgroundColor: color.withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
                  if (_alert.isDemo)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('DEMO', style: TextStyle(color: Color(0xFF5E35B1), fontWeight: FontWeight.w800)),
                      backgroundColor: Color(0xFFEDE7F6),
                      side: BorderSide.none,
                    ),
                ]),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.35)),
                const SizedBox(height: 12),
                SelectableText(body, style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF2D3748))),
                const SizedBox(height: 14),
                _MetaRow(icon: Icons.schedule, label: lang.t('issued_at'), value: formatDateTime(_alert.issuedAtLocal)),
                _MetaRow(icon: Icons.place_outlined, label: lang.t('target_area'), value: regions.join(', ')),
                if (_alert.regionText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2),
                    child: Text(_alert.regionText, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                  ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: TtsService.speaking,
                    builder: (context, speaking, _) => FilledButton.tonalIcon(
                      onPressed: () => _speak(lang),
                      icon: Icon(speaking ? Icons.stop : Icons.volume_up),
                      label: Text(speaking ? lang.t('stop_reading') : lang.t('read_aloud')),
                    ),
                  ),
                  if (_alert.translated)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showOriginal = !_showOriginal),
                      icon: const Icon(Icons.translate, size: 18),
                      label: Text(_showOriginal ? lang.t('show_translation') : lang.t('show_original')),
                    ),
                ]),
                if (_alert.translated && !_showOriginal) ...[
                  const SizedBox(height: 8),
                  Text('🌐 ${lang.t('machine_translated')}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                ],
                if (needsTranslationNotice) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: Text(lang.t('translation_unavailable'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8A5300))),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text(lang.t('what_to_do'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tips != null)
                  ...tips.asMap().entries.map((e) => _TipRow(
                        index: e.key + 1,
                        title: lang.t(e.value.$1),
                        body: lang.t(e.value.$2),
                        color: color,
                      ))
                else
                  ...['generic_tip_1', 'generic_tip_2', 'generic_tip_3'].asMap().entries.map(
                        (e) => _TipRow(index: e.key + 1, title: lang.t(e.value), body: null, color: color),
                      ),
                if (guideSectionFor(_alert.categoryCode) != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SafetyGuideScreen(initialSection: guideSectionFor(_alert.categoryCode)),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text(lang.t('open_safety_guide')),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShelterMapPage())),
                icon: const Icon(Icons.night_shelter_outlined),
                label: Text(lang.t('find_shelter'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Launch.call('119'),
                icon: const Icon(Icons.phone),
                label: const Text('119', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Text('${lang.t('source_label')}: ${lang.t('data_source_alerts')}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text('$label  ', style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748)))),
      ]),
    );
  }
}

class _TipRow extends StatelessWidget {
  final int index;
  final String title;
  final String? body;
  final Color color;
  const _TipRow({required this.index, required this.title, required this.body, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Text('$index', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navyDark, height: 1.4)),
            if (body != null) ...[
              const SizedBox(height: 2),
              Text(body!, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4)),
            ],
          ]),
        ),
      ]),
    );
  }
}
