import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

typedef GuideTip = ({String title, String sub, String? image});

class SafetyGuideScreen extends StatefulWidget {
  /// 처음부터 펼쳐 둘 섹션 ('earthquake' | 'rain' | 'fire') — 알림 상세에서 이동할 때 사용
  final String? initialSection;
  const SafetyGuideScreen({super.key, this.initialSection});

  @override
  State<SafetyGuideScreen> createState() => _SafetyGuideScreenState();
}

class _SafetyGuideScreenState extends State<SafetyGuideScreen> {
  final Map<String, bool> _expanded = {
    'earthquake': false,
    'rain': false,
    'fire': false,
  };

  @override
  void initState() {
    super.initState();
    final section = widget.initialSection;
    if (section != null && _expanded.containsKey(section)) _expanded[section] = true;
  }

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
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.t('Safety Guide'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    lang.t('What to do in an emergency'),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // 바디
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _GuideCategory(
                    id: 'earthquake',
                    title: lang.t('guide_earthquake'),
                    headerBg: const Color(0xFFf5f3ff),
                    iconBg: const Color(0xFFede9fe),
                    titleColor: const Color(0xFF4c1d95),
                    badgeBg: const Color(0xFFede9fe),
                    dotColor: const Color(0xFF7c3aed),
                    icon: Icons.show_chart,
                    iconColor: const Color(0xFF7c3aed),
                    isExpanded: _expanded['earthquake']!,
                    onToggle: () => setState(
                      () => _expanded['earthquake'] = !_expanded['earthquake']!,
                    ),
                    tips: [
                      (
                        title: lang.t('Drop & Stay Calm'),
                        sub: lang.t(
                          'When shaking starts, drop down and watch for falling objects',
                        ),
                        image: 'assets/images/eq1.png',
                      ),
                      (
                        title: lang.t('Cover & Hold On'),
                        sub: lang.t(
                          'Take cover under a sturdy piece of furniture and hold on until the shaking stops',
                        ),
                        image: 'assets/images/eq2.png',
                      ),
                      (
                        title: lang.t('Secure an exit'),
                        sub: lang.t(
                          'Once shaking stops, open a door and move calmly, protecting your head',
                        ),
                        image: 'assets/images/eq3.png',
                      ),
                      (
                        title: lang.t('Evacuate safely'),
                        sub: lang.t(
                          'Use the stairs, not elevators, and head to a safe assembly point',
                        ),
                        image: 'assets/images/eq4.png',
                      ), // 사진 없으면 null
                      (
                        title: lang.t('If you are outdoors'),
                        sub: lang.t(
                          'Move away from buildings, power lines, and signs to an open area, and protect your head',
                        ),
                        image: null,
                      ), // 사진 없으면 null
                    ],
                  ),
                  const SizedBox(height: 8),

                  _GuideCategory(
                    id: 'rain',
                    title: lang.t('guide_rain'),
                    headerBg: const Color(0xFFeff6ff),
                    iconBg: const Color(0xFFdbeafe),
                    titleColor: const Color(0xFF1e3a8a),
                    badgeBg: const Color(0xFFdbeafe),
                    dotColor: const Color(0xFF2563eb),
                    icon: Icons.water_drop_outlined,
                    iconColor: const Color(0xFF2563eb),
                    isExpanded: _expanded['rain']!,
                    onToggle: () =>
                        setState(() => _expanded['rain'] = !_expanded['rain']!),
                    tips: [
                      (
                        title: lang.t('Pack emergency supplies'),
                        sub: lang.t(
                          'Gather water, food, and essentials in a bag before water rises',
                        ),
                        image: 'assets/images/flood1.png',
                      ),
                      (
                        title: lang.t('Call 119'),
                        sub: lang.t(
                          'Call 119 to report flooding and ask for help if you are in danger',
                        ),
                        image: 'assets/images/flood2.png',
                      ),
                      (
                        title: lang.t('Move to high ground'),
                        sub: lang.t(
                          'Move to higher floors or ground immediately and stay away from submerged cars',
                        ),
                        image: 'assets/images/flood3.png',
                      ),
                      (
                        title: lang.t('Go to a shelter'),
                        sub: lang.t(
                          'Head to a designated shelter and never cross flooded roads or bridges',
                        ),
                        image: 'assets/images/flood4.png',
                      ), // 사진 없으면 null
                    ],
                  ),
                  const SizedBox(height: 8),

                  _GuideCategory(
                    id: 'fire',
                    title: lang.t('guide_fire'),
                    headerBg: const Color(0xFFfff1f2),
                    iconBg: const Color(0xFFffe4e6),
                    titleColor: const Color(0xFF7f1d1d),
                    badgeBg: const Color(0xFFffe4e6),
                    dotColor: const Color(0xFFdc2626),
                    icon: Icons.local_fire_department_outlined,
                    iconColor: const Color(0xFFdc2626),
                    isExpanded: _expanded['fire']!,
                    onToggle: () =>
                        setState(() => _expanded['fire'] = !_expanded['fire']!),
                    tips: [
                      (
                        title: lang.t('Sound the alarm'),
                        sub: lang.t(
                          'If you see a fire, press the alarm and shout to alert others nearby',
                        ),
                        image: 'assets/images/firesaftey1.png',
                      ),
                      (
                        title: lang.t('Call for help'),
                        sub: lang.t(
                          'Call 119 (fire department) and report the location clearly',
                        ),
                        image: 'assets/images/firesafety2.png',
                      ),
                      (
                        title: lang.t('Stay low, cover your nose'),
                        sub: lang.t(
                          'Cover your nose and mouth with a cloth and stay low to avoid smoke',
                        ),
                        image: 'assets/images/firesafety3.png',
                      ),
                      (
                        title: lang.t('Use the stairs'),
                        sub: lang.t(
                          'NEVER use elevators-take the stairs and evacuate to a safe place outside',
                        ),
                        image: 'assets/images/firesafety4.png',
                      ), // 사진 없으면 null
                    ],
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

class _GuideCategory extends StatelessWidget {
  final String id, title;
  final Color headerBg, iconBg, titleColor, badgeBg, dotColor, iconColor;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<GuideTip> tips; // 기존: final List<(String, String)> tips;

  const _GuideCategory({
    required this.id,
    required this.title,
    required this.headerBg,
    required this.iconBg,
    required this.titleColor,
    required this.badgeBg,
    required this.dotColor,
    required this.icon,
    required this.iconColor,
    required this.isExpanded,
    required this.onToggle,
    required this.tips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Column(
        children: [
          // 헤더
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: isExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),

                  // tips 개수 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${tips.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: titleColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // 팁 목록
          if (isExpanded)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFe2e8f0))),
              ),
              child: Column(
                children: tips.asMap().entries.map((entry) {
                  final i = entry.key;
                  final tip = entry.value;
                  return Container(
                    decoration: BoxDecoration(
                      border: i < tips.length - 1
                          ? const Border(
                              bottom: BorderSide(color: Color(0xFFf1f5f9)),
                            )
                          : null,
                    ),
                    padding: const EdgeInsets.fromLTRB(30, 8, 12, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5, right: 8),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${tip.title} ',
                                      style: const TextStyle(
                                        fontSize: 15, // 12 → 15
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1a2744),
                                        height: 1.4,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '— ${tip.sub}',
                                      style: const TextStyle(
                                        fontSize: 13, // 12 → 13
                                        color: Color(0xFF374151),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (tip.image != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 180,
                                    ), // ← 사진 높이 상한
                                    child: Image.asset(
                                      tip.image!,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) => Container(
                                        height: 120,
                                        color: const Color(0xFFf1f5f9),
                                        child: Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 28,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ], // ← Row children 닫기
                    ), // ← Row 닫기
                  ); // ← Container(return) 닫기
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
