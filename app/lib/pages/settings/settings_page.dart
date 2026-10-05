import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/device_services.dart';
import '../../l10n/app_strings.dart';
import '../../providers/language_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/place_service.dart';
import '../../services/user_service.dart';
import 'demo_panel.dart';

const Color kNavy = AppColors.navy;

// ── 지역 모델 ─────────────────────────────────────────────────
class RegionInfo {
  final String code;
  final String nameEn;
  final String nameKey;
  final double? lat;
  final double? lng;

  const RegionInfo({required this.code, required this.nameEn, required this.nameKey, this.lat, this.lng});
}

/// 설정 (기존 디자인 유지)
/// 변경: 설정 상태를 SettingsProvider 로 이동(홈·알림에 즉시 반영), 언어 15개,
///       '내 위치로 자동 설정', 토글 의미를 실제 동작(앱 내 배너·음성 안내)에 맞춤, 데이터 출처 표시
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<RegionInfo> _regions = [];
  bool _detecting = false;
  int _versionTaps = 0;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final list = await UserService.fetchRegions();
      if (!mounted) return;
      setState(() => _regions = [
            const RegionInfo(code: 'ALL', nameEn: 'All Regions', nameKey: 'region_all'),
            ...list.map((r) => RegionInfo(
                  code: r.code,
                  nameEn: r.nameEn,
                  nameKey: 'region_${r.code.toLowerCase()}',
                  lat: r.latitude,
                  lng: r.longitude,
                )),
          ]);
    } catch (_) {
      if (mounted) setState(() => _regions = _defaultRegions);
    }
  }

  String _regionLabel(LanguageProvider lang, String code) {
    final key = 'region_${code.toLowerCase()}';
    final t = lang.t(key);
    if (t != key) return t;
    final found = _regions.where((r) => r.code == code);
    return found.isNotEmpty ? found.first.nameEn : code;
  }

  Future<void> _detectRegion() async {
    final lang = context.read<LanguageProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _detecting = true);
    final loc = await LocationService.current();
    if (!loc.ok) {
      if (mounted) setState(() => _detecting = false);
      messenger.showSnackBar(SnackBar(
        content: Text(lang.t(loc.failure == LocationFailure.denied ? 'location_permission_needed' : 'location_unavailable')),
      ));
      return;
    }
    try {
      final geo = await PlaceService.reverse(loc.lat!, loc.lng!);
      if (geo.regionCode != null) {
        await settings.setRegion(geo.regionCode!, geo.regionNameEn ?? geo.regionCode!, lat: loc.lat, lng: loc.lng);
        messenger.showSnackBar(SnackBar(
          content: Text('${lang.t('region_updated')}: ${_regionLabel(lang, geo.regionCode!)}'),
        ));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(lang.t('location_unavailable'))));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(lang.t('alerts_connection_error'))));
    }
    if (mounted) setState(() => _detecting = false);
  }

  void _showLanguagePicker(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final settings = context.read<SettingsProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ChangeNotifierProvider.value(
        value: lang,
        child: _LanguagePickerSheet(onPicked: settings.syncLanguage),
      ),
    );
  }

  void _showRegionPicker(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final settings = context.read<SettingsProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ChangeNotifierProvider.value(
        value: lang,
        child: _RegionPickerSheet(
          regions: _regions.isEmpty ? _defaultRegions : _regions,
          selectedCode: settings.regionCode,
          onSelect: (region) => settings.setRegion(region.code, region.nameEn, lat: region.lat, lng: region.lng),
        ),
      ),
    );
  }

  void _onVersionTap() {
    // 발표용 데모 메뉴: 버전 정보를 5번 누르면 열림
    _versionTaps++;
    if (_versionTaps >= 5) {
      _versionTaps = 0;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DemoPanel()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: kNavy,
        elevation: 0,
        titleSpacing: 20,
        title: Text(lang.t('settings'),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              _SectionLabel(lang.t('language')),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                _TileWithChip(
                  icon: Icons.language,
                  iconBg: const Color(0xFFE8EAF6),
                  iconColor: const Color(0xFF5C6BC0),
                  title: lang.t('app_language'),
                  subtitle: lang.t('alert_translation'),
                  chipLabel: '${lang.currentFlag} ${lang.currentLangName}',
                  onTap: () => _showLanguagePicker(context),
                ),
              ]),
              if (lang.usesMachineTranslation)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Text('🌐 ${lang.t('machine_translation_note')}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),

              const SizedBox(height: 24),
              _SectionLabel(lang.t('notifications')),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                _TileWithToggle(
                  icon: Icons.notifications_outlined,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFE53935),
                  title: lang.t('emergency_alerts'),
                  subtitle: lang.t('alert_banner_sub'),
                  value: settings.alertBanner,
                  onChanged: settings.setAlertBanner,
                ),
                const _Divider(),
                _TileWithToggle(
                  icon: Icons.volume_up_outlined,
                  iconBg: const Color(0xFFFFF8E1),
                  iconColor: const Color(0xFFFFB300),
                  title: lang.t('read_alerts_aloud'),
                  subtitle: lang.t('read_alerts_aloud_sub'),
                  value: settings.readAloud,
                  onChanged: settings.alertBanner ? settings.setReadAloud : null,
                ),
                const _Divider(),
                _TileWithChip(
                  icon: Icons.location_on_outlined,
                  iconBg: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF43A047),
                  title: lang.t('region'),
                  subtitle: lang.t('my_alert_area'),
                  chipLabel: _regionLabel(lang, settings.regionCode),
                  onTap: () => _showRegionPicker(context),
                ),
                const _Divider(),
                InkWell(
                  onTap: _detecting ? null : _detectRegion,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      const _IconBox(icon: Icons.my_location, bg: Color(0xFFE3F2FD), color: Color(0xFF1E88E5)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(_detecting ? lang.t('detecting_location') : lang.t('use_current_location'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kNavy)),
                      ),
                      if (_detecting)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ]),
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              _SectionLabel(lang.t('about')),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                GestureDetector(
                  onTap: _onVersionTap,
                  child: _TileAbout(
                    icon: Icons.info_outline,
                    iconBg: const Color(0xFFE3F2FD),
                    iconColor: const Color(0xFF1E88E5),
                    title: lang.t('app_version'),
                    subtitle: 'ResQ',
                    trailing: 'v2.0.0',
                  ),
                ),
                const _Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lang.t('data_sources'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kNavy)),
                    const SizedBox(height: 6),
                    ...[
                      lang.t('data_source_alerts'),
                      lang.t('shelter_source'),
                      'Map & address: © OpenStreetMap contributors',
                      'Translation: Google Cloud Translation',
                    ].map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('· $s', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        )),
                  ]),
                ),
              ]),
            ],
          ),
          if (lang.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: kNavy),
                        const SizedBox(height: 12),
                        Text(lang.t('loading'), style: const TextStyle(color: kNavy)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 기본 지역 목록 (API 실패 시 fallback) — 기존 값 유지
const List<RegionInfo> _defaultRegions = [
  RegionInfo(code: 'ALL', nameEn: 'All Regions', nameKey: 'region_all'),
  RegionInfo(code: 'SEOUL', nameEn: 'Seoul', nameKey: 'region_seoul', lat: 37.5665, lng: 126.9780),
  RegionInfo(code: 'BUSAN', nameEn: 'Busan', nameKey: 'region_busan', lat: 35.1796, lng: 129.0756),
  RegionInfo(code: 'DAEGU', nameEn: 'Daegu', nameKey: 'region_daegu', lat: 35.8714, lng: 128.6014),
  RegionInfo(code: 'INCHEON', nameEn: 'Incheon', nameKey: 'region_incheon', lat: 37.4563, lng: 126.7052),
  RegionInfo(code: 'GWANGJU', nameEn: 'Gwangju', nameKey: 'region_gwangju', lat: 35.1595, lng: 126.8526),
  RegionInfo(code: 'DAEJEON', nameEn: 'Daejeon', nameKey: 'region_daejeon', lat: 36.3504, lng: 127.3845),
  RegionInfo(code: 'ULSAN', nameEn: 'Ulsan', nameKey: 'region_ulsan', lat: 35.5384, lng: 129.3114),
  RegionInfo(code: 'SEJONG', nameEn: 'Sejong', nameKey: 'region_sejong', lat: 36.4800, lng: 127.2890),
  RegionInfo(code: 'GYEONGGI', nameEn: 'Gyeonggi', nameKey: 'region_gyeonggi', lat: 37.4138, lng: 127.5183),
  RegionInfo(code: 'GANGWON', nameEn: 'Gangwon', nameKey: 'region_gangwon', lat: 37.8228, lng: 128.1555),
  RegionInfo(code: 'CHUNGBUK', nameEn: 'Chungbuk', nameKey: 'region_chungbuk', lat: 36.6357, lng: 127.4917),
  RegionInfo(code: 'CHUNGNAM', nameEn: 'Chungnam', nameKey: 'region_chungnam', lat: 36.5184, lng: 126.8000),
  RegionInfo(code: 'CHEONAN', nameEn: 'Cheonan', nameKey: 'region_cheonan', lat: 36.8151, lng: 127.1139),
  RegionInfo(code: 'JEONBUK', nameEn: 'Jeonbuk', nameKey: 'region_jeonbuk', lat: 35.7175, lng: 127.1530),
  RegionInfo(code: 'JEONNAM', nameEn: 'Jeonnam', nameKey: 'region_jeonnam', lat: 34.8679, lng: 126.9910),
  RegionInfo(code: 'GYEONGBUK', nameEn: 'Gyeongbuk', nameKey: 'region_gyeongbuk', lat: 36.4919, lng: 128.8889),
  RegionInfo(code: 'GYEONGNAM', nameEn: 'Gyeongnam', nameKey: 'region_gyeongnam', lat: 35.4606, lng: 128.2132),
  RegionInfo(code: 'JEJU', nameEn: 'Jeju', nameKey: 'region_jeju', lat: 33.4996, lng: 126.5312),
];

// ── 지역 선택 바텀시트 ────────────────────────────────────────
class _RegionPickerSheet extends StatelessWidget {
  final List<RegionInfo> regions;
  final String selectedCode;
  final void Function(RegionInfo) onSelect;

  const _RegionPickerSheet({required this.regions, required this.selectedCode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(lang.t('select_region'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
                  const SizedBox(height: 4),
                  Text(lang.t('select_region_sub'), style: const TextStyle(fontSize: 13, color: Color(0xFF718096))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                itemCount: regions.length,
                itemBuilder: (context, index) {
                  final region = regions[index];
                  final isSelected = selectedCode == region.code;
                  final t = lang.t(region.nameKey);
                  final label = t != region.nameKey ? t : region.nameEn;

                  return InkWell(
                    onTap: () {
                      onSelect(region);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? kNavy.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? kNavy : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(region.code == 'ALL' ? Icons.public : Icons.location_on_outlined, size: 20, color: kNavy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? kNavy : const Color(0xFF2D3748),
                              )),
                        ),
                        if (isSelected) const Icon(Icons.check_circle, color: kNavy, size: 20),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 언어 선택 바텀시트 ────────────────────────────────────────
class _LanguagePickerSheet extends StatelessWidget {
  final Future<void> Function(String lang) onPicked;
  const _LanguagePickerSheet({required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(lang.t('choose_language'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
            const SizedBox(height: 16),
            ...AppStrings.languageNames.entries.map((entry) {
              final isSelected = lang.currentLang == entry.key;
              return _LanguageTile(
                flag: AppStrings.languageFlags[entry.key] ?? '',
                name: entry.value,
                isSelected: isSelected,
                onTap: () async {
                  Navigator.pop(context);
                  await lang.setLanguage(entry.key);
                  await onPicked(entry.key);
                },
              );
            }),
          ],
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({required this.flag, required this.name, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? kNavy.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? kNavy : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? kNavy : const Color(0xFF2D3748),
                )),
          ),
          if (isSelected) const Icon(Icons.check_circle, color: kNavy, size: 20),
        ]),
      ),
    );
  }
}

// ── 공통 위젯 (기존과 동일) ─────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNavy, letterSpacing: 1.2));
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: children));
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 68, color: Color(0xFFF0F2F5));
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  const _IconBox({required this.icon, required this.bg, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 20));
}

class _TileWithToggle extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _TileWithToggle({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        _IconBox(icon: icon, bg: iconBg, color: iconColor),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDisabled ? Colors.grey : kNavy)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: isDisabled ? Colors.grey.shade400 : const Color(0xFF718096))),
        ])),
        Switch(value: value, onChanged: onChanged, activeThumbColor: Colors.white, activeTrackColor: kNavy),
      ]),
    );
  }
}

class _TileWithChip extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle, chipLabel;
  final VoidCallback onTap;
  const _TileWithChip({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.chipLabel,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            _IconBox(icon: icon, bg: iconBg, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kNavy)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
            ])),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(8)),
                child: Text(chipLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: kNavy, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E0), size: 20),
          ]),
        ),
      );
}

class _TileAbout extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle, trailing;
  const _TileAbout({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          _IconBox(icon: icon, bg: iconBg, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kNavy)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
          ])),
          Text(trailing, style: const TextStyle(fontSize: 13, color: Color(0xFF9AA5B4))),
        ]),
      );
}
