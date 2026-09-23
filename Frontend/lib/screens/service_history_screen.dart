import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/booking_model.dart';
import '../models/consultation_model.dart';
import '../providers/booking_provider.dart';
import '../providers/consultation_provider.dart';
import '../screens/booking/book_technician_screen.dart';
import 'write_review_screen.dart';

/// Shows the customer's past service bookings (completed / cancelled) as well
/// as their past Live Video Consultation calls, with a "Book Again" action
/// that pre-fills the same technician + category for a repeat booking — see
/// BookTechnicianScreen's preferredTechnician param — and a "Rate this
/// Service" action that opens WriteReviewScreen.
class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchUserBookings();
      context.read<ConsultationProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Service History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bookings'),
            Tab(text: 'Video Calls'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: () => context.read<BookingProvider>().fetchUserBookings(),
            child: Consumer<BookingProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.bookings.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final closed = provider.bookings
                    .where((b) => b.status == 'completed' || b.status == 'cancelled')
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                if (closed.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No service history yet',
                    subtitle: 'Completed and cancelled bookings will show up here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: closed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _HistoryCard(booking: closed[index]),
                );
              },
            ),
          ),
          RefreshIndicator(
            onRefresh: () => context.read<ConsultationProvider>().loadHistory(),
            child: Consumer<ConsultationProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingHistory && provider.history.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final closed = provider.history
                    .where((c) => c.status == ConsultationStatus.ended || c.status == ConsultationStatus.cancelled)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (closed.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.videocam_off_rounded,
                    title: 'No video calls yet',
                    subtitle: 'Completed video consultations will show up here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: closed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ConsultationCard(consultation: closed[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final Consultation consultation;
  const _ConsultationCard({required this.consultation});

  @override
  Widget build(BuildContext context) {
    final ended = consultation.status == ConsultationStatus.ended;
    final minutes = consultation.durationSeconds != null ? (consultation.durationSeconds! / 60).ceil() : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (ended ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              ended ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: ended ? AppTheme.successColor : AppTheme.errorColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  consultation.categoryName.isNotEmpty ? consultation.categoryName : 'Video consultation',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${consultation.createdAt.day}/${consultation.createdAt.month}/${consultation.createdAt.year}'
                  '${consultation.technicianName != null && consultation.technicianName!.isNotEmpty ? ' • ${consultation.technicianName}' : ''}'
                  '${minutes != null ? ' • $minutes min' : ''}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (ended ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ended ? 'Completed' : 'Cancelled',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: ended ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Booking booking;

  const _HistoryCard({required this.booking});

  void _bookAgain(BuildContext context, BookingTechnicianInfo tech) {
    final technician = Technician(
      id: tech.id,
      name: tech.name,
      categoryId: booking.categoryId,
      categoryName: tech.categoryName,
      experienceYears: tech.experienceYears,
      ratingAvg: tech.ratingAvg,
      ratingCount: tech.ratingCount,
      isVerified: tech.isVerified,
      isAvailable: true,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookTechnicianScreen(
        categoryId: booking.categoryId,
        categoryName: booking.categoryName,
        problemDescription: booking.problemDescription,
        preferredTechnician: technician,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final completed = booking.status == 'completed';
    final tech = booking.technician;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (completed ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  completed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: completed ? AppTheme.successColor : AppTheme.errorColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.categoryName.isNotEmpty ? booking.categoryName : 'Service booking',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}'
                      '${tech != null ? ' • ${tech.name}' : ''}',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (completed && booking.finalPrice != null)
                    Text('₹${booking.finalPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (completed ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      completed ? 'Completed' : 'Cancelled',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: completed ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (completed && tech != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: Material(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(11),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => _bookAgain(context, tech),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay_rounded, size: 15, color: Colors.white),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Book Again',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WriteReviewScreen(booking: booking),
                        ));
                      },
                      icon: const Icon(Icons.star_outline_rounded, size: 15),
                      label: const Text('Rate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (booking.isWarrantyClaim) ...[
            const SizedBox(height: 10),
            _InlineBanner(
              icon: Icons.verified_rounded,
              color: AppTheme.primaryColor,
              text: booking.warrantyClaimOfServiceCode != null
                  ? 'Warranty claim for ${booking.warrantyClaimOfServiceCode}'
                  : 'Warranty claim',
            ),
          ] else if (completed && booking.warrantyEnabled) ...[
            const SizedBox(height: 10),
            if (booking.canClaimWarranty)
              _InlineBanner(
                icon: Icons.shield_rounded,
                color: AppTheme.successColor,
                text: 'Under warranty till ${booking.warrantyExpiresAt!.day}/${booking.warrantyExpiresAt!.month}/${booking.warrantyExpiresAt!.year}',
                actionLabel: 'Claim',
                onAction: () => _claimWarranty(context),
              )
            else
              _InlineBanner(
                icon: Icons.shield_outlined,
                color: Colors.grey[500]!,
                text: 'Warranty expired',
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _claimWarranty(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Claim Warranty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This raises a free revisit request for the same issue. Wherever possible it\'s routed straight back to the technician who did the original job.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What\'s the issue? (optional)',
                hintText: 'e.g. Same noise came back after a week',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Raise Claim')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final provider = context.read<BookingProvider>();
    final ok = await provider.raiseWarrantyClaim(booking.id, note: controller.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Warranty claim raised — check My Bookings' : (provider.error ?? 'Could not raise claim'))),
    );
  }
}

/// Compact single-line status banner (used for warranty state) — replaces
/// the old pattern of a full block plus a separate full-width button below
/// it, which made cards feel tall and busy.
class _InlineBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InlineBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  actionLabel!,
                  style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}