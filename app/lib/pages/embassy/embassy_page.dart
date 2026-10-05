import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/device_services.dart';
import '../../providers/language_provider.dart';
import '../../services/embassy_service.dart';

const Color kNavy = AppColors.navy;

/// 대사관 (기존 카드 디자인 유지)
/// 변경: 서버 API 사용(국가명 번역은 서버 공식 번역 API) + 오프라인이면 내장 목록,
///       전화번호 정규화로 실제 전화 연결, 지도·이메일 버튼 추가
///       (주소는 기계번역 시 고유명사가 깨질 수 있어 원문 유지)
class EmbassyPage extends StatefulWidget {
  const EmbassyPage({super.key});

  @override
  State<EmbassyPage> createState() => _EmbassyPageState();
}

class _EmbassyPageState extends State<EmbassyPage> {
  List<EmbassyModel> _embassyList = [];
  List<EmbassyModel> _filteredList = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _offline = false;
  String? _loadedLang;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Provider.of<LanguageProvider>(context);
    if (!lang.isLoading && _loadedLang != lang.currentLang) {
      _loadedLang = lang.currentLang;
      _load(lang.currentLang);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load(String lang) async {
    final list = await EmbassyService.fetchEmbassies(lang: lang);
    if (!mounted) return;
    setState(() {
      _embassyList = list;
      _offline = EmbassyService.lastFromAsset;
      _isLoading = false;
    });
    _onSearchChanged();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredList = query.isEmpty
          ? List.of(_embassyList)
          : _embassyList
              .where((e) => e.nameTranslated.toLowerCase().contains(query) || e.nameEn.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: Text(lang.t('nav_embassy'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: lang.t('embassy_search_hint'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade400),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_offline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF7E8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(lang.t('embassy_offline'), style: const TextStyle(fontSize: 12, color: Color(0xFF8A5300))),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kNavy))
                : _filteredList.isEmpty
                    ? Center(
                        child: Text(lang.t('embassy_no_results'),
                            style: const TextStyle(color: Colors.grey, fontSize: 15)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredList.length,
                        itemBuilder: (context, index) => _EmbassyCard(data: _filteredList[index], lang: lang),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmbassyCard extends StatelessWidget {
  final EmbassyModel data;
  final LanguageProvider lang;
  const _EmbassyCard({required this.data, required this.lang});

  @override
  Widget build(BuildContext context) {
    final showEnglish = data.nameTranslated != data.nameEn;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.flag, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.nameTranslated,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                if (showEnglish)
                  Text(data.nameEn, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: kNavy),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(data.addressEn,
                          style: const TextStyle(fontSize: 13, color: kNavy, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _ActionPill(
                    icon: Icons.call,
                    label: data.phoneDial ?? data.phone,
                    onTap: () => Launch.call(data.phoneDial ?? data.phone),
                  ),
                  if (data.addressEn.isNotEmpty)
                    _ActionPill(
                      icon: Icons.map_outlined,
                      label: lang.t('embassy_map'),
                      onTap: () => Launch.mapSearch('${data.nameEn} ${data.addressEn}'),
                    ),
                  if (data.email != null)
                    _ActionPill(
                      icon: Icons.mail_outline,
                      label: lang.t('embassy_email'),
                      onTap: () => Launch.email(data.email!),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kNavy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: kNavy, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
