import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/consultation_provider.dart';
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
  int _tab = 0; // 0 = Chats, 1 = Video Call

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ConsultationProvider>().loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final bookings = context.watch<BookingProvider>().bookings;
    final consultationProvider = context.watch<ConsultationProvider>();

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
            ],
          ),
        ),
        Expanded(
          child: _tab == 0
              ? _chatsList(bookings)
              : _videoCallList(consultationProvider),
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
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BookingChatScreen(bookingId: b.id, peerName: customerName),
          )),
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
              const Icon(Icons.forum_outlined, color: AppTheme.primaryColor),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c.status.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}