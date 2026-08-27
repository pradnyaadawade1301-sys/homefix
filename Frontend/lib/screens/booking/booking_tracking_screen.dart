import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/contact_actions.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../payment/payment_screen.dart';
import '../chat/booking_chat_screen.dart';

/// Step 9 of the customer flow ("Booking Tracking").
///
/// HONEST SCOPE NOTE: the spec's 8-step flow (Pending -> Technician Assigned
/// -> On The Way -> Arrived -> Service Started -> Service Completed ->
/// Payment Pending -> Completed) is finer-grained than what the backend
/// currently models. homefix_backend/internal/models/booking.go only has 5
/// real statuses: requested, accepted, in_progress, completed, cancelled —
/// and there's no payment table/status yet. Rather than fake the extra steps
/// client-side, this screen shows a stepper for the 4 real stages plus the
/// ACTUAL status_history log (real timestamps, real notes from
/// GET /bookings/:id/history). Getting the exact 8-step granularity would
/// need new backend statuses (e.g. "on_the_way", "arrived") — that's a
/// follow-up if you want it.
class BookingTrackingScreen extends StatefulWidget {
  final String bookingId;
  const BookingTrackingScreen({Key? key, required this.bookingId}) : super(key: key);

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<BookingProvider>().fetchBookingDetail(widget.bookingId);

  static const _stages = ['requested', 'accepted', 'in_progress', 'completed'];
  static const _stageLabels = {
    'requested': 'Pending Assignment',
    'accepted': 'Technician Assigned',
    'in_progress': 'Service In Progress',
    'completed': 'Service Completed',
  };
  static const _stageIcons = {
    'requested': Icons.search_rounded,
    'accepted': Icons.person_pin_circle_rounded,
    'in_progress': Icons.build_rounded,
    'completed': Icons.check_circle_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Booking')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Consumer<BookingProvider>(
            builder: (context, provider, _) {
              final booking = provider.selectedBooking;
              if (provider.isLoading && booking == null) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }
              if (booking == null) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        provider.error ?? 'Booking not found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                );
              }

              if (booking.status == 'cancelled') {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cancel_rounded, color: AppTheme.errorColor),
                          SizedBox(width: 10),
                          Expanded(child: Text('This booking was cancelled', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _historySection(provider.history),
                  ],
                );
              }

              final currentIndex = _stages.indexOf(booking.status).clamp(0, _stages.length - 1);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStepper(currentIndex),
                  const SizedBox(height: 24),
                  if (booking.technician != null) ...[
                    _technicianCard(booking.technician!),
                    const SizedBox(height: 24),
                  ] else if (booking.status == 'requested') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Text('Searching for nearby technician...', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (booking.isInvoiced && !booking.isPaid) ...[
                    _paymentDueCard(booking),
                    const SizedBox(height: 24),
                  ] else if (booking.isInvoiced && booking.isPaid) ...[
                    _paidCard(booking),
                    const SizedBox(height: 24),
                  ],
                  if (booking.problemDescription.isNotEmpty) ...[
                    const Text('Issue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(booking.problemDescription, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    const SizedBox(height: 24),
                  ],
                  _historySection(provider.history),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Shown once the technician has marked the job "completed" — the amount is
  /// [Booking.displayPrice] (final price if the technician set one, else the
  /// original estimate). Tapping it opens the existing UPI PaymentScreen.
  /// Shown once the customer has already paid the invoice — replaces the
  /// "Pay Now" card so there's no way to accidentally trigger a second
  /// payment for the same booking.
  Widget _paidCard(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Paid ₹${booking.displayPrice!.toStringAsFixed(0)} — thank you!',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentDueCard(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Service completed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Amount due: ₹${booking.displayPrice!.toStringAsFixed(0)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: const Text('Pay Now'),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PaymentScreen(
                    bookingId: booking.id,
                    amount: booking.displayPrice!,
                    bookingTitle: booking.categoryName.isNotEmpty ? booking.categoryName : 'Service booking',
                  ),
                ));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(int currentIndex) {
    return Row(
      children: List.generate(_stages.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepBefore = i ~/ 2;
          final reached = stepBefore < currentIndex;
          return Expanded(
            child: Container(height: 3, color: reached ? AppTheme.primaryColor : Colors.grey[300]),
          );
        }
        final stageIndex = i ~/ 2;
        final stage = _stages[stageIndex];
        final reached = stageIndex <= currentIndex;
        return Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: reached ? AppTheme.primaryColor : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(_stageIcons[stage], color: reached ? Colors.white : Colors.grey[500], size: 20),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                _stageLabels[stage] ?? stage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                  color: reached ? const Color(0xFF1A1F36) : Colors.grey[500],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _technicianCard(BookingTechnicianInfo tech) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: Text(
              tech.name.isNotEmpty ? tech.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tech.name.isNotEmpty ? tech.name : 'Technician',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (tech.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 15, color: Colors.blue),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('${tech.categoryName} • ${tech.experienceYears} yrs experience',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A623)),
                    const SizedBox(width: 2),
                    Text('${tech.ratingAvg.toStringAsFixed(1)} (${tech.ratingCount} reviews)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
     Container(
  decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
  child: IconButton(
    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
    tooltip: 'Chat',
    onPressed: () {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookingChatScreen(
          bookingId: widget.bookingId,
          peerName: tech.name.isNotEmpty ? tech.name : 'Technician',
        ),
      ));
    },
  ),
),
        ],
      ),
    );
  }

  Widget _historySection(List<BookingStatusHistory> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status updates', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        ...history.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stageLabels[h.status] ?? h.status,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (h.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(h.note, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${h.createdAt.day}/${h.createdAt.month}/${h.createdAt.year} • ${h.createdAt.hour.toString().padLeft(2, '0')}:${h.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}