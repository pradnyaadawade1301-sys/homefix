import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';
import 'technician_detail_screen.dart';
import 'nearby_technicians_screen.dart';

/// Step 3 of the customer flow ("Technician Selection"): HomeFox finds
/// available technicians for the category and highlights one "Recommended
/// Technician" (best rated + nearest) at the top — photo, rating,
/// experience, distance, ETA and the visit charge — with the full list
/// underneath for anyone who wants to compare or pick someone else.
class TechnicianListScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;
  final String? initialQuery;
  final String? problemDescription;

  const TechnicianListScreen({
    Key? key,
    this.categoryId,
    this.categoryName,
    this.initialQuery,
    this.problemDescription,
  }) : super(key: key);

  @override
  State<TechnicianListScreen> createState() => _TechnicianListScreenState();
}

class _TechnicianListScreenState extends State<TechnicianListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _query = widget.initialQuery!.trim().toLowerCase();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    // We only have a categoryId (and therefore live distance/ETA data) when
    // arriving from a specific service category. Without one we fall back
    // to the plain "all technicians" list (no distance/recommended card).
    if (widget.categoryId != null) {
      try {
        final locProvider = context.read<LocationProvider>();
        await locProvider.resolveLocation();
        if (locProvider.hasLocation) {
          _myLat = locProvider.latitude;
          _myLng = locProvider.longitude;
        }
      } catch (_) {
        // Location unavailable — nearby fetch below still works, just
        // without distance_km per technician.
      }
      if (!mounted) return;
      await context.read<NearbyTechnicianProvider>().fetchNearby(
            categoryId: widget.categoryId!,
            lat: _myLat,
            lng: _myLng,
          );
      if (!mounted) return;
      // Category base price powers the "visit charge" shown on the
      // recommended card — fetch once if not already loaded.
      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) {
        await catProvider.fetchCategories();
      }
    } else {
      context.read<TechnicianProvider>().fetchTechnicians(categoryId: null);
    }
  }

  double? get _visitCharge {
    if (widget.categoryId == null) return null;
    final categories = context.read<CategoryProvider>().categories;
    for (final c in categories) {
      if (c.id == widget.categoryId) return c.basePrice;
    }
    return null;
  }

  /// Rough ETA estimate from distance, assuming ~30 km/h average city
  /// travel speed. This is a client-side estimate for display only — there
  /// is no live routing/traffic API wired up yet.
  int? _etaMinutes(double? distanceKm) {
    if (distanceKm == null) return null;
    final minutes = (distanceKm / 30 * 60).round();
    return minutes < 10 ? 10 : minutes;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? 'All Technicians'),
        actions: [
          if (widget.categoryId != null)
            IconButton(
              icon: const Icon(Icons.map_rounded),
              tooltip: 'Show nearby on map',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NearbyTechniciansScreen(
                    categoryId: widget.categoryId!,
                    categoryName: widget.categoryName ?? 'Technicians',
                  ),
                ));
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search technician or service...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: widget.categoryId != null ? _buildNearbyList() : _buildPlainList(),
          ),
        ],
      ),
    );
  }

  /// Category-scoped view: recommended technician card + rest of the list,
  /// both backed by [NearbyTechnicianProvider] so distance/ETA are real.
  Widget _buildNearbyList() {
    return Consumer<NearbyTechnicianProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.technicians.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        var techs = List<TechnicianNearby>.from(provider.technicians);
        if (_query.isNotEmpty) {
          techs = techs
              .where((t) => t.name.toLowerCase().contains(_query) || t.categoryName.toLowerCase().contains(_query))
              .toList();
        }
        if (techs.isEmpty) {
          return Center(
            child: Text(
              provider.error != null ? 'Could not load technicians' : 'No technicians found',
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }

        // Recommended = best rated, ties broken by nearest — this is the
        // single technician the "Recommended Technician" card highlights.
        final sorted = List<TechnicianNearby>.from(techs)
          ..sort((a, b) {
            final ratingCmp = b.ratingAvg.compareTo(a.ratingAvg);
            if (ratingCmp != 0) return ratingCmp;
            final ad = a.distanceKm ?? double.infinity;
            final bd = b.distanceKm ?? double.infinity;
            return ad.compareTo(bd);
          });
        final recommended = sorted.first;
        final rest = techs.where((t) => t.id != recommended.id).toList();
        final visitCharge = _visitCharge;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Text('Recommended Technician', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            _RecommendedTechCard(
              technician: recommended,
              visitCharge: visitCharge,
              etaMinutes: _etaMinutes(recommended.distanceKm),
              problemDescription: widget.problemDescription,
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text('Other technicians nearby', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              ...rest.map((t) => _TechCard.fromNearby(
                    technician: t,
                    etaMinutes: _etaMinutes(t.distanceKm),
                    problemDescription: widget.problemDescription,
                  )),
            ],
          ],
        );
      },
    );
  }

  /// Fallback view when there's no category context (e.g. "Browse all
  /// technicians" from search) — no distance data available.
  Widget _buildPlainList() {
    return Consumer<TechnicianProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.technicians.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        var techs = provider.technicians;
        if (_query.isNotEmpty) {
          techs = techs
              .where((t) => t.name.toLowerCase().contains(_query) || t.categoryName.toLowerCase().contains(_query))
              .toList();
        }
        if (techs.isEmpty) {
          return Center(
            child: Text(
              provider.error != null ? 'Could not load technicians' : 'No technicians found',
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: techs.length,
          itemBuilder: (context, i) => _TechCard.fromTechnician(
            technician: techs[i],
            problemDescription: widget.problemDescription,
          ),
        );
      },
    );
  }
}

