import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/device_services.dart';
import '../../providers/language_provider.dart';
import '../../services/place_service.dart';

/// 119/112 신고 도우미
/// 한국어가 어려운 사용자가 한국어 문장을 보여주거나 음성으로 들려주고,
/// 현재 위치의 한국어 주소를 말할 수 있게 돕습니다.
class EmergencyHelperPage extends StatefulWidget {
  const EmergencyHelperPage({super.key});

  @override
  State<EmergencyHelperPage> createState() => _EmergencyHelperPageState();
}

const _phraseKeys = [
  'phrase_help',
  'phrase_fire',
  'phrase_ambulance',
  'phrase_injured',
  'phrase_police',
  'phrase_gas',
  'phrase_interpreter',
  'phrase_shelter',
];

class _EmergencyHelperPageState extends State<EmergencyHelperPage> {
  Map<String, String> _ko = {};
  bool _locating = true;
  String? _addressKo;
  String? _attribution;
  bool _locationFailed = false;

  @override
  void initState() {
    super.initState();
    _loadKorean();
    _locate();
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  Future<void> _loadKorean() async {
    final raw = await rootBundle.loadString('assets/i18n/ko.json');
    if (!mounted) return;
    setState(() => _ko = Map<String, String>.from(jsonDecode(raw) as Map));
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationFailed = false;
    });
    final loc = await LocationService.current();
    if (!loc.ok) {
      if (mounted) setState(() { _locating = false; _locationFailed = true; });
      return;
    }
    try {
      final geo = await PlaceService.reverse(loc.lat!, loc.lng!);
      if (!mounted) return;
      setState(() {
        _addressKo = geo.addressKo;
        _attribution = geo.attribution;
        _locating = false;
        _locationFailed = geo.addressKo == null;
      });
    } catch (_) {
      if (mounted) setState(() { _locating = false; _locationFailed = true; });
    }
  }

  Future<void> _speakKorean(String text, LanguageProvider lang) async {
    final ok = await TtsService.speak(text, 'ko-KR');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('tts_unavailable'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final addressSentence = _addressKo == null ? null : '${_ko['phrase_address'] ?? ''} $_addressKo';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(lang.t('helper_title'), style: const TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(lang.t('helper_intro'), style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 14),

          // 내 위치 (한국어 주소)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.my_location, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(lang.t('my_location_ko'),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: lang.t('refresh'),
                    onPressed: _locating ? null : _locate,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ]),
                const SizedBox(height: 6),
                if (_locating)
                  Text(lang.t('address_loading'), style: const TextStyle(color: Colors.white, fontSize: 16))
                else if (_locationFailed || _addressKo == null)
                  Text(lang.t('address_unavailable'), style: const TextStyle(color: Colors.white, fontSize: 15))
                else ...[
                  SelectableText(_addressKo!,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.4)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.navy),
                    onPressed: () => _speakKorean(addressSentence!, lang),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(lang.t('read_aloud')),
                  ),
                  if (_attribution != null) ...[
                    const SizedBox(height: 6),
                    Text(_attribution!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 한국어 문장 카드
          ..._phraseKeys.map((key) {
            final korean = _ko[key] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: korean.isEmpty ? null : () => _speakKorean(korean, lang),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(korean,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navyDark, height: 1.35)),
                            if (lang.currentLang != 'ko') ...[
                              const SizedBox(height: 4),
                              Text(lang.t(key), style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.play_circle_fill, color: AppColors.emergencyRed, size: 40),
                    ]),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFfef9e7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFfde68a)),
            ),
            child: Text(lang.t('helper_call_tip'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF78350f), height: 1.5)),
          ),
          const SizedBox(height: 12),
          Row(children: [
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
                label: const Text('119', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563eb),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Launch.call('112'),
                icon: const Icon(Icons.local_police_outlined),
                label: const Text('112', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
