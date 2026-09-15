import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/booking_call_launcher.dart';
import '../../core/theme.dart';
import '../../providers/booking_provider.dart';
import '../../models/booking_model.dart';
import '../../l10n/app_localizations.dart';
import 'booking_tracking_screen.dart';
import '../chat/booking_chat_screen.dart';

/// Customer-facing "My Bookings" list. Shows the assigned technician's
/// name/phone/rating on each card once one is assigned (b.technician != null).
class BookingsScreen extends StatefulWidget {
  /// Optional anchor the Guided Tour can spotlight when it walks onto this
  /// screen. Attached to the AppBar title so it's always present, even
  /// while the bookings list itself is still loading or empty.
  final GlobalKey? tourKey;

  const BookingsScreen({Key? key, this.tourKey}) : super(key: key);

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchUserBookings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _canCancel(String status) {
    return !['in_progress', 'completed', 'cancelled'].contains(status);
  }

  Future<void> _cancelFromList(BuildContext context, String bookingId) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.bookingsCancelDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bookingsCancelDialogBody,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.bookingsCancelReasonLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.bookingsKeepBooking)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.bookingsYesCancel),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    final provider = context.read<BookingProvider>();
    final ok = await provider.cancelBooking(bookingId, reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.bookingsCancelledMsg : (provider.error ?? l10n.bookingsCouldNotCancel))),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'in_progress':
      case 'accepted':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'requested':
        return l10n.bookingsStatusFinding;
      case 'pending_technician':
        return l10n.bookingsStatusWaiting;
      case 'accepted':
        return l10n.bookingsStatusAssigned;
      case 'in_progress':
        return l10n.bookingsStatusInProgress;
      case 'completed':
        return l10n.bookingsStatusCompleted;
      case 'cancelled':
        return l10n.bookingsStatusCancelled;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookingsTitle, key: widget.tourKey),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<BookingProvider>().fetchUserBookings(),
        child: Consumer<BookingProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.bookings.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.bookings.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Icon(Icons.calendar_month_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      l10n.bookingsEmptyTitle,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      l10n.bookingsEmptySubtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ),
                ],
              );
            }
            // "Started" statuses mean the technician has actually begun the
            // job — anything before that (even if today's scheduled slot
            // time has technically passed) should still read as Upcoming,
            // not silently vanish from that tab just because the wall clock
            // ticked past the slot before the technician got moving.
            const startedStatuses = {'on_the_way', 'arrived', 'in_progress', 'awaiting_estimate_approval', 'inspecting'};
            final upcoming = provider.bookings
                .where((b) => b.status != 'completed' && b.status != 'cancelled' && b.scheduledAt != null && !startedStatuses.contains(b.status))
                .toList()
              ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
            final active = provider.bookings
                .where((b) => b.status != 'completed' && b.status != 'cancelled' && (b.scheduledAt == null || startedStatuses.contains(b.status)))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final past = provider.bookings.where((b) => b.status == 'completed' || b.status == 'cancelled').toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

            return TabBarView(
              controller: _tabController,
              children: [
                _BookingList(
                  bookings: active,
                  l10n: l10n,
                  emptyIcon: Icons.bolt_rounded,
                  emptyTitle: 'No active bookings',
                  emptySubtitle: 'Bookings in progress will show up here.',
                  canCancel: _canCancel,
                  onCancel: (id) => _cancelFromList(context, id),
                  statusColor: _statusColor,
                  statusLabel: (s) => _statusLabel(s, l10n),
                ),
                _BookingList(
                  bookings: upcoming,
                  l10n: l10n,
                  emptyIcon: Icons.event_available_outlined,
                  emptyTitle: 'No upcoming bookings',
                  emptySubtitle: 'Bookings scheduled for later will show up here.',
                  canCancel: _canCancel,
                  onCancel: (id) => _cancelFromList(context, id),
                  statusColor: _statusColor,
                  statusLabel: (s) => _statusLabel(s, l10n),
                ),
                _BookingList(
                  bookings: past,
                  l10n: l10n,
                  emptyIcon: Icons.history_rounded,
                  emptyTitle: 'No past bookings',
                  emptySubtitle: 'Completed and cancelled bookings will show up here.',
                  canCancel: (_) => false,
                  onCancel: (_) {},
                  statusColor: _statusColor,
                  statusLabel: (s) => _statusLabel(s, l10n),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final AppLocalizations l10n;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool Function(String status) canCancel;
  final void Function(String id) onCancel;
  final Color Function(String status) statusColor;
  final String Function(String status) statusLabel;

  const _BookingList({
    required this.bookings,
    required this.l10n,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.canCancel,
    required this.onCancel,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Icon(emptyIcon, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Center(
            child: Text(emptyTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(emptySubtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: bookings.length,
      itemBuilder: (context, i) {
        final b = bookings[i];
        return _BookingCard(
          booking: b,
          l10n: l10n,
          canCancel: canCancel(b.status),
          onCancel: () => onCancel(b.id),
          statusColor: statusColor(b.status),
          statusLabel: statusLabel(b.status),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final AppLocalizations l10n;
  final bool canCancel;
  final VoidCallback? onCancel;
  final Color statusColor;
  final String statusLabel;

  const _BookingCard({
    required this.booking,
    required this.l10n,
    required this.canCancel,
    required this.onCancel,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    // A future scheduledAt is the "schedule for later" case — call that out
    // explicitly instead of letting it blend into the regular status chip,
    // so scheduled bookings don't get lost among active/completed ones.
    const startedStatuses = {'on_the_way', 'arrived', 'in_progress', 'awaiting_estimate_approval', 'inspecting'};
    final isFutureScheduled = b.scheduledAt != null && !startedStatuses.contains(b.status) && b.status != 'completed' && b.status != 'cancelled';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BookingTrackingScreen(bookingId: b.id),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
          border: isFutureScheduled ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    b.categoryName.isNotEmpty ? b.categoryName : l10n.bookingsServiceBookingFallback,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isFutureScheduled ? AppTheme.primaryColor : statusColor).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFutureScheduled ? 'Scheduled' : statusLabel,
                    style: TextStyle(fontSize: 11, color: isFutureScheduled ? AppTheme.primaryColor : statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.cancel_outlined, size: 18, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ],
            ),
            if (b.problemDescription.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                b.problemDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (isFutureScheduled) ...[
                  Icon(Icons.event_rounded, size: 13, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  b.scheduledAt != null
                      ? '${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year}'
                      : l10n.bookingsBookedOn('${b.createdAt.day}/${b.createdAt.month}/${b.createdAt.year}'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isFutureScheduled ? AppTheme.primaryColor : Colors.grey[600],
                    fontWeight: isFutureScheduled ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (b.technician != null) ...[
              const SizedBox(height: 12),
              _TechnicianTile(technician: b.technician!, bookingId: b.id, bookingStatus: b.status),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact "who's coming" card shown on a customer's booking once a
/// technician has been assigned.
class _TechnicianTile extends StatelessWidget {
  final BookingTechnicianInfo technician;
  final String bookingId;
  final String bookingStatus;
  const _TechnicianTile({required this.technician, required this.bookingId, required this.bookingStatus});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: Text(
              technician.name.isNotEmpty ? technician.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(technician.name.isNotEmpty ? technician.name : l10n.bookingsTechnicianFallback,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (technician.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: Colors.blue),
                    ],
                  ],
                ),
                Text(
                  '${technician.categoryName} • ${technician.experienceYears} yrs • ★ ${technician.ratingAvg.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          IconButton(
  icon: Icon(
    Icons.call_outlined,
    color: isCallableBookingStatus(bookingStatus) ? AppTheme.primaryColor : Colors.grey[400],
    size: 20,
  ),
  tooltip: isCallableBookingStatus(bookingStatus) ? 'Call' : 'You can call once the job is active',
  onPressed: isCallableBookingStatus(bookingStatus)
      ? () => startBookingAudioCall(
            context,
            bookingId: bookingId,
            peerDisplayName: technician.name.isNotEmpty ? technician.name : l10n.bookingsTechnicianFallback,
          )
      : null,
),
          IconButton(
  icon: const Icon(Icons.forum_outlined, color: AppTheme.primaryColor, size: 20),
  tooltip: l10n.bookingsChatTooltip,
  onPressed: () {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingChatScreen(
        bookingId: bookingId,
        peerName: technician.name.isNotEmpty ? technician.name : l10n.bookingsTechnicianFallback,
      ),
    ));
  },
),

        ],
      ),
    );
  }
}