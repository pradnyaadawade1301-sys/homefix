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
///  2. A tab switcher — Visit History (every completed job: customer,
///     address, date, amount) vs Payment History (every settlement record
///     from PaymentProvider.history(): amount, status, method, date,
///     invoice number) — mirrors the Chats/Video Call tab pattern used on
///     the technician History screen for a consistent, less cluttered feel.
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
  int _tab = 0; // 0 = Visit History, 1 = Payment History

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

          final isLoadingPayments = paymentProvider.isLoadingHistory && payments.isEmpty;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    key: widget.tourKey,
                    child: _SummaryCard(totalEarned: totalEarned, jobsCompleted: completedJobs.length),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabChip(
                          icon: Icons.route_outlined,
                          label: 'Visit History',
                          index: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tabChip(
                          icon: Icons.receipt_long_outlined,
                          label: 'Payment History',
                          index: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_tab == 0)
                _buildVisitSliver(completedJobs)
              else
                _buildPaymentSliver(payments, isLoadingPayments),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _tabChip({required IconData icon, required String label, required int index}) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppTheme.primaryColor : Colors.grey[300]!),
          boxShadow: selected
              ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitSliver(List<Booking> completedJobs) {
    if (completedJobs.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(Icons.route_outlined, 'No completed visits yet'));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      sliver: SliverList.separated(
        itemCount: completedJobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _VisitTile(booking: completedJobs[i]),
      ),
    );
  }

  Widget _buildPaymentSliver(List<Payment> payments, bool isLoading) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (payments.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(Icons.receipt_long_outlined, 'No payments yet'));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      sliver: SliverList.separated(
        itemCount: payments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _PaymentTile(payment: payments[i]),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
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