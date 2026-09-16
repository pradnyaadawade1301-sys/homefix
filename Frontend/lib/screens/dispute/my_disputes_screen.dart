import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/dispute_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/dispute_service.dart';
import 'dispute_detail_screen.dart';
import 'raise_dispute_screen.dart';

/// Entry point for "My Disputes" — reachable from booking/consultation detail
/// ("Raise a dispute" button) and from account settings. GET /disputes/me.
class MyDisputesScreen extends StatefulWidget {
  const MyDisputesScreen({Key? key}) : super(key: key);

  @override
  State<MyDisputesScreen> createState() => _MyDisputesScreenState();
}

class _MyDisputesScreenState extends State<MyDisputesScreen> {
  late Future<List<Dispute>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<DisputeService>().listMine();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  /// The only entry point into RaiseDisputeScreen anywhere in the app —
  /// picks which booking the dispute is about first, since a dispute must
  /// be tied to exactly one booking/consultation.
  Future<void> _startNewDispute() async {
    final bookingProvider = context.read<BookingProvider>();
    final isTechnician = context.read<AuthProvider>().currentUser?.isTechnician == true;
    if (bookingProvider.bookings.isEmpty) {
      if (isTechnician) {
        final technicianId = context.read<TechnicianKycProvider>().profile?.id;
        if (technicianId != null) {
          await bookingProvider.fetchTechnicianBookings(technicianId);
        }
      } else {
        await bookingProvider.fetchUserBookings();
      }
    }
    if (!mounted) return;
    final bookings = bookingProvider.bookings.where((b) => b.status == 'completed').toList();
    if (bookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed bookings yet to raise a dispute about')),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Which booking is this about?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = bookings[i];
                    final counterpart = b.technician?.name ?? b.customer?.name;
                    return ListTile(
                      title: Text(
                        '${b.categoryName.isNotEmpty ? b.categoryName : 'Service'}'
                        '${counterpart != null && counterpart.isNotEmpty ? ' \u2022 $counterpart' : ''}',
                      ),
                      subtitle: Text(
                        '#${b.id.length >= 8 ? b.id.substring(0, 8) : b.id} \u2022 '
                        '${b.createdAt.day}/${b.createdAt.month}/${b.createdAt.year}'
                        '${b.finalPrice != null ? ' \u2022 \u20b9${b.finalPrice!.toStringAsFixed(0)}' : ''}',
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(b.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RaiseDisputeScreen(bookingId: picked),
    ));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Disputes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewDispute,
        icon: const Icon(Icons.add),
        label: const Text('Raise Dispute'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Dispute>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Failed to load: ${snapshot.error}')),
                ],
              );
            }
            final disputes = snapshot.data ?? [];
            if (disputes.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(
                    child: Text(
                      'No disputes raised yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: disputes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _DisputeCard(dispute: disputes[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final Dispute dispute;
  const _DisputeCard({required this.dispute});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.lightOutline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DisputeDetailScreen(disputeId: dispute.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dispute.bookingId != null
                        ? 'Booking #${dispute.bookingId!.substring(0, 8)}'
                        : 'Consultation #${dispute.consultationId?.substring(0, 8) ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  _StatusChip(status: dispute.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dispute.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(dispute.createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'open' => (AppTheme.warningColor, 'Open'),
      'under_review' => (AppTheme.infoColor, 'Under Review'),
      'resolved_refund' => (AppTheme.successColor, 'Refunded'),
      'resolved_partial' => (AppTheme.successColor, 'Partial Refund'),
      'resolved_rejected' => (AppTheme.errorColor, 'Rejected'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}