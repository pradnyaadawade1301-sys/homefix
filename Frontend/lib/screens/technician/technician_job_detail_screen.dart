import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/technician_theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/payment_provider.dart';
import '../../models/payment_model.dart';
import '../../core/booking_call_launcher.dart';
import '../chat/booking_chat_screen.dart';
import 'job_brief_card.dart';
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
      case 'repair_in_progress':
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
      case 'pending_technician':
        return 'Awaiting your response';
      case 'accepted':
        return 'Accepted';
      case 'on_the_way':
        return 'On the way';
      case 'arrived':
        return 'Arrived';
      case 'in_progress':
        return 'In progress';
      case 'repair_in_progress':
        return 'Repair in progress';
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
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    current.categoryName.isNotEmpty ? current.categoryName : 'Service request',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (current.isUrgent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '🚨 Urgent',
                                      style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
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
                      if (current.displayPrice != null && current.finalPrice != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Final amount: \u20b9${current.displayPrice!.toStringAsFixed(0)} (${current.isPaid ? "paid" : "payment pending"})',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                        ),
                      ],
                      // Only offer "Confirm cash received" once the
                      // completion photo has actually been uploaded — the
                      // photo (proof of finished work) should exist before
                      // money changes hands, not the other way around.
                      if (!current.isPaid && provider.afterPhotos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _CashReceivedButton(bookingId: current.id),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (current.jobBrief != null || current.images.isNotEmpty) JobBriefCard(booking: current),
                if (customer != null) ...[
                  Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey[800])),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TechTheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: TechTheme.primary.withValues(alpha: 0.15),
                              child: Text(
                                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: TechTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name.isNotEmpty ? customer.name : 'Customer',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
                                icon: const Icon(Icons.call_outlined, size: 16),
                                label: const Text('Call'),
                                onPressed: isCallableBookingStatus(current.status)
                                    ? () => startBookingAudioCall(
                                          context,
                                          bookingId: current.id,
                                          peerDisplayName: customer.name.isNotEmpty ? customer.name : 'Customer',
                                        )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 20),
                _JobPhotosSection(bookingId: current.id),
                const SizedBox(height: 20),
                JobActionRow(booking: current),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Before/after" proof-photo strip — shows what's already been uploaded for
/// this job, and always offers an "Add Photos" action (opens
/// [JobPhotosSheet] with both sections) so the technician can add a "Before"
/// shot any time during the visit, not just the "After" shot prompted right
/// after completion (see _showInvoiceDialog).
class _JobPhotosSection extends StatefulWidget {
  final String bookingId;
  const _JobPhotosSection({required this.bookingId});

  @override
  State<_JobPhotosSection> createState() => _JobPhotosSectionState();
}

class _JobPhotosSectionState extends State<_JobPhotosSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchJobPhotos(widget.bookingId);
    });
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => JobPhotosSheet(bookingId: widget.bookingId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        return Container(
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
                  const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  TextButton.icon(
                    onPressed: _openSheet,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('Add Photos'),
                    style: TextButton.styleFrom(foregroundColor: TechTheme.primary, padding: EdgeInsets.zero),
                  ),
                ],
              ),
              if (provider.beforePhotos.isEmpty && provider.afterPhotos.isEmpty)
                Text('No photos added yet.', style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
              if (provider.beforePhotos.isNotEmpty) ...[
                const SizedBox(height: 10),
                _strip('Before', provider.beforePhotos),
              ],
              if (provider.afterPhotos.isNotEmpty) ...[
                const SizedBox(height: 14),
                _strip('After', provider.afterPhotos),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _strip(String label, List<BookingJobPhoto> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(photos[i].imageUrl, width: 80, height: 80, fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Cash Received" action for a Cash on Delivery booking — invisible unless
/// there's actually a pending cash payment for this booking (see
/// PaymentProvider.getPendingCodByBooking), so it stays out of the way for
/// every online-paid job, which is the overwhelming majority.
class _CashReceivedButton extends StatefulWidget {
  final String bookingId;
  const _CashReceivedButton({required this.bookingId});

  @override
  State<_CashReceivedButton> createState() => _CashReceivedButtonState();
}

class _CashReceivedButtonState extends State<_CashReceivedButton> {
  Payment? _payment;
  bool _loading = true;
  bool _confirming = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // The customer may pick "Cash on Delivery" (which creates the pending
    // cash Payment this button watches for) AFTER the technician already has
    // this screen open — without polling, the button would never appear
    // until they manually left and reopened the job.
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final payment = await context.read<PaymentProvider>().getPendingCodByBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_confirming || _payment == null) return;
    setState(() => _confirming = true);
    try {
      await context.read<PaymentProvider>().confirmCash(_payment!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash payment confirmed — commission debited from your wallet.')),
      );
      setState(() => _payment = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _payment == null) return const SizedBox.shrink();
    final payment = _payment!;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _confirming ? null : _confirm,
          icon: _confirming
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.payments_outlined, size: 18),
          label: Text(_confirming ? 'Confirming…' : 'Confirm ₹${payment.amount.toStringAsFixed(0)} cash received'),
          style: OutlinedButton.styleFrom(foregroundColor: TechTheme.primary, side: const BorderSide(color: TechTheme.primary)),
        ),
      ),
    );
  }
}