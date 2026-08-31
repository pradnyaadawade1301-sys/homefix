import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/consultation_provider.dart';
import '../chat/booking_chat_screen.dart';
import '../consultation/post_call_screen.dart';

/// Bottom-nav "Consult" tab: one place for every conversation the customer has
/// had with a technician — text chat (booking-scoped, see BookingChatScreen)
/// on one tab, Live Video Consultation calls (see ConsultationProvider) on the
/// other. Each row always shows WHO it was with, since that's the whole point
/// of this screen (as opposed to ServiceHistoryScreen, which is organised by
/// booking/job rather than by conversation).
class ConsultScreen extends StatefulWidget {
  /// Optional anchor the Guided Tour can spotlight when it walks onto this
  /// screen. Attached to the Chat/Video TabBar so it's always present.
  final GlobalKey? tourKey;

  const ConsultScreen({Key? key, this.tourKey}) : super(key: key);

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> with SingleTickerProviderStateMixin {
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
        title: const Text('Consult'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFFF7F8FA),
        foregroundColor: const Color(0xFF1A1F36),
        bottom: TabBar(
          key: widget.tourKey,
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline_rounded), text: 'Chat'),
            Tab(icon: Icon(Icons.videocam_outlined), text: 'Video'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ChatHistoryTab(),
          _VideoHistoryTab(),
        ],
      ),
    );
  }
}

/// Every booking that has (or can have) a chat thread with a technician —
/// each booking id doubles as its own thread id (see BookingChatScreen doc
/// comment), so this is effectively "who have I messaged".
class _ChatHistoryTab extends StatelessWidget {
  const _ChatHistoryTab();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<BookingProvider>().fetchUserBookings(),
      child: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.bookings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          // Only bookings that actually have a technician assigned can have a
          // chat thread — a booking still "searching" has no one to chat with.
          final withTechnician = provider.bookings.where((b) => b.technician != null).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (withTechnician.isEmpty) {
            return const _EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No chats yet',
              subtitle: 'Once a technician is assigned to your booking, your conversation shows up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: withTechnician.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ChatRow(booking: withTechnician[index]),
          );
        },
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final Booking booking;
  const _ChatRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final tech = booking.technician!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BookingChatScreen(bookingId: booking.id, peerName: tech.name),
        )),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.lightOutline),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(
                  tech.name.isNotEmpty ? tech.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tech.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(
                      booking.categoryName.isNotEmpty ? booking.categoryName : 'Service booking',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every Live Video Consultation the customer has ever started — most recent
/// first, whatever the status (upcoming/ended/cancelled).
class _VideoHistoryTab extends StatelessWidget {
  const _VideoHistoryTab();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<ConsultationProvider>().loadHistory(),
      child: Consumer<ConsultationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingHistory && provider.history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final calls = [...provider.history]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (calls.isEmpty) {
            return const _EmptyState(
              icon: Icons.videocam_off_rounded,
              title: 'No video calls yet',
              subtitle: 'Your live video consultations with technicians will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: calls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _VideoRow(consultation: calls[index]),
          );
        },
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final Consultation consultation;
  const _VideoRow({required this.consultation});

  Color _statusColor() {
    switch (consultation.status) {
      case ConsultationStatus.ended:
        return AppTheme.successColor;
      case ConsultationStatus.cancelled:
      case ConsultationStatus.rejected:
      case ConsultationStatus.noTechnician:
        return AppTheme.errorColor;
      case ConsultationStatus.confirmed:
        return AppTheme.successColor;
      case ConsultationStatus.scheduled:
        return AppTheme.warningColor;
      default:
        return Colors.orange; // searching / ringing / accepted / in_call — still active
    }
  }

  String _statusLabel() {
    switch (consultation.status) {
      case ConsultationStatus.ended:
        return 'Completed';
      case ConsultationStatus.cancelled:
        return 'Cancelled';
      case ConsultationStatus.rejected:
        // A scheduled slot the technician couldn't hold reads differently from
        // an instant call nobody picked up — same underlying status, different
        // customer-facing story, so distinguish it here rather than showing a
        // flat "Declined" for both.
        return consultation.scheduledAt != null ? 'Technician unavailable' : 'Declined';
      case ConsultationStatus.noTechnician:
        return 'No expert found';
      case ConsultationStatus.inCall:
        return 'In call';
      case ConsultationStatus.confirmed:
        return 'Confirmed';
      case ConsultationStatus.scheduled:
        return 'Awaiting confirmation';
      default:
        return 'Upcoming';
    }
  }

  /// A short explanatory line shown under the category/date row for statuses
  /// where the label alone isn't enough to know what to do next — most
  /// importantly a declined "Schedule for later" slot, where the customer
  /// should see plainly that the technician was busy and they need to pick a
  /// new time, not just a bare "Declined" tag with no next step.
  String? _helperText() {
    switch (consultation.status) {
      case ConsultationStatus.rejected:
        return consultation.scheduledAt != null
            ? 'The technician was busy and couldn\'t make this slot. Please request a new time.'
            : 'The technician couldn\'t take your call. You can try again.';
      case ConsultationStatus.scheduled:
        return 'Waiting for the technician to confirm your requested slot.';
      case ConsultationStatus.confirmed:
        return 'Confirmed — the call will start automatically at your scheduled time.';
      case ConsultationStatus.noTechnician:
        return 'No technician was available for this request. Please try again later.';
      default:
        return null;
    }
  }

  static String _formatSlot(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = months[local.month - 1];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '$day $month, $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final peerName = (consultation.technicianName != null && consultation.technicianName!.isNotEmpty)
        ? consultation.technicianName!
        : 'Technician';
    final minutes = consultation.durationSeconds != null ? (consultation.durationSeconds! / 60).ceil() : null;
    final ended = consultation.status == ConsultationStatus.ended;
    final helper = _helperText();
    final color = _statusColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: ended
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PostCallScreen(
                    consultationId: consultation.id,
                    categoryId: consultation.categoryId,
                    categoryName: consultation.categoryName,
                    technicianName: consultation.technicianName,
                  ),
                ))
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.videocam_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(peerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        const SizedBox(height: 3),
                        Text(
                          '${consultation.categoryName.isNotEmpty ? consultation.categoryName : 'Video consultation'}'
                          '${consultation.scheduledAt != null ? ' • ${_formatSlot(consultation.scheduledAt!)}' : ' • ${consultation.createdAt.day}/${consultation.createdAt.month}/${consultation.createdAt.year}'}'
                          '${minutes != null ? ' • $minutes min' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _statusLabel(),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ),
              if (helper != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(helper, style: TextStyle(fontSize: 12, color: color, height: 1.35)),
                ),
              ],
            ],
          ),
        ),
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