/// The highlighted "Recommended Technician" card shown at the top of Step 3:
/// photo, rating, experience, distance, ETA and visit charge, matching the
/// product spec's example ("Rahul – AC Technician, 4.8★, 7 yrs, 2.5 km,
/// arrives in 30 minutes").
class _RecommendedTechCard extends StatelessWidget {
  final TechnicianNearby technician;
  final double? visitCharge;
  final int? etaMinutes;
  final String? problemDescription;

  const _RecommendedTechCard({
    required this.technician,
    required this.visitCharge,
    required this.etaMinutes,
    required this.problemDescription,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TechnicianDetailScreen(
            technician: Technician(
              id: technician.id,
              name: technician.name,
              categoryId: technician.categoryId,
              categoryName: technician.categoryName,
              experienceYears: technician.experienceYears,
              ratingAvg: technician.ratingAvg,
              ratingCount: technician.ratingCount,
              isVerified: false,
              isAvailable: technician.isAvailable,
              createdAt: DateTime.now(),
            ),
            problemDescription: problemDescription,
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor.withValues(alpha: 0.10), AppTheme.primaryColor.withValues(alpha: 0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25), width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    technician.name.isNotEmpty ? technician.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        technician.name.isNotEmpty ? technician.name : 'Technician',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                      ),
                      const SizedBox(height: 2),
                      Text(technician.categoryName, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Best Match', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _StatChip(icon: Icons.star_rounded, iconColor: const Color(0xFFF5A623), label: '${technician.ratingAvg.toStringAsFixed(1)} (${technician.ratingCount})'),
                _StatChip(icon: Icons.work_outline_rounded, iconColor: AppTheme.primaryColor, label: '${technician.experienceYears} yrs exp'),
                if (technician.distanceKm != null)
                  _StatChip(icon: Icons.location_on_outlined, iconColor: Colors.redAccent, label: '${technician.distanceKm!.toStringAsFixed(1)} km away'),
                if (etaMinutes != null)
                  _StatChip(icon: Icons.access_time_rounded, iconColor: Colors.blueAccent, label: 'Arrives in $etaMinutes min'),
                if (visitCharge != null)
                  _StatChip(icon: Icons.currency_rupee_rounded, iconColor: Colors.green, label: 'Visit charge \u20b9${visitCharge!.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _StatChip({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TechCard extends StatelessWidget {
  final Technician technician;
  final int? etaMinutes;
  final double? distanceKm;
  final String? problemDescription;

  const _TechCard({
    required this.technician,
    this.etaMinutes,
    this.distanceKm,
    this.problemDescription,
  });

  factory _TechCard.fromTechnician({required Technician technician, String? problemDescription}) {
    return _TechCard(technician: technician, problemDescription: problemDescription);
  }

  factory _TechCard.fromNearby({required TechnicianNearby technician, int? etaMinutes, String? problemDescription}) {
    return _TechCard(
      technician: Technician(
        id: technician.id,
        name: technician.name,
        categoryId: technician.categoryId,
        categoryName: technician.categoryName,
        experienceYears: technician.experienceYears,
        ratingAvg: technician.ratingAvg,
        ratingCount: technician.ratingCount,
        isVerified: false,
        isAvailable: technician.isAvailable,
        createdAt: DateTime.now(),
      ),
      etaMinutes: etaMinutes,
      distanceKm: technician.distanceKm,
      problemDescription: problemDescription,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TechnicianDetailScreen(technician: technician, problemDescription: problemDescription),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                technician.name.isNotEmpty ? technician.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(technician.name.isNotEmpty ? technician.name : 'Technician',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Text(technician.categoryName, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                        const SizedBox(width: 2),
                        Text('${technician.ratingAvg.toStringAsFixed(1)} (${technician.ratingCount})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                      Text('${technician.experienceYears} yrs exp', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      if (distanceKm != null)
                        Text('${distanceKm!.toStringAsFixed(1)} km • $etaMinutes min', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}