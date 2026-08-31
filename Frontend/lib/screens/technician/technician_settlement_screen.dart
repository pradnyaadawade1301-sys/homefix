import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/payment_provider.dart';

/// Technician-facing settlement/history screen.
///
/// Shows:
///  1. An earnings summary (total earned + jobs completed).
///  2. Visit history — every completed job: customer, address, date, amount.
///  3. Payment history — every settlement record from PaymentProvider.history()
///     (amount, status, method, date, invoice number).
///
/// NOTE: video-call history isn't shown here yet because there's no backend
/// endpoint that returns a technician's past consultations (only the live
/// "pending requests" queue exists today — see ConsultationService). Once
/// that endpoint exists this screen has a clearly marked spot to slot it in.
class TechnicianSettlementScreen extends StatefulWidget {
  final Key? tourKey;
  const TechnicianSettlementScreen({Key? key, this.tourKey}) : super(key: key);

  @override
  State<TechnicianSettlementScreen> createState() => _TechnicianSettlementScreenState();
}

class _TechnicianSettlementScreenState extends State<TechnicianSettlementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<PaymentProvider>().loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Consumer2<BookingProvider, PaymentProvider>(
        builder: (context, bookingProvider, paymentProvider, _) {
          final completedJobs = bookingProvider.bookings.where((b) => b.status == 'completed').toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final payments = List<Payment>.from(paymentProvider.history)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final totalEarned = payments
              .where((p) => p.isPaid)
              .fold<double>(0, (sum, p) => sum + (p.technicianEarning ?? p.amount));

          final isLoading = paymentProvider.isLoadingHistory && payments.isEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Container(key: widget.tourKey, child: _SummaryCard(totalEarned: totalEarned, jobsCompleted: completedJobs.length)),
              const SizedBox(height: 24),
              const Text('Visit History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Jobs you have completed, with where you went and when.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              if (completedJobs.isEmpty)
                _emptyRow('No completed visits yet')
              else
                ...completedJobs.map((b) => _VisitTile(booking: b)),
              const SizedBox(height: 28),
              const Text('Payment / Settlement History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'What was paid, when, and how much of it was yours.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (payments.isEmpty)
                _emptyRow('No payments yet')
              else
                ...payments.map((p) => _PaymentTile(payment: p)),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyRow(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalEarned;
  final int jobsCompleted;
  const _SummaryCard({required this.totalEarned, required this.jobsCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Earned', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(
                  '₹${totalEarned.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Jobs Completed', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text(
                '$jobsCompleted',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final Booking booking;
  const _VisitTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final customerName = booking.customer?.name ?? 'Customer';
    final date = booking.updatedAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.successColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$customerName · ${booking.categoryName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 3),
                if (booking.address != null)
                  Text(
                    booking.address!.formatted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                const SizedBox(height: 3),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (booking.finalPrice != null || booking.estimatedPrice != null)
            Text(
              '₹${(booking.finalPrice ?? booking.estimatedPrice)!.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1A1F36)),
            ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Payment payment;
  const _PaymentTile({required this.payment});

  Color get _statusColor {
    if (payment.isPaid) return AppTheme.successColor;
    if (payment.isFailed) return AppTheme.errorColor;
    if (payment.isRefunded) return AppTheme.warningColor;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final date = payment.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance_wallet_outlined, color: _statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('₹${payment.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(payment.status, style: TextStyle(fontSize: 10.5, color: _statusColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (payment.technicianEarning != null)
                  Text('Your share: ₹${payment.technicianEarning!.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 3),
                Text(
                  '${date.day}/${date.month}/${date.year}'
                  '${payment.method != null ? ' · ${payment.method}' : ''}'
                  '${payment.invoiceNumber != null ? ' · ${payment.invoiceNumber}' : ''}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}