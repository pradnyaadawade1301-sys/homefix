import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../chat/booking_chat_screen.dart';

/// Technician-facing History tab — one place to see every job's chat thread
/// and how much the customer paid for it. Reuses the same booking list
/// already loaded by TechnicianJobsScreen (BookingProvider.bookings), so it
/// needs no new backend endpoint.
///
/// Note: there's no video-call log here — video calling isn't wired up for
/// regular jobs yet (only for the separate paid "Live Consultation" flow),
/// so there's no call history data to show for jobs.
class TechnicianHistoryScreen extends StatefulWidget {
  const TechnicianHistoryScreen({super.key});

  @override
  State<TechnicianHistoryScreen> createState() => _TechnicianHistoryScreenState();
}

class _TechnicianHistoryScreenState extends State<TechnicianHistoryScreen> {
  int _tab = 0; // 0 = Chats, 1 = Payments

  @override
  Widget build(BuildContext context) {
    final bookings = context.watch<BookingProvider>().bookings;

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
                child: _tabChip('Payments', 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0 ? _chatsList(bookings) : _paymentsList(bookings),
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
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BookingChatScreen(bookingId: b.id, peerName: customerName),
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentsList(List<Booking> bookings) {
    final paid = bookings.where((b) => b.isPaid && b.displayPrice != null).toList();
    if (paid.isEmpty) {
      return const Center(child: Text('No payments yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: paid.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = paid[i];
        final customerName = b.customer?.name.isNotEmpty == true ? b.customer!.name : 'Customer';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text('Paid on ${_formatDate(b.updatedAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Text('\u20b9${b.displayPrice!.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryColor)),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}