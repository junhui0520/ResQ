import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/device_services.dart';
import '../providers/language_provider.dart';
import '../services/qr_service.dart';

const Color kNavy = Color(0xFF243F73);
const Color kTextNavy = Color(0xFF152A5C);
const Color kPurple = Color(0xFF777FC8);

/// My Info (응급 정보) — 기존 디자인 유지
/// 변경: 응급 QR 코드 표시(구조대원이 스캔하면 한국어 응급정보 페이지),
///       연락처·의료정보 서버 저장, 삭제 버그 수정, 전화 버튼 동작, 문구 다국어화
class QrResultScreen extends StatefulWidget {
  const QrResultScreen({super.key});

  @override
  State<QrResultScreen> createState() => _QrResultScreenState();
}

class _QrResultScreenState extends State<QrResultScreen> {
  QrProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    final p = await QrService.load();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _isLoading = false;
    });
  }

  Future<void> _deleteProfile() async {
    final lang = context.read<LanguageProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('delete_profile')),
        content: Text(lang.t('delete_profile_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.t('delete'), style: const TextStyle(color: Color(0xFFC94A4A))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await QrService.delete();
    if (mounted) setState(() => _profile = null);
  }

  void _openEditSheet(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ChangeNotifierProvider.value(
        value: lang,
        child: _EditSheet(
          profile: _profile,
          onSaved: (updated, synced) {
            Navigator.pop(context);
            setState(() => _profile = updated);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(synced ? lang.t('saved') : lang.t('saved_offline'))),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4FA),
      body: SafeArea(
        child: Column(
          children: [
            _Header(lang: lang),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kNavy))
                  : _profile != null
                      ? _ProfileView(
                          profile: _profile!,
                          lang: lang,
                          onEdit: () => _openEditSheet(context),
                          onDelete: _deleteProfile,
                        )
                      : _EmptyView(lang: lang, onSetup: () => _openEditSheet(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final LanguageProvider lang;
  const _Header({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: kNavy,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.t('emergency_info'),
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(lang.t('scanned_from'),
                  style: const TextStyle(color: Color(0xFFC9D3F1), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 미등록 화면 ───────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final LanguageProvider lang;
  final VoidCallback onSetup;
  const _EmptyView({required this.lang, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: const Color(0xFFEEF0FB), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.qr_code_2, color: kNavy, size: 44),
          ),
          const SizedBox(height: 24),
          Text(lang.t('qr_not_setup'),
              style: const TextStyle(color: kTextNavy, fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(lang.t('qr_not_setup_sub'),
              style: const TextStyle(color: kPurple, fontSize: 14, height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(lang.t('setup_my_info'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 프로필 화면 ───────────────────────────────────────────────
class _ProfileView extends StatelessWidget {
  final QrProfile profile;
  final LanguageProvider lang;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileView({required this.profile, required this.lang, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final allergies = profile.allergies;
    final conditions = profile.conditions;
    final genderLabel = profile.gender == 'male'
        ? lang.t('male')
        : profile.gender == 'female'
            ? lang.t('female')
            : profile.gender;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        children: [
          // 응급 QR (신규)
          _QrCard(url: profile.qrUrl, lang: lang),
          const SizedBox(height: 14),

          // 기본 정보
          _card(
              child: Column(children: [
            Row(children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: kNavy,
                child: Icon(Icons.person_outline, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(profile.name, style: const TextStyle(color: kTextNavy, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                    [profile.nationality, genderLabel, if (profile.age > 0) '${profile.age}']
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: kPurple, fontSize: 13, fontWeight: FontWeight.w700)),
              ])),
            ]),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFE5E7F2)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _infoBox(
                      title: lang.t('blood_type'),
                      value: profile.bloodType.isEmpty ? '-' : profile.bloodType,
                      valueColor: const Color(0xFFC0392B))),
              const SizedBox(width: 12),
              Expanded(
                  child: _infoBox(
                      title: lang.t('nationality'),
                      value: profile.nationality.isEmpty ? '-' : profile.nationality,
                      valueColor: kTextNavy)),
            ]),
          ])),

          // 긴급 연락처
          if (profile.contacts.isNotEmpty) ...[
            const SizedBox(height: 14),
            _card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _cardTitle(lang.t('emergency_contacts')),
              const SizedBox(height: 12),
              ...profile.contacts.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _contactRow(c),
                  )),
            ])),
          ],

          // 의료 정보
          if (allergies.isNotEmpty || conditions.isNotEmpty) ...[
            const SizedBox(height: 14),
            _card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _cardTitle(lang.t('medical_info')),
              if (allergies.isNotEmpty) ...[
                const SizedBox(height: 14),
                _subTitle(lang.t('allergies')),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allergies
                        .map((m) => _chip(m.value, const Color(0xFFFFE5E5), const Color(0xFFC94A4A)))
                        .toList()),
              ],
              if (conditions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE5E7F2)),
                const SizedBox(height: 12),
                _subTitle(lang.t('conditions')),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: conditions
                        .map((m) => _chip(m.value, const Color(0xFFE9E9FB), const Color(0xFF5D65B3)))
                        .toList()),
              ],
            ])),
          ],

          const SizedBox(height: 14),
          // 경고
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD89C)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD36B2C), size: 23),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(lang.t('qr_warning'),
                      style: const TextStyle(
                          color: Color(0xFFC1632A), fontSize: 14, fontWeight: FontWeight.w700, height: 1.35))),
            ]),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
              label: Text(lang.t('edit_my_info'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFC94A4A), size: 18),
              label: Text(lang.t('delete_profile'),
                  style: const TextStyle(color: Color(0xFFC94A4A), fontSize: 16, fontWeight: FontWeight.w900)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFC94A4A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(EmergencyContact c) {
    return Row(children: [
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.name, style: const TextStyle(color: kTextNavy, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text([c.relationship, c.phone].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(color: Color(0xFF8B92CF), fontSize: 12, fontWeight: FontWeight.w700)),
      ])),
      // 기존: 버튼 모양만 있고 동작 없음 → 전화 연결
      Material(
        color: kNavy,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => Launch.call(c.phone),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              const Icon(Icons.call, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Text(lang.t('call'),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _infoBox({required String title, required String value, required Color valueColor}) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF6F7FC), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFFB2B6DA), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, height: 1.15)),
        const Spacer(),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: valueColor, fontSize: 17, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1E4EF))),
        child: child,
      );

  Widget _cardTitle(String text) => Text(text,
      style: const TextStyle(color: Color(0xFF8A91CD), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2));

  Widget _subTitle(String text) => Text(text,
      style: const TextStyle(color: Color(0xFFB2B6DA), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1));

  Widget _chip(String text, Color bgColor, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w900)),
      );
}

