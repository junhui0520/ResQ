import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/device_services.dart';
import '../../providers/language_provider.dart';
import '../../services/place_service.dart';

/// 주변 대피소 지도 (OpenStreetMap 타일 + 행정안전부 민방위 대피시설 데이터)
class ShelterMapPage extends StatefulWidget {
  const ShelterMapPage({super.key});

  @override
  State<ShelterMapPage> createState() => _ShelterMapPageState();
}

class _ShelterMapPageState extends State<ShelterMapPage> {
  final MapController _map = MapController();
  LatLng? _me;
  List<ShelterModel> _shelters = [];
  bool _loading = true;
  bool _dataLoaded = true;
  bool _isSample = false;
  String? _errorKey;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    final loc = await LocationService.current();
    if (!mounted) return;
    if (!loc.ok) {
      setState(() {
        _loading = false;
        _errorKey = loc.failure == LocationFailure.denied ? 'location_permission_needed' : 'location_unavailable';
      });
      return;
    }
    final me = LatLng(loc.lat!, loc.lng!);
    try {
      var result = await PlaceService.nearbyShelters(me.latitude, me.longitude, radiusKm: 2);
      if (result.shelters.isEmpty && result.dataLoaded) {
        result = await PlaceService.nearbyShelters(me.latitude, me.longitude, radiusKm: 10);
      }
      if (!mounted) return;
      setState(() {
        _me = me;
        _shelters = result.shelters;
        _dataLoaded = result.dataLoaded;
        _isSample = result.isSample;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(me, 15);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _me = me;
        _loading = false;
        _errorKey = 'alerts_connection_error';
      });
    }
  }

  void _focus(ShelterModel s) {
    setState(() => _selectedId = s.id);
    _map.move(LatLng(s.latitude, s.longitude), 16);
  }

  String _distance(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    // 위치를 모를 때 기본 중심: 서울시청 (기존 앱 지역 좌표)
    final center = _me ?? LatLng(37.5665, 126.9780);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(lang.t('shelters_nearby'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.my_location))],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(initialCenter: center, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'kr.ac.bu.resq',
                ),
                MarkerLayer(markers: [
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ..._shelters.map((s) => Marker(
                        point: LatLng(s.latitude, s.longitude),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _focus(s),
                          child: Icon(
                            Icons.location_on,
                            size: 40,
                            color: s.id == _selectedId ? AppColors.emergencyRed : const Color(0xFF2E7D32),
                          ),
                        ),
                      )),
                ]),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => Launch.url('https://www.openstreetmap.org/copyright'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(lang)),
        ],
      ),
    );
  }

  Widget _buildList(LanguageProvider lang) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    if (_errorKey != null) {
      return _Message(icon: Icons.location_off_outlined, text: lang.t(_errorKey!), action: lang.t('retry'), onAction: _load);
    }
    if (!_dataLoaded) {
      return _Message(icon: Icons.storage_outlined, text: lang.t('shelters_not_loaded'));
    }
    if (_shelters.isEmpty) {
      return _Message(icon: Icons.search_off, text: lang.t('shelters_empty'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _shelters.length + 1,
      separatorBuilder: (_, i) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == _shelters.length) {
          if (_isSample) {
            return Text(lang.t('shelter_source_sample'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC62828)));
          }
          return Text(lang.t('shelter_source'),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textFaint));
        }
        final s = _shelters[i];
        final selected = s.id == _selectedId;
        return Material(
          color: selected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _focus(s),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 52,
                  alignment: Alignment.center,
                  child: Text(_distance(s.distanceKm),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    if (s.address.isNotEmpty)
                      Text(s.address, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (s.type.isNotEmpty)
                      Text(s.type, style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
                  ]),
                ),
                TextButton.icon(
                  onPressed: () => Launch.directions(s.latitude, s.longitude),
                  icon: const Icon(Icons.directions_walk, size: 18),
                  label: Text(lang.t('directions')),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Message({required this.icon, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: const Color(0xFFCBD5E0)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, height: 1.5)),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      ),
    );
  }
}
