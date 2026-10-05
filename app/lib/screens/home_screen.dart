import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/time_format.dart';
import '../pages/alerts/alert_detail_page.dart';
import '../pages/helper/emergency_helper_page.dart';
import '../pages/shelters/shelter_map_page.dart';
import '../providers/alert_watcher.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../services/alert_service.dart';
import '../widgets/action_card.dart';
import '../widgets/alert_card.dart';
import 'call119.dart';
import 'qr_result_screen.dart';
import 'safetyguide.dart';

const Color kNavy = AppColors.navy;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AlertModel> _recentAlerts = [];
  List<AlertModel> _activeAlerts = [];
  bool _isLoading = true;
  bool _offline = false;
  String _loadedKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 언어·지역 변경 또는 새 알림 도착 시 다시 불러오기 (기존: 언어 변경만 감지)
    final lang = Provider.of<LanguageProvider>(context);
    final region = Provider.of<SettingsProvider>(context).regionFilter;
    final tick = Provider.of<AlertWatcher>(context).refreshTick;
    final key = '${lang.currentLang}|$region|$tick';
    if (!lang.isLoading && key != _loadedKey) {
      _loadedKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchAlerts();
      });
    }
  }

  Future<void> _fetchAlerts() async {
    final lang = context.read<LanguageProvider>().currentLang;
    final region = context.read<SettingsProvider>().regionFilter;
    setState(() => _isLoading = _recentAlerts.isEmpty);
    try {
      final alerts = await AlertService.fetchAlerts(lang: lang, regionCode: region, limit: 20);
      if (!mounted) return;
      // 발령 중 알림: 심각도 높은 순 → 최신순
      final active = alerts.where((a) => a.isActive).toList()
        ..sort((a, b) {
          final bySeverity = b.severityLevel.compareTo(a.severityLevel);
          return bySeverity != 0 ? bySeverity : b.issuedAt.compareTo(a.issuedAt);
        });
      setState(() {
        _activeAlerts = active;
        _recentAlerts = alerts.take(5).toList();
        _offline = AlertService.lastFromCache;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _offline = true; });
    }
  }

  void _openAlert(AlertModel alert) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AlertDetailPage(alert: alert)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final settings = context.watch<SettingsProvider>();
    final regionLabel = settings.regionCode == 'ALL'
        ? lang.t('region_all')
        : lang.t('region_${settings.regionCode.toLowerCase()}');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: kNavy,
        elevation: 0,
        titleSpacing: 20,
        title: const Text('ResQ', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrResultScreen())),
              icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 18),
              label: const Text('My Info', style: TextStyle(color: Colors.white, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAlerts,
        color: kNavy,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            if (_offline)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  const Icon(Icons.cloud_off, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(lang.t('alerts_connection_error'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ),
                ]),
              ),
            if (_isLoading)
              const _LoadingCard()
            else if (_activeAlerts.isNotEmpty)
              _DangerCard(
                alert: _activeAlerts.first,
                moreCount: _activeAlerts.length - 1,
                lang: lang,
                onTap: () => _openAlert(_activeAlerts.first),
              )
            else
              _SafeCard(lang: lang, regionLabel: regionLabel),

            const SizedBox(height: 24),
            SectionLabel(lang.t('quick_actions')),
            const SizedBox(height: 10),
            _EmergencyCallCard(lang: lang),
            const SizedBox(height: 10),
            ActionCard(
              icon: Icons.record_voice_over_outlined,
              iconColor: const Color(0xFFDC2626),
              iconBg: const Color(0xFFFFE4E6),
              title: lang.t('helper_title'),
              subtitle: lang.t('helper_sub'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyHelperPage())),
            ),
            const SizedBox(height: 10),
            ActionCard(
              icon: Icons.night_shelter_outlined,
              iconColor: const Color(0xFF2E7D32),
              iconBg: const Color(0xFFE8F5E9),
              title: lang.t('shelters_title'),
              subtitle: lang.t('shelters_sub'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShelterMapPage())),
            ),
            const SizedBox(height: 10),
            ActionCard(
              icon: Icons.menu_book_outlined,
              title: lang.t('safety_guide'),
              subtitle: lang.t('safety_guide_sub'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyGuideScreen())),
            ),

            const SizedBox(height: 24),
            SectionLabel(lang.t('recent_alerts')),
            const SizedBox(height: 10),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: kNavy)))
            else if (_recentAlerts.isEmpty)
              _EmptyAlerts(lang: lang)
            else
              ..._recentAlerts.map((alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AlertCard(alert: alert, lang: lang, onTap: () => _openAlert(alert)),
                  )),
            const SizedBox(height: 8),
            Text(lang.t('data_source_alerts'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.safeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
      ),
    );
  }
}

class _SafeCard extends StatelessWidget {
  final LanguageProvider lang;
  final String regionLabel;
  const _SafeCard({required this.lang, required this.regionLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.safeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.circle, color: Color(0xFF4CAF50), size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Text(lang.t('no_active_alerts'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(lang.t('area_safe'), style: const TextStyle(fontSize: 14, color: Color(0xFF4A5568), height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFD0EED1), borderRadius: BorderRadius.circular(20)),
            // 기존: 'All clear · Cheonan' 고정 → 선택한 지역 표시
            child: Text('${lang.t('all_clear')} · $regionLabel',
                style: const TextStyle(fontSize: 13, color: AppColors.safe, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  final AlertModel alert;
  final int moreCount;
  final LanguageProvider lang;
  final VoidCallback onTap;
  const _DangerCard({required this.alert, required this.moreCount, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final regionLabel = lang.t('region_${alert.regionCode.toLowerCase()}');
    return Material(
      color: AppColors.dangerBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE58E8E), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SeverityBadge(code: alert.severityCode, lang: lang),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(lang.t('active_alert_in_area'),
                      style: const TextStyle(fontSize: 12, color: AppColors.dangerText, fontWeight: FontWeight.w700)),
                ),
                Text(timeAgo(alert.issuedAtLocal, lang),
                    style: const TextStyle(fontSize: 13, color: AppColors.dangerText, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(alert.displayTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dangerText)),
              const SizedBox(height: 8),
              Text(lang.t('alert_tap_to_translate'),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7A2020), height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFCFCF), borderRadius: BorderRadius.circular(20)),
                  child: Text('${lang.t('alert_active')} · $regionLabel',
                      style: const TextStyle(fontSize: 12, color: AppColors.dangerText, fontWeight: FontWeight.w600)),
                ),
                if (moreCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text(lang.tf('more_alerts', {'n': moreCount}),
                        style: const TextStyle(fontSize: 12, color: AppColors.dangerText, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyCallCard extends StatelessWidget {
  final LanguageProvider lang;
  const _EmergencyCallCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kNavy,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Call119Screen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: const Center(
                child: Text('119', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.t('call_119'),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(lang.t('fire_ambulance'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ]),
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  final LanguageProvider lang;
  const _EmptyAlerts({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Icon(Icons.notifications_none, color: Colors.grey[400], size: 40),
        const SizedBox(height: 8),
        Text(lang.t('no_recent_alerts'), style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]),
    );
  }
}
