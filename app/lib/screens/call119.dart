import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/device_services.dart';
import '../pages/helper/emergency_helper_page.dart';
import '../providers/language_provider.dart';

/// 긴급 전화 (기존 디자인 유지)
/// 변경: 1339 를 '의료상담'이 아닌 질병관리청 콜센터로 정정(응급의료상담은 2012년 119로 통합),
///       1345·1330 추가, '주변 병원'을 실제 지도 검색으로 연결, 긴급 문장 화면 연결
class Call119Screen extends StatelessWidget {
  const Call119Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFf0f4f8),
      body: Column(
        children: [
          // 헤더
          Container(
            color: const Color(0xFF1a2744),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.chevron_left, color: Colors.white70, size: 22),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.t('call_title'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(lang.t('call_subtitle'), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ),
              ],
            ),
          ),

          // 바디
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 119 히어로 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFFdc2626), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        const Text(
                          '119',
                          style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: 4),
                        ),
                        const SizedBox(height: 4),
                        Text(lang.t('call_119_desc'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 전화 버튼
                  _WideButton(
                    icon: Icons.phone,
                    color: const Color(0xFFdc2626),
                    label: lang.t('tap_to_call'),
                    onTap: () => Launch.call('119'),
                  ),
                  const SizedBox(height: 8),
                  // 한국어 문장·현재 주소 화면
                  _WideButton(
                    icon: Icons.record_voice_over_outlined,
                    color: const Color(0xFF1a2744),
                    label: lang.t('open_helper'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyHelperPage())),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    lang.t('other_numbers'),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1a2744), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),

                  _EmergencyRow(
                    iconBg: const Color(0xFFeff6ff),
                    icon: Icons.local_police_outlined,
                    iconColor: const Color(0xFF2563eb),
                    title: lang.t('police_112'),
                    subtitle: lang.t('police_112_sub'),
                    onTap: () => Launch.call('112'),
                  ),
                  const SizedBox(height: 8),
                  _EmergencyRow(
                    iconBg: const Color(0xFFfef3c7),
                    icon: Icons.support_agent,
                    iconColor: const Color(0xFFb45309),
                    title: lang.t('immigration_1345'),
                    subtitle: lang.t('immigration_1345_sub'),
                    onTap: () => Launch.call('1345'),
                  ),
                  const SizedBox(height: 8),
                  _EmergencyRow(
                    iconBg: const Color(0xFFf0fdf4),
                    icon: Icons.coronavirus_outlined,
                    iconColor: const Color(0xFF16a34a),
                    title: lang.t('medical_1339'),
                    subtitle: lang.t('medical_1339_sub'),
                    onTap: () => Launch.call('1339'),
                  ),
                  const SizedBox(height: 8),
                  _EmergencyRow(
                    iconBg: const Color(0xFFf5f3ff),
                    icon: Icons.translate,
                    iconColor: const Color(0xFF7c3aed),
                    title: lang.t('travel_1330'),
                    subtitle: lang.t('travel_1330_sub'),
                    onTap: () => Launch.call('1330'),
                  ),
                  const SizedBox(height: 8),
                  _EmergencyRow(
                    iconBg: const Color(0xFFfff1f2),
                    icon: Icons.local_hospital_outlined,
                    iconColor: const Color(0xFFdc2626),
                    title: lang.t('nearby_hospitals'),
                    subtitle: lang.t('nearby_er_hint'),
                    onTap: () => Launch.mapSearch('응급실'),
                  ),
                  const SizedBox(height: 8),

                  // 팁 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFfef9e7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFfde68a)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('call_tip_title'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400e))),
                        const SizedBox(height: 4),
                        Text(lang.t('call_tip_body'),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF78350f), height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _WideButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFe2e8f0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyRow extends StatelessWidget {
  final Color iconBg, iconColor;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _EmergencyRow({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFe2e8f0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1a2744))),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748b))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFcbd5e1), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
