import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/contact_actions.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../chat/booking_chat_screen.dart';
import 'job_photos_sheet.dart';
import 'technician_jobs_screen.dart' show JobActionRow;

/// Full-detail view of a single job, reached by tapping the customer block on
/// a job card in [TechnicianJobsScreen]. Everything shown here is already
/// present on [Booking] (no extra network round trip needed to open it), but
/// the screen keeps listening to [BookingProvider] so it stays live if the
/// technician advances the job's status from here.
class TechnicianJobDetailScreen extends StatelessWidget {
  final Booking booking;
  const TechnicianJobDetailScreen({Key? key, required this.booking}) : super(key: key);

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'in_progress':
      case 'accepted':
      case 'on_the_way':
      case 'arrived':
      case 'awaiting_estimate_approval':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'requested':
        return 'Pending assignment';
      case 'accepted':
        return 'Accepted';
      case 'on_the_way':
        return 'On the way';
      case 'arrived':
        return 'Arrived';
      case 'in_progress':
        return 'In progress';
      case 'awaiting_estimate_approval':
        return 'Awaiting customer approval';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} • $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        // Prefer the live copy from the provider's list (kept up to date as
        // the technician advances the job), falling back to the snapshot
        // passed in if it's not there for some reason.
        final live = provider.bookings.where((b) => b.id == booking.id).toList();
        final current = live.isNotEmpty ? live.first : booking;
        final customer = current.customer;

        return Scaffold(
          appBar: AppBar(title: const Text('Job Details')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              current.categoryName.isNotEmpty ? current.categoryName : 'Service request',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(current.status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(current.status),
                              style: TextStyle(fontSize: 11, color: _statusColor(current.status), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (current.problemDescription.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Issue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(current.problemDescription, style: TextStyle(fontSize: 13.5, color: Colors.grey[800])),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        current.scheduledAt != null
                            ? 'Scheduled for ${_formatDateTime(current.scheduledAt!)}'
                            : 'Booked ${_formatDateTime(current.createdAt)}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                      ),
                      if (current.displayPrice != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          current.finalPrice != null
                              ? 'Final amount: \u20b9${current.displayPrice!.toStringAsFixed(0)} (${current.isPaid ? "paid" : "payment pending"})'
                              : 'Estimated: \u20b9${current.displayPrice!.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (customer != null) ...[
                  Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey[800])),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Text(
                                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name.isNotEmpty ? customer.name : 'Customer',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  if (customer.phone.isNotEmpty)
                                    Text(customer.phone, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (current.address != null) ...[
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(current.address!.formatted, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (customer.phone.isNotEmpty) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.call_outlined, size: 16),
                                  label: const Text('Call'),
                                  onPressed: () => callContact(context, customer.phone),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.chat_outlined, size: 16),
                                  label: const Text('WhatsApp'),
                                  onPressed: () => openWhatsApp(context, customer.phone),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.forum_outlined, size: 16),
                                label: const Text('Chat'),
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => BookingChatScreen(
                                    bookingId: current.id,
                                    peerName: customer.name.isNotEmpty ? customer.name : 'Customer',
                                  ),
                                )),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (current.status != 'requested' && current.status != 'cancelled') ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Before / after photos'),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => JobPhotosSheet(bookingId: current.id),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                JobActionRow(booking: current),
              ],
            ),
          ),
        );
      },
    );
  }
}