// ── 응급 QR 카드 (신규) ────────────────────────────────────────
class _QrCard extends StatelessWidget {
  final String? url;
  final LanguageProvider lang;
  const _QrCard({required this.url, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E4EF)),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.qr_code_2, color: kNavy),
          const SizedBox(width: 8),
          Text(lang.t('my_qr_title'),
              style: const TextStyle(color: kTextNavy, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        Text(lang.t('my_qr_desc'), style: const TextStyle(color: kPurple, fontSize: 13, height: 1.4)),
        const SizedBox(height: 14),
        if (url == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF6F7FC), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.cloud_off, color: kPurple),
              const SizedBox(width: 10),
              Expanded(child: Text(lang.t('qr_needs_server'), style: const TextStyle(color: kTextNavy))),
            ]),
          )
        else ...[
          QrImageView(
            data: url!,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: kTextNavy),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: kTextNavy),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: () => Launch.url(url!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(lang.t('open_responder_page')),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('link_copied'))));
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text(lang.t('copy_link')),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── 편집 바텀시트 (기존 구성 유지) ─────────────────────────────────
class _EditSheet extends StatefulWidget {
  final QrProfile? profile;
  final void Function(QrProfile profile, bool synced) onSaved;
  const _EditSheet({this.profile, required this.onSaved});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _nameCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = 'male';
  String _bloodType = 'A+';

  // 긴급 연락처 (최대 3개)
  final List<Map<String, TextEditingController>> _contacts = [];
  // 의료 정보
  final List<TextEditingController> _allergies = [];
  final List<TextEditingController> _conditions = [];

