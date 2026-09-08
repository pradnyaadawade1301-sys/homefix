import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/contact_actions.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import 'technician_service_history_screen.dart';

/// Customer-facing "My Technicians" screen — lists technicians this customer
/// has booked more than once, most-frequent first. Backed by
/// GET /me/repeat-technicians (see booking_service.dart -> getRepeatTechnicians,
/// booking_provider.dart -> fetchRepeatTechnicians). Mirrors the technician's
/// RepeatCustomersScreen.
class RepeatTechniciansScreen extends StatefulWidget {
  const RepeatTechniciansScreen({Key? key}) : super(key: key);

  @override
  State<RepeatTechniciansScreen> createState() => _RepeatTechniciansScreenState();
}

class _RepeatTechniciansScreenState extends State<RepeatTechniciansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<BookingProvider>().fetchRepeatTechnicians();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Technicians')),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingRepeatTechnicians) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.repeatTechnicians.isEmpty) {
            return _ErrorState(message: provider.error!, onRetry: _load);
          }
          final technicians = provider.repeatTechnicians;
          if (technicians.isEmpty) {
            return _EmptyState(onRefresh: _load);
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: technicians.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _RepeatTechnicianCard(
                technician: technicians[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TechnicianServiceHistoryScreen(technician: technicians[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RepeatTechnicianCard extends StatelessWidget {
  final RepeatTechnician technician;
  final VoidCallback onTap;
  const _RepeatTechnicianCard({required this.technician, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightOutline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            backgroundImage: technician.profilePhotoUrl.isNotEmpty
                ? NetworkImage(technician.profilePhotoUrl)
                : null,
            child: technician.profilePhotoUrl.isEmpty
                ? Text(
                    technician.name.isNotEmpty ? technician.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  technician.name.isNotEmpty ? technician.name : 'Technician',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                if (technician.categoryName.isNotEmpty)
                  Text(
                    technician.categoryName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      technician.ratingAvg.toStringAsFixed(1),
                      style: TextStyle(color: Colors.grey[700], fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Last booked: ${dateFmt.format(technician.lastBookingAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${technician.totalBookings} bookings',
                  style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              if (technician.phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.call_outlined, size: 20, color: AppTheme.primaryColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => callContact(context, technician.phone),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.engineering_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No repeat technicians yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Technicians you book more than once will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}