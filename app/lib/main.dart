import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/device_services.dart';
import 'core/user_session.dart';
import 'screens/home_screen.dart';
import 'pages/alerts/alerts_page.dart';
import 'pages/alerts/alert_detail_page.dart';
import 'pages/embassy/embassy_page.dart';
import 'pages/onboarding/onboarding_page.dart';
import 'pages/settings/settings_page.dart';
import 'providers/alert_watcher.dart';
import 'providers/language_provider.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 저장된 언어·설정 미리 로드
  final langProvider = LanguageProvider();
  await langProvider.init();
  final settings = SettingsProvider();
  await settings.init();

  await UserSession.init(languageCode: langProvider.currentLang);
  settings.syncFromServer(); // 기다리지 않음

  final watcher = AlertWatcher();
  await watcher.start(lang: langProvider.currentLang, region: settings.regionFilter, enabled: settings.alertBanner);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: langProvider),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: watcher),
      ],
      child: const ResQApp(),
    ),
  );
}

class ResQApp extends StatelessWidget {
  const ResQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQ',
      theme: buildAppTheme(),
      // 웹(PC 브라우저)에서는 휴대폰 크기 화면으로 가운데 표시 → 발표 영상에서 앱처럼 보이도록
      builder: (context, child) => _PhoneFrame(child: child ?? const SizedBox()),
      home: const _RootGate(),
    );
  }
}

/// 첫 실행이면 언어 선택, 아니면 메인 화면
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<LanguageProvider, bool>((l) => l.onboarded);
    return onboarded ? const MainScaffold() : const OnboardingPage();
  }
}

class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= 600) return child;
    const width = 430.0;
    return ColoredBox(
      color: const Color(0xFFDDE2EC),
      child: Center(
        child: Container(
          width: width,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 10))],
          ),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery(
            data: mq.copyWith(size: Size(width, mq.size.height - 32)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  int? _spokenAlertId;

  static const List<Widget> _pages = [
    HomeScreen(),
    AlertsPage(),
    EmbassyPage(),
    SettingsPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 언어·지역·알림 설정이 바뀌면 새 알림 감시 조건도 갱신
    final lang = Provider.of<LanguageProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    if (!lang.isLoading) {
      context.read<AlertWatcher>().configure(
            lang: lang.currentLang,
            region: settings.regionFilter,
            enabled: settings.alertBanner,
          );
    }
  }

  void _maybeSpeak(AlertWatcher watcher, LanguageProvider lang, SettingsProvider settings) {
    final a = watcher.newAlert;
    if (a == null || !settings.readAloud || !a.isUrgent || _spokenAlertId == a.id) return;
    _spokenAlertId = a.id;
    final locale = a.translated ? lang.ttsLocale : 'ko-KR';
    TtsService.speak('${a.displayTitle}. ${a.content}', locale);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final settings = context.watch<SettingsProvider>();
    final watcher = context.watch<AlertWatcher>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSpeak(watcher, lang, settings));

    return Scaffold(
      body: Stack(
        children: [
          // 탭을 바꿔도 각 화면 상태(스크롤·검색어)를 유지
          IndexedStack(index: _selectedIndex, children: _pages),
          if (watcher.newAlert != null)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: _NewAlertBanner(
                title: watcher.newAlert!.displayTitle,
                severityCode: watcher.newAlert!.severityCode,
                label: lang.t('new_alert'),
                viewLabel: lang.t('view'),
                onView: () {
                  final alert = watcher.newAlert!;
                  watcher.dismiss();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AlertDetailPage(alert: alert)),
                  );
                },
                onDismiss: () {
                  TtsService.stop();
                  watcher.dismiss();
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.navy,
        unselectedItemColor: AppColors.textFaint,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: lang.t('nav_home')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.notifications_outlined),
              activeIcon: const Icon(Icons.notifications),
              label: lang.t('nav_alerts')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.business_outlined),
              activeIcon: const Icon(Icons.business),
              label: lang.t('nav_embassy')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: lang.t('nav_settings')),
        ],
      ),
    );
  }
}

/// 새 알림 배너 (화면 상단)
class _NewAlertBanner extends StatelessWidget {
  final String title;
  final String severityCode;
  final String label;
  final String viewLabel;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  const _NewAlertBanner({
    required this.title,
    required this.severityCode,
    required this.label,
    required this.viewLabel,
    required this.onView,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = SeverityStyle.color(severityCode);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onView,
                child: Text(viewLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
