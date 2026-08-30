import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../payment/payment_screen.dart';
import '../chat/booking_chat_screen.dart';

/// Step 9 of the customer flow ("Booking Tracking").
///
/// Mirrors the full technician-flow spec: Pending -> Technician Assigned ->
/// On The Way -> Arrived (OTP shown here) -> Service In Progress -> Service
/// Completed, backed by the real booking.status + status_history log from
/// GET /bookings/:id/history.
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

  Future<void> _load() async {
    final provider = context.read<BookingProvider>();
    await provider.fetchBookingDetail(widget.bookingId);
    if (!mounted) return;
    await provider.fetchJobPhotos(widget.bookingId);
  }

  static const _stages = ['requested', 'accepted', 'on_the_way', 'arrived', 'in_progress', 'completed'];
  static const _stageLabels = {
    'requested': 'Pending Assignment',
    'accepted': 'Technician Assigned',
    'on_the_way': 'On The Way',
    'arrived': 'Technician Arrived',
    'in_progress': 'Service In Progress',
    'awaiting_estimate_approval': 'Estimate Awaiting Approval',
    'completed': 'Service Completed',
  };
  static const _stageIcons = {
    'requested': Icons.search_rounded,
    'accepted': Icons.person_pin_circle_rounded,
    'on_the_way': Icons.directions_run_rounded,
    'arrived': Icons.home_rounded,
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

              final currentIndex = booking.status == 'awaiting_estimate_approval'
                  ? _stages.indexOf('in_progress')
                  : _stages.indexOf(booking.status).clamp(0, _stages.length - 1);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStepper(currentIndex),
                  const SizedBox(height: 24),
                  if (booking.isAwaitingEstimateApproval) ...[
                    _estimateApprovalCard(context, provider, booking),
                    const SizedBox(height: 24),
                  ],
                  if (booking.status == 'arrived' && booking.otpCode != null) ...[
                    _otpCard(booking.otpCode!),
                    const SizedBox(height: 24),
                  ],
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
                  if (provider.jobPhotos.isNotEmpty) ...[
                    _jobPhotosSection(provider),
                    const SizedBox(height: 24),
                  ],
                  _historySection(provider.history),
                  if (_canCancel(booking.status)) ...[
                    const SizedBox(height: 24),
                    _cancelBookingButton(context, provider, booking),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Shown to the customer while a technician's estimate is pending their
  /// decision (booking.status == 'awaiting_estimate_approval'). Approve
  /// sends the technician back to work with the agreed total; Decline asks
  /// for an optional reason and sends the technician back to revise;
  /// Discuss just opens the existing booking chat.
  Widget _estimateApprovalCard(BuildContext context, BookingProvider provider, Booking booking) {
    final estimate = provider.currentEstimate;
    if (estimate == null || !estimate.isPending) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Text('Loading estimate...', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
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
              Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Estimate ready for your approval',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ],
          ),
          if ((estimate.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(estimate.note!, style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
          ],
          const SizedBox(height: 14),
          if (estimate.labourItems.isNotEmpty) ..._estimateItemGroup('Labour', estimate.labourItems),
          if (estimate.partItems.isNotEmpty) ..._estimateItemGroup('Parts', estimate.partItems),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('\u20b9${estimate.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineEstimate(context, provider, booking.id, estimate.id),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Discuss'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BookingChatScreen(
                        bookingId: booking.id,
                        peerName: booking.technician?.name ?? 'Technician',
                      ),
                    ));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respond(context, provider, booking.id, estimate.id, 'approve'),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mirrors the backend's own cancellation guard (see BookingService.Cancel):
  /// once the technician has actually started the job, or the booking is
  /// already completed/cancelled, there's nothing left to cancel.
  bool _canCancel(String status) {
    return !['in_progress', 'completed', 'cancelled'].contains(status);
  }

  Widget _cancelBookingButton(BuildContext context, BookingProvider provider, Booking booking) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text('Cancel Booking'),
        onPressed: () => _confirmCancel(context, provider, booking.id),
      ),
    );
  }

  /// Uber-style two-step cancel: a reason sheet, then the actual API call,
  /// with a clear confirm/cancel snackbar either way so the customer always
  /// knows what just happened.
  Future<void> _confirmCancel(BuildContext context, BookingProvider provider, String bookingId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will cancel your booking and notify the technician, if one has been assigned.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Booked by mistake, found another option',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (reason == null) return; // user tapped "Keep Booking" / dismissed
    if (!mounted) return;

    final ok = await provider.cancelBooking(bookingId, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Booking cancelled' : (provider.error ?? 'Could not cancel booking')),
        backgroundColor: ok ? AppTheme.errorColor : null,
      ),
    );
  }

  List<Widget> _estimateItemGroup(String label, List<BookingEstimateItem> items) {
    return [
      Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey[600])),
      const SizedBox(height: 4),
      ...items.map((it) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    it.quantity == 1 ? it.name : '${it.name} × ${it.quantity.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text('\u20b9${it.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
      const SizedBox(height: 8),
    ];
  }

  Future<void> _respond(BuildContext context, BookingProvider provider, String bookingId, String estimateId, String action, {String? note}) async {
    final ok = await provider.respondToEstimate(bookingId: bookingId, estimateId: estimateId, action: action, note: note);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'approve' ? 'Estimate approved' : 'Estimate declined')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Something went wrong')),
      );
    }
  }

  Future<void> _declineEstimate(BuildContext context, BookingProvider provider, String bookingId, String estimateId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline estimate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Too expensive, want to discuss parts cost',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    if (!mounted) return;
    await _respond(context, provider, bookingId, estimateId, 'decline', note: reason.isEmpty ? null : reason);
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

  /// Uber-style arrival OTP: shown to the CUSTOMER once the technician has
  /// marked themselves "arrived". They read these digits out to the
  /// technician, who types them into their app to actually start the job —
  /// this is what proves the technician is genuinely on-site.
  Widget _otpCard(String otp) {
    final digits = otp.split('');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Share this OTP with your technician',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your technician has arrived. Give them this code to confirm and start the service.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: digits
                .map((d) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 42,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(int currentIndex) {
    // A vertical timeline instead of the old horizontal icon row — it never
    // overflows on narrow screens (labels wrap naturally) and reads more
    // like a premium delivery-tracking screen.
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: List.generate(_stages.length, (i) {
          final stage = _stages[i];
          final isLast = i == _stages.length - 1;
          final isCurrent = i == currentIndex;
          final isDone = i < currentIndex;
          final reached = i <= currentIndex;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isCurrent ? 40 : 32,
                      height: isCurrent ? 40 : 32,
                      decoration: BoxDecoration(
                        color: reached ? AppTheme.primaryColor : Colors.grey[200],
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  spreadRadius: 3,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : _stageIcons[stage],
                        color: reached ? Colors.white : Colors.grey[400],
                        size: isCurrent ? 20 : 16,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 3,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: isDone ? AppTheme.primaryColor : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 16 : 26, top: isCurrent ? 6 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stageLabels[stage] ?? stage,
                          style: TextStyle(
                            fontSize: isCurrent ? 15.5 : 13.5,
                            fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                            color: reached ? const Color(0xFF1A1F36) : Colors.grey[400],
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(height: 3),
                          Text(
                            'In progress...',
                            style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
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

  /// Before/after proof photos the technician attached to this job (see
  /// JobPhotosSheet on the technician side) — GET /bookings/:id/photos.
  Widget _jobPhotosSection(BookingProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Job photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        if (provider.beforePhotos.isNotEmpty) ...[
          Text('Before', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _photoStrip(provider.beforePhotos),
          const SizedBox(height: 16),
        ],
        if (provider.afterPhotos.isNotEmpty) ...[
          Text('After', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _photoStrip(provider.afterPhotos),
        ],
      ],
    );
  }

  Widget _photoStrip(List<BookingJobPhoto> photos) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final photo = photos[i];
          return GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: InteractiveViewer(child: Image.network(photo.imageUrl)),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(photo.imageUrl, width: 90, height: 90, fit: BoxFit.cover),
            ),
          );
        },
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