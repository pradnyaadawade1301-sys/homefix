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
                    .toList();
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
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                    .toList();
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
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (ended ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ended ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: ended ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  consultation.categoryName.isNotEmpty ? consultation.categoryName : 'Video consultation',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${consultation.createdAt.day}/${consultation.createdAt.month}/${consultation.createdAt.year}'
                  '${consultation.technicianName != null && consultation.technicianName!.isNotEmpty ? ' • ${consultation.technicianName}' : ''}'
                  '${minutes != null ? ' • $minutes min' : ''}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            ended ? 'Completed' : 'Cancelled',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: ended ? AppTheme.successColor : AppTheme.errorColor,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (completed ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  completed ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                  color: completed ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.categoryName.isNotEmpty ? booking.categoryName : 'Service booking',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}'
                      '${tech != null ? ' • ${tech.name}' : ''}',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (completed && booking.finalPrice != null)
                    Text('₹${booking.finalPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    completed ? 'Completed' : 'Cancelled',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: completed ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (completed && tech != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: Material(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _bookAgain(context, tech),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.replay_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Book ${tech.name} again',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WriteReviewScreen(booking: booking),
                  ));
                },
                icon: const Icon(Icons.star_outline_rounded, size: 16),
                label: const Text('Rate this Service'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
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