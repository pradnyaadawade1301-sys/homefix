import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/category_provider.dart';
import 'technician_detail_screen.dart';
import 'nearby_technicians_screen.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _query = widget.initialQuery!.trim().toLowerCase();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechnicianProvider>().fetchTechnicians(categoryId: widget.categoryId);
    });
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
            child: Consumer<TechnicianProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.technicians.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                var techs = provider.technicians;
                if (_query.isNotEmpty) {
                  techs = techs
                      .where((t) =>
                          t.name.toLowerCase().contains(_query) ||
                          t.categoryName.toLowerCase().contains(_query))
                      .toList();
                }
                if (techs.isEmpty) {
                  return Center(
                    child: Text(
                      provider.error != null
                          ? 'Could not load technicians'
                          : 'No technicians found',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: techs.length,
                  itemBuilder: (context, i) => _TechCard(technician: techs[i], problemDescription: widget.problemDescription),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TechCard extends StatelessWidget {
  final Technician technician;
  final String? problemDescription;
  const _TechCard({required this.technician, this.problemDescription});

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
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text('${technician.ratingAvg.toStringAsFixed(1)} (${technician.ratingCount})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Text('${technician.experienceYears} yrs exp',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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