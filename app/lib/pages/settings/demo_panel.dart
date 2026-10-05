import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../providers/alert_watcher.dart';
import '../../services/admin_service.dart';

/// 발표·영상 촬영용 데모 메뉴 (설정 > 앱 버전 5번 탭)
/// 서버 ADMIN_KEY 가 필요하며, 만든 알림은 [ResQ 데모] 로 표시되어 실제 재난문자와 구분됩니다.
/// 발표자 전용 화면이라 한국어/영어로만 표시합니다.
class DemoPanel extends StatefulWidget {
  const DemoPanel({super.key});

  @override
  State<DemoPanel> createState() => _DemoPanelState();
}

class _DemoPanelState extends State<DemoPanel> {
  static const _kKey = 'demo_admin_key';
  final _keyCtrl = TextEditingController();
  List<Map<String, dynamic>> _presets = [];
  Map<String, dynamic>? _stats;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString(_kKey);
      if (saved != null && mounted) {
        _keyCtrl.text = saved;
        _connect();
      }
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      _message = '실패 / Failed: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _connect() => _run(() async {
        final key = _keyCtrl.text.trim();
        _presets = await AdminService.presets(key);
        _stats = await AdminService.stats(key);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kKey, key);
        _message = '연결됨 / Connected';
      });

  Future<void> _send(String preset) => _run(() async {
        await AdminService.sendDemoAlert(_keyCtrl.text.trim(), preset);
        _stats = await AdminService.stats(_keyCtrl.text.trim());
        _message = '데모 알림 전송 / Demo alert sent: $preset';
        if (mounted) await context.read<AlertWatcher>().check();
      });

  Future<void> _clear() => _run(() async {
        final n = await AdminService.clearDemoAlerts(_keyCtrl.text.trim());
        _stats = await AdminService.stats(_keyCtrl.text.trim());
        _message = '데모 알림 $n건 삭제 / Deleted';
      });

  Future<void> _fetchNow() => _run(() async {
        final r = await AdminService.fetchNow(_keyCtrl.text.trim());
        _stats = await AdminService.stats(_keyCtrl.text.trim());
        _message = '재난문자 수집 / Fetched: 신규 ${r['saved']}건';
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Demo mode (발표용)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('서버 .env 의 ADMIN_KEY 를 입력하세요. 데모 알림은 [ResQ 데모] 로 표시되고 실제 재난문자와 구분됩니다.',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Admin key', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _connect, child: const Text('연결 / Connect')),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (_stats != null) ...[
            const SizedBox(height: 12),
            Text('알림 ${_stats!['alerts']?['total']}건 (발령 중 ${_stats!['alerts']?['active']}, 데모 ${_stats!['alerts']?['demo']}) · '
                '대피소 ${_stats!['shelters']}곳 · 오늘 번역 ${_stats!['translation_chars_today']}자'),
          ],
          if (_presets.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('데모 알림 보내기 / Send demo alert', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._presets.map((p) => Card(
                  child: ListTile(
                    title: Text('${p['key']} · ${p['category_code']} · ${p['severity_code']}'),
                    subtitle: Text('${p['message_ko']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.send),
                    onTap: _busy ? null : () => _send('${p['key']}'),
                  ),
                )),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('데모 알림 모두 삭제 / Clear demo alerts'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _fetchNow,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('실제 재난문자 지금 수집 / Fetch real alerts now'),
            ),
          ],
        ],
      ),
    );
  }
}
