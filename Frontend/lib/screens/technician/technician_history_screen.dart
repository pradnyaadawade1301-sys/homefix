import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/booking_call_launcher.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/call_log_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/call_log_provider.dart';
import '../chat/booking_chat_screen.dart';

/// Technician-facing History tab — one place to see every job's chat thread
/// and past video consultations. Chats reuses the booking list already
/// loaded by TechnicianJobsScreen (BookingProvider.bookings); Video Call
/// reuses ConsultationProvider.loadHistory() (same "/consultations/mine"
/// endpoint the customer-side history screen uses — scoped to whoever is
/// authenticated, technician or customer).
class TechnicianHistoryScreen extends StatefulWidget {
  const TechnicianHistoryScreen({super.key});
  @override
  State<TechnicianHistoryScreen> createState() => _TechnicianHistoryScreenState();
}

class _TechnicianHistoryScreenState extends State<TechnicianHistoryScreen> {
  int _tab = 0; // 0 = Chats, 1 = Video Call, 2 = Call, 3 = Warranty

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsultationProvider>().loadHistory();
      context.read<CallLogProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookings = context.watch<BookingProvider>().bookings;
    final consultationProvider = context.watch<ConsultationProvider>();
    final callLogProvider = context.watch<CallLogProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _tabChip('Chats', 0),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tabChip('Video Call', 1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tabChip('Call', 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tabChip('Warranty', 3),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0
              ? _chatsList(bookings)
              : _tab == 1
                  ? _videoCallList(consultationProvider)
                  : _tab == 2
                      ? _callList(callLogProvider)
                      : _warrantyList(bookings),
        ),
      ],
    );
  }

  Widget _tabChip(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _chatsList(List<Booking> bookings) {
    if (bookings.isEmpty) {
      return const Center(child: Text('No jobs yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = bookings[i];
        final customerName = b.customer?.name.isNotEmpty == true ? b.customer!.name : 'Customer';
        void openChat() => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BookingChatScreen(bookingId: b.id, peerName: customerName),
            ));
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: openChat,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Text(customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(b.status.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.forum_outlined, color: AppTheme.primaryColor),
                  tooltip: 'Open chat',
                  onPressed: openChat,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Real audio-call history — every call this technician placed or
  /// received (see GET /calls/history, CallLogProvider), most recent first,
  /// with who it was with, when, and whether it was picked up.
  Widget _callList(CallLogProvider provider) {
    if (provider.isLoading && provider.calls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final calls = provider.calls;
    if (calls.isEmpty) {
      return const Center(child: Text('No calls yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: calls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final call = calls[i];
        final peerName = call.peerName.isNotEmpty ? call.peerName : 'Customer';
        final missed = call.isMissed;

        IconData directionIcon;
        Color directionColor;
        if (missed) {
          directionIcon = call.isOutgoing ? Icons.call_made_rounded : Icons.call_missed_rounded;
          directionColor = AppTheme.errorColor;
        } else {
          directionIcon = call.isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded;
          directionColor = AppTheme.successColor;
        }

        String subtitle;
        if (missed) {
          subtitle = call.isOutgoing ? 'Not answered' : 'Missed call';
        } else if (call.durationSeconds != null) {
          final mins = call.durationSeconds! ~/ 60;
          final secs = call.durationSeconds! % 60;
          subtitle = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
        } else {
          subtitle = call.isOutgoing ? 'Outgoing call' : 'Incoming call';
        }

        final dt = call.startedAt;
        final now = DateTime.now();
        final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
        final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour < 12 ? 'AM' : 'PM';
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        final dateLabel = isToday
            ? '$hour12:$minute $ampm'
            : '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}, $hour12:$minute $ampm';

        void call_() {
          if (call.bookingId != null) {
            startBookingAudioCall(context, bookingId: call.bookingId!, peerDisplayName: peerName);
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: call.bookingId != null ? call_ : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Text(peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(peerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: missed ? AppTheme.errorColor : const Color(0xFF1A1F36),
                          )),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(directionIcon, size: 14, color: directionColor),
                          const SizedBox(width: 4),
                          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(dateLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    IconButton(
                      icon: const Icon(Icons.call_outlined, color: AppTheme.primaryColor, size: 20),
                      tooltip: 'Call',
                      onPressed: call.bookingId != null ? call_ : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _videoCallList(ConsultationProvider provider) {
    if (provider.isLoadingHistory && provider.history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.history.isEmpty) {
      return const Center(child: Text('No video calls yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = provider.history[i];
        final customerName = c.customerName?.isNotEmpty == true ? c.customerName! : 'Customer';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: const Icon(Icons.videocam_outlined, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(
                      c.scheduledAt != null ? 'Scheduled on ${_formatDate(c.scheduledAt!)}' : _formatDate(c.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(c.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(c.status),
                  style: TextStyle(fontSize: 11, color: _statusColor(c.status), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Jobs this technician offered a warranty on — most recent first. Reuses
  /// BookingProvider.bookings (already loaded for the Jobs tab), filtered to
  /// warrantyEnabled == true, so no extra network call is needed.
  Widget _warrantyList(List<Booking> bookings) {
    final warrantyBookings = bookings.where((b) => b.warrantyEnabled).toList()
      ..sort((a, b) => (b.warrantyExpiresAt ?? DateTime(0)).compareTo(a.warrantyExpiresAt ?? DateTime(0)));

    if (warrantyBookings.isEmpty) {
      return const Center(child: Text('No warranties offered yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: warrantyBookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = warrantyBookings[i];
        final customerName = b.customer?.name.isNotEmpty == true ? b.customer!.name : 'Customer';
        final active = b.warrantyExpiresAt != null && b.warrantyExpiresAt!.isAfter(DateTime.now());
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: (active ? AppTheme.primaryColor : Colors.grey).withValues(alpha: 0.12),
                child: Icon(Icons.shield_outlined, color: active ? AppTheme.primaryColor : Colors.grey[600], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(
                      _formatWarrantyDuration(b.warrantyDays),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (b.warrantyExpiresAt != null)
                      Text(
                        active
                            ? 'Valid until ${_formatDate(b.warrantyExpiresAt!)}'
                            : 'Expired on ${_formatDate(b.warrantyExpiresAt!)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (active ? AppTheme.primaryColor : Colors.grey).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active ? 'Active' : 'Expired',
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? AppTheme.primaryColor : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// warrantyDays is always stored in total days (see BookingService.Complete),
  /// regardless of whether the technician originally picked days/months/years
  /// — so this converts back to the friendliest display unit.
  String _formatWarrantyDuration(int? days) {
    if (days == null) return 'Warranty offered';
    if (days % 365 == 0 && days >= 365) {
      final years = days ~/ 365;
      return '$years ${years == 1 ? 'year' : 'years'} warranty';
    }
    if (days % 30 == 0 && days >= 30) {
      final months = days ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} warranty';
    }
    return '$days ${days == 1 ? 'day' : 'days'} warranty';
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  /// Plain-language label for the technician's own video call history —
  /// "cancelled" while the call was still ringing reads as a missed call
  /// from the technician's side (they never answered in time), and
  /// "rejected" is when the technician explicitly declined it.
  String _statusLabel(String status) {
    switch (status) {
      case 'cancelled':
        return 'Missed';
      case 'rejected':
        return 'Declined';
      case 'no_technician':
        return 'No technician found';
      case 'ended':
        return 'Completed';
      case 'ringing':
        return 'Ringing';
      case 'in_call':
        return 'In call';
      case 'accepted':
        return 'Accepted';
      case 'scheduled':
        return 'Awaiting confirmation';
      case 'confirmed':
        return 'Confirmed';
      case 'searching':
        return 'Searching';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'cancelled':
        return Colors.grey[600]!;
      case 'rejected':
        return Colors.red[700]!;
      case 'no_technician':
        return Colors.red[700]!;
      case 'ended':
        return Colors.grey[700]!;
      default:
        return AppTheme.primaryColor;
    }
  }
}