  bool _isSaving = false;
  bool _nameError = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    if (p != null) {
      _nameCtrl.text = p.name;
      _nationalityCtrl.text = p.nationality;
      _ageCtrl.text = p.age > 0 ? p.age.toString() : '';
      _gender = p.gender.isNotEmpty ? p.gender : 'male';
      _bloodType = _bloodTypes.contains(p.bloodType) ? p.bloodType : 'A+';
      for (final c in p.contacts) {
        _contacts.add({
          'name': TextEditingController(text: c.name),
          'relationship': TextEditingController(text: c.relationship),
          'phone': TextEditingController(text: c.phone),
        });
      }
      for (final m in p.medicalInfos) {
        final ctrl = TextEditingController(text: m.value);
        if (m.category == 'allergy') {
          _allergies.add(ctrl);
        } else {
          _conditions.add(ctrl);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nationalityCtrl.dispose();
    _ageCtrl.dispose();
    for (final c in _contacts) {
      for (final ctrl in c.values) {
        ctrl.dispose();
      }
    }
    for (final a in _allergies) {
      a.dispose();
    }
    for (final c in _conditions) {
      c.dispose();
    }
    super.dispose();
  }

  void _addContact() {
    if (_contacts.length >= 3) return;
    setState(() {
      _contacts.add({
        'name': TextEditingController(),
        'relationship': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeContact(int index) {
    setState(() {
      for (final ctrl in _contacts[index].values) {
        ctrl.dispose();
      }
      _contacts.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    setState(() => _isSaving = true);

    final profile = QrProfile(
      name: _nameCtrl.text.trim(),
      gender: _gender,
      age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
      bloodType: _bloodType,
      nationality: _nationalityCtrl.text.trim(),
      contacts: _contacts
          .where((c) => c['name']!.text.trim().isNotEmpty && c['phone']!.text.trim().isNotEmpty)
          .map((c) => EmergencyContact(
                name: c['name']!.text.trim(),
                relationship: c['relationship']!.text.trim(),
                phone: c['phone']!.text.trim(),
              ))
          .toList(),
      medicalInfos: [
        ..._allergies.where((a) => a.text.trim().isNotEmpty).map((a) => MedicalInfo(category: 'allergy', value: a.text.trim())),
        ..._conditions
            .where((c) => c.text.trim().isNotEmpty)
            .map((c) => MedicalInfo(category: 'condition', value: c.text.trim())),
      ],
      qrUrl: widget.profile?.qrUrl,
    );

    final lang = context.read<LanguageProvider>();
    final (result, saved) = await QrService.save(profile, languageCode: lang.currentLang);
    if (!mounted) return;
    setState(() => _isSaving = false);
    widget.onSaved(saved, result == SaveResult.synced);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),
            Text(lang.t('edit_my_info'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kTextNavy)),
            const SizedBox(height: 20),

            // ── 기본 정보 ──────────────────────────────────────
            _sectionHeader(lang.t('basic_info')),
            const SizedBox(height: 12),
            _label(lang.t('name')),
            _textField(_nameCtrl, lang.t('name_hint'), errorText: _nameError ? lang.t('name_required') : null),
            const SizedBox(height: 14),
            _label(lang.t('nationality')),
            _textField(_nationalityCtrl, lang.t('nationality_hint')),
            const SizedBox(height: 14),
            _label(lang.t('age')),
            _textField(_ageCtrl, lang.t('age_hint'), keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            _label(lang.t('gender')),
            Row(children: [
              _genderChip(lang.t('male'), 'male'),
              const SizedBox(width: 10),
              _genderChip(lang.t('female'), 'female'),
            ]),
            const SizedBox(height: 14),
            _label(lang.t('blood_type')),
            Wrap(spacing: 8, runSpacing: 8, children: _bloodTypes.map(_bloodChip).toList()),

            const SizedBox(height: 24),

            // ── 긴급 연락처 ────────────────────────────────────
            _sectionHeader(lang.t('emergency_contacts')),
            const SizedBox(height: 12),
            ..._contacts.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${lang.t('contact')} ${i + 1}',
                        style: const TextStyle(color: kPurple, fontSize: 12, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: () => _removeContact(i),
                      child: const Icon(Icons.close, size: 18, color: Color(0xFF9AA5B4)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _label(lang.t('name')),
                  _textField(c['name']!, lang.t('name_hint')),
                  const SizedBox(height: 10),
                  _label(lang.t('relationship')),
                  _textField(c['relationship']!, lang.t('relationship_hint')),
                  const SizedBox(height: 10),
                  _label(lang.t('phone')),
                  _textField(c['phone']!, lang.t('phone_hint'), keyboardType: TextInputType.phone),
                ]),
              );
            }),
            if (_contacts.length < 3) _addButton(lang.t('add_contact'), _addContact),

            const SizedBox(height: 24),

            // ── 알레르기 ────────────────────────────────────────
            _sectionHeader(lang.t('allergies')),
            const SizedBox(height: 12),
            ..._valueRows(_allergies, lang.t('allergy_hint'), const Color(0xFFFFE5E5), const Color(0xFFC94A4A)),
            _addButton(lang.t('add_allergy'), () => setState(() => _allergies.add(TextEditingController()))),

            const SizedBox(height: 24),

            // ── 질환 ────────────────────────────────────────────
            _sectionHeader(lang.t('conditions')),
            const SizedBox(height: 12),
            ..._valueRows(_conditions, lang.t('condition_hint'), const Color(0xFFE9E9FB), const Color(0xFF5D65B3)),
            _addButton(lang.t('add_condition'), () => setState(() => _conditions.add(TextEditingController()))),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(lang.t('save'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _valueRows(List<TextEditingController> list, String hint, Color bg, Color fg) {
    return list.asMap().entries.map((entry) {
      final i = entry.key;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: _textField(entry.value, hint)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              list[i].dispose();
              list.removeAt(i);
            }),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.close, size: 18, color: fg),
            ),
          ),
        ]),
      );
    }).toList();
  }

  Widget _sectionHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: kNavy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.circle, size: 6, color: kNavy),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: kNavy, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add, size: 18, color: kPurple),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: kPurple, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: kPurple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  Widget _textField(TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text, String? errorText}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      onChanged: errorText != null ? (_) => setState(() => _nameError = false) : null,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        hintStyle: const TextStyle(color: Color(0xFFB2B6DA)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kNavy, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _genderChip(String label, String value) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kNavy : const Color(0xFFF6F7FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? kNavy : const Color(0xFFE2E8F0)),
        ),
        child: Text(label,
            style: TextStyle(color: isSelected ? Colors.white : kPurple, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  Widget _bloodChip(String value) {
    final isSelected = _bloodType == value;
    return GestureDetector(
      onTap: () => setState(() => _bloodType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kNavy : const Color(0xFFF6F7FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? kNavy : const Color(0xFFE2E8F0)),
        ),
        child: Text(value,
            style: TextStyle(color: isSelected ? Colors.white : kPurple, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}
