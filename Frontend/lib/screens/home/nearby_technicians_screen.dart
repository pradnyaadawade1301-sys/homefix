import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';

/// Shows available technicians for a category on a live map, nearest-first, using the
/// customer's current location (real GPS via `location` package). Map tiles are
/// OpenStreetMap (free, no API key) via flutter_map. Backs onto GET /technicians/available.
class NearbyTechniciansScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const NearbyTechniciansScreen({Key? key, required this.categoryId, required this.categoryName})
      : super(key: key);

  @override
  State<NearbyTechniciansScreen> createState() => _NearbyTechniciansScreenState();
}

enum _LoadState { locating, locationDenied, ready }

class _NearbyTechniciansScreenState extends State<NearbyTechniciansScreen> {
  final MapController _mapController = MapController();

  double? _myLat;
  double? _myLng;
  _LoadState _state = _LoadState.locating;
  String? _selectedTechId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLocationAndFetch());
  }

  Future<void> _resolveLocationAndFetch() async {
    setState(() => _state = _LoadState.locating);
    try {
      // Use the shared LocationProvider instead of creating a local loc.Location
      final locProvider = context.read<LocationProvider>();
      await locProvider.resolveLocation();

      if (locProvider.hasLocation) {
        _myLat = locProvider.latitude;
        _myLng = locProvider.longitude;
        setState(() => _state = _LoadState.ready);
      } else {
        setState(() => _state = _LoadState.locationDenied);
      }
      await _fetchTechnicians();
    } catch (_) {
      setState(() => _state = _LoadState.locationDenied);
      await _fetchTechnicians();
    }
  }

  Future<void> _fetchTechnicians() async {
    if (!mounted) return;
    await context.read<NearbyTechnicianProvider>().fetchNearby(
          categoryId: widget.categoryId,
          lat: _myLat,
          lng: _myLng,
        );
    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    final techs = context.read<NearbyTechnicianProvider>().technicians;
    final points = <LatLng>[
      if (_myLat != null && _myLng != null) LatLng(_myLat!, _myLng!),
      ...techs.where((t) => t.hasLocation).map((t) => LatLng(t.currentLat!, t.currentLng!)),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 13);
      return;
    }
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nearby ${widget.categoryName}')),
      body: Consumer<NearbyTechnicianProvider>(
        builder: (context, provider, _) {
          final markers = <Marker>[];
          if (_myLat != null && _myLng != null) {
            markers.add(Marker(
              point: LatLng(_myLat!, _myLng!),
              width: 40,
              height: 40,
              child: const Icon(Icons.my_location_rounded, color: Colors.blue, size: 32),
            ));
          }
          for (final t in provider.technicians.where((t) => t.hasLocation)) {
            final selected = t.id == _selectedTechId;
            markers.add(Marker(
              point: LatLng(t.currentLat!, t.currentLng!),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => setState(() => _selectedTechId = t.id),
                child: Icon(
                  Icons.location_on_rounded,
                  color: selected ? AppTheme.primaryColor : Colors.redAccent,
                  size: selected ? 42 : 36,
                ),
              ),
            ));
          }

          final initialCenter = _myLat != null && _myLng != null
              ? LatLng(_myLat!, _myLng!)
              : const LatLng(28.6139, 77.2090);

          return Column(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: 12,
                        onMapReady: _fitMapToMarkers,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.homefixlive.homefix_live',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                    if (_state == _LoadState.locating)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black12,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    if (_state == _LoadState.locationDenied)
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                      child: _Banner(
                        text: 'Location unavailable — showing top-rated technicians instead of nearest.',
                        onRetry: _resolveLocationAndFetch,
                      ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _TechnicianSheet(
                  provider: provider,
                  selectedTechId: _selectedTechId,
                  onSelect: (id) {
                    setState(() => _selectedTechId = id);
                    final t = provider.technicians.firstWhere((t) => t.id == id);
                    if (t.hasLocation) {
                      _mapController.move(LatLng(t.currentLat!, t.currentLng!), 15);
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _Banner({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off_rounded, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _TechnicianSheet extends StatelessWidget {
  final NearbyTechnicianProvider provider;
  final String? selectedTechId;
  final ValueChanged<String> onSelect;

  const _TechnicianSheet({required this.provider, required this.selectedTechId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.technicians.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.technicians.isEmpty) {
      return Center(
        child: Text(
          provider.error != null ? 'Could not load nearby technicians' : 'No technicians available right now',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: provider.technicians.length,
      itemBuilder: (context, i) {
        final t = provider.technicians[i];
        final selected = t.id == selectedTechId;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelect(t.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name.isNotEmpty ? t.name : 'Technician',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                          const SizedBox(width: 2),
                          Text('${t.ratingAvg.toStringAsFixed(1)} (${t.ratingCount})',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          if (t.distanceKm != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Text('${t.distanceKm!.toStringAsFixed(1)} km away',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: selected ? AppTheme.primaryColor : Colors.grey[400],
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
