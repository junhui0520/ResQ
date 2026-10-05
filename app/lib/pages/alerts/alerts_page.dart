import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/alert_watcher.dart';
import '../../providers/language_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/alert_service.dart';
import '../../widgets/alert_card.dart';
import 'alert_detail_page.dart';

const Color kNavy = AppColors.navy;

/// 필터 목록 — 서버 alert_categories 코드와 일치
/// (기존: 앱은 'RAIN', 서버는 'RAIN/TYPHOON' 으로 저장해 호우·태풍 필터가 항상 비어 있던 문제 수정)
final List<CategoryStyle> kCategories = [CategoryStyle.all, ...CategoryStyle.list];

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<AlertModel> _alerts = [];
  String _selectedCategory = 'ALL';
  bool _isLoading = true;
  bool _offline = false;
  String? _error;
  String _loadedKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Provider.of<LanguageProvider>(context);
    final region = Provider.of<SettingsProvider>(context).regionFilter;
    final tick = Provider.of<AlertWatcher>(context).refreshTick;
    final key = '${lang.currentLang}|$region|$tick';
    if (!lang.isLoading && key != _loadedKey) {
      _loadedKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAll();
      });
    }
  }

  Future<void> _loadAll() async {
    final lang = context.read<LanguageProvider>().currentLang;
    final region = context.read<SettingsProvider>().regionFilter;
    setState(() {
      _error = null;
      _isLoading = _alerts.isEmpty;
    });
    try {
      final alerts = await AlertService.fetchAlerts(lang: lang, regionCode: region, limit: 100);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _offline = AlertService.lastFromCache;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AlertModel> get _filtered {
    if (_selectedCategory == 'ALL') return _alerts;
    return _alerts.where((a) => a.categoryCode == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: kNavy,
        elevation: 0,
        titleSpacing: 20,
        title: Text(lang.t('nav_alerts'),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _FilterBar(
            categories: kCategories,
            selectedCategory: _selectedCategory,
            lang: lang,
            onSelected: (code) => setState(() => _selectedCategory = code),
          ),
          if (_offline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF7E8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(lang.t('alerts_connection_error'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A5300))),
            ),
          Expanded(child: _buildBody(lang)),
        ],
      ),
    );
  }

  Widget _buildBody(LanguageProvider lang) {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: kNavy),
          const SizedBox(height: 14),
          Text(lang.t('alerts_loading'), style: const TextStyle(color: AppColors.textFaint)),
        ]),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_outlined, color: Color(0xFFCBD5E0), size: 48),
          const SizedBox(height: 12),
          Text(lang.t('alerts_connection_error'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textFaint, fontSize: 13, height: 1.6)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(lang.t('retry')),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      );
    }

    if (_filtered.isEmpty) {
      return RefreshIndicator(
        color: kNavy,
        onRefresh: _loadAll,
        child: ListView(children: [
          const SizedBox(height: 120),
          const Icon(Icons.notifications_none, color: Color(0xFFCBD5E0), size: 48),
          const SizedBox(height: 12),
          Center(child: Text(lang.t('alerts_empty'), style: const TextStyle(color: AppColors.textFaint))),
        ]),
      );
    }

    return RefreshIndicator(
      color: kNavy,
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: _filtered.length + 1,
        separatorBuilder: (_, i) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _filtered.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(lang.t('data_source_alerts'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
            );
          }
          final alert = _filtered[index];
          return AlertCard(
            alert: alert,
            lang: lang,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertDetailPage(alert: alert))),
          );
        },
      ),
    );
  }
}

// ── 필터 바 (좌우 화살표 포함) — 기존 디자인 유지 ─────────────────
class _FilterBar extends StatefulWidget {
  final List<CategoryStyle> categories;
  final String selectedCategory;
  final LanguageProvider lang;
  final void Function(String) onSelected;

  const _FilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.lang,
    required this.onSelected,
  });

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrows);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted || !_scrollController.hasClients) return;
    setState(() {
      _canScrollLeft = _scrollController.offset > 0;
      _canScrollRight = _scrollController.offset < _scrollController.position.maxScrollExtent;
    });
  }

  void _scrollBy(double delta) {
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(0.0, max),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _arrow({required bool visible, required IconData icon, required VoidCallback onTap, required double dx}) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: visible ? onTap : null,
        child: Container(
          width: 28,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: Offset(dx, 0))],
          ),
          child: Icon(icon, size: 20, color: kNavy),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _arrow(visible: _canScrollLeft, icon: Icons.chevron_left, onTap: () => _scrollBy(-150), dx: 2),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: widget.categories.map((cat) {
                  final isSelected = widget.selectedCategory == cat.code;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: widget.lang.t(cat.labelKey),
                      selected: isSelected,
                      activeColor: cat.code == 'ALL' ? kNavy : cat.color.withValues(alpha: 0.15),
                      activeTextColor: cat.code == 'ALL' ? Colors.white : cat.color,
                      onTap: () => widget.onSelected(cat.code),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          _arrow(visible: _canScrollRight, icon: Icons.chevron_right, onTap: () => _scrollBy(150), dx: -2),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final Color activeTextColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.activeTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? activeTextColor : AppColors.textMuted,
            )),
      ),
    );
  }
}
