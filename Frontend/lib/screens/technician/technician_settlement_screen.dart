import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme.dart';
import '../../core/technician_theme.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/due_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/payment_provider.dart';
import '../../l10n/app_localizations.dart';
import '../payment/invoice_screen.dart';
import 'technician_job_detail_screen.dart';

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

  // One Razorpay instance for the whole screen, shared by the top "Pay Dues"
  // card and every payment row's "Pay commission" button (the plugin routes
  // native callbacks to a single listener, so per-row instances would clash).
  late final Razorpay _razorpay;
  String? _orderId;
  String? _payingDueId; // which row's button is busy (null = top card / none)

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Pays all pending dues (dueId == null) or a single payment's commission.
  Future<void> _payDues({String? dueId}) async {
    final provider = context.read<PaymentProvider>();
    setState(() => _payingDueId = dueId);
    final order = await provider.createDueOrder(dueId: dueId);
    if (!mounted) return;
    if (order == null) {
      setState(() => _payingDueId = null);
      _snack(provider.error ?? 'Could not start payment');
      return;
    }
    _orderId = order.razorpayOrderId;
    try {
      _razorpay.open({
        'key': order.razorpayKeyId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'order_id': order.razorpayOrderId,
        'name': 'OneFix Live',
        'description': 'Commission dues',
        'timeout': 300,
      });
    } catch (e) {
      setState(() => _payingDueId = null);
      _snack('Could not open payment sheet: $e');
    }
  }

  Future<void> _onPaySuccess(PaymentSuccessResponse r) async {
    final provider = context.read<PaymentProvider>();
    final ok = await provider.verifyDuePayment(
      orderId: r.orderId ?? _orderId ?? '',
      paymentId: r.paymentId ?? '',
      signature: r.signature ?? '',
    );
    if (mounted) setState(() => _payingDueId = null);
    _snack(ok ? 'Commission paid successfully.' : (provider.error ?? 'Could not verify payment'));
  }

  void _onPayError(PaymentFailureResponse r) {
    if (mounted) setState(() => _payingDueId = null);
    _snack(r.message ?? 'Payment cancelled');
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<PaymentProvider>();
    await Future.wait([provider.loadHistory(), provider.fetchDues()]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: Consumer2<BookingProvider, PaymentProvider>(
        builder: (context, bookingProvider, paymentProvider, _) {
          final completedJobs = bookingProvider.bookings.where((b) => b.status == 'completed').toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          // Payment History: one row per booking payment. Paid rows always
          // show; a payment that was only ever "created" (an abandoned or
          // still-open checkout) shows as "unpaid" — but only if that same
          // booking has no paid payment, and only its latest attempt, so a
          // paid job never also lists its stale "created" duplicates.
          final all = List<Payment>.from(paymentProvider.history)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final paidKeys = <String>{
            for (final p in all)
              if (p.isPaid) '${p.bookingId}|${p.paymentType}',
          };
          final seenUnpaid = <String>{};
          final payments = <Payment>[];
          for (final p in all) {
            final key = '${p.bookingId}|${p.paymentType}';
            if (p.isPaid || p.isRefunded) {
              payments.add(p);
            } else if (!paidKeys.contains(key) && seenUnpaid.add(key)) {
              payments.add(p); // latest unpaid attempt only
            }
          }

          // Total Earned = the technician's share of every PAID service
          // payment, counted once per booking. Visit-fee payments and
          // unpaid/created/refunded rows never count, and a missing share is
          // never replaced by the full customer amount (which includes GST
          // and platform fees the technician doesn't earn).
          final earnedByBooking = <String, double>{};
          for (final p in all) {
            if (!p.isPaid || p.isVisitFee) continue;
            earnedByBooking.putIfAbsent(p.bookingId, () => p.technicianEarning ?? 0);
          }
          final totalEarned = earnedByBooking.values.fold<double>(0, (sum, v) => sum + v);

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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _DuesCard(
                    dues: paymentProvider.dues,
                    isLoading: paymentProvider.isLoadingDues,
                    paying: paymentProvider.isPayingDues,
                    onPay: () => _payDues(),
                    error: paymentProvider.dues == null ? paymentProvider.error : null,
                    onRetry: () => context.read<PaymentProvider>().fetchDues(),
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
                          label: l10n.techSettlementVisitHistory,
                          index: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tabChip(
                          icon: Icons.receipt_long_outlined,
                          label: l10n.techSettlementPaymentHistory,
                          index: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_tab == 0)
                _buildVisitSliver(completedJobs, l10n)
              else
                _buildPaymentSliver(payments, isLoadingPayments, l10n, paymentProvider.dues),
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
          color: selected ? TechTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? TechTheme.primary : Colors.grey[300]!),
          boxShadow: selected
              ? [BoxShadow(color: TechTheme.primary.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 4))]
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

  Widget _buildVisitSliver(List<Booking> completedJobs, AppLocalizations l10n) {
    if (completedJobs.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(Icons.route_outlined, l10n.techSettlementNoCompletedVisits));
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

  Widget _buildPaymentSliver(List<Payment> payments, bool isLoading, AppLocalizations l10n, DueSummary? dues) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (payments.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(Icons.receipt_long_outlined, l10n.techSettlementNoPayments));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      sliver: SliverList.separated(
        itemCount: payments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = payments[i];
          DueItem? due;
          if (dues != null) {
            for (final d in dues.dues) {
              if (d.isPending && d.paymentId == p.id) {
                due = d;
                break;
              }
            }
          }
          return _PaymentTile(
            payment: p,
            pendingDue: due,
            paying: _payingDueId != null && _payingDueId == due?.id,
            anyPaying: _payingDueId != null,
            onPayCommission: due == null ? null : () => _payDues(dueId: due!.id),
          );
        },
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

/// COD commission dues. When the technician confirms cash received, the
/// platform's commission becomes a pending due (DueService). Once dues cross
/// the limit (or any due is too old) Cash-on-Delivery jobs are blocked until
/// the technician pays them here via Razorpay (UPI / cards / netbanking).
class _DuesCard extends StatelessWidget {
  final DueSummary? dues;
  final bool isLoading;
  final bool paying;
  final VoidCallback onPay;
  final String? error; // set when GET /technician/dues failed
  final VoidCallback onRetry;
  const _DuesCard({
    required this.dues,
    required this.isLoading,
    required this.paying,
    required this.onPay,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final total = dues?.pendingTotal ?? 0;
    final limit = dues?.limit ?? 0;
    final blocked = dues?.codBlocked ?? false;
    final warn = blocked || (limit > 0 && total >= limit * 0.8);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warn ? AppTheme.errorColor.withValues(alpha: 0.3) : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TechTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_outlined, color: TechTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending dues (cash jobs)', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                    const SizedBox(height: 2),
                    isLoading && dues == null
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: TechTheme.primary),
                          )
                        : Text(
                            limit > 0
                                ? '₹${total.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}'
                                : '₹${total.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: warn ? AppTheme.errorColor : Colors.black87,
                            ),
                          ),
                  ],
                ),
              ),
              if (total > 0)
                ElevatedButton(
                  onPressed: paying ? null : onPay,
                  child: paying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Pay Dues'),
                ),
            ],
          ),
          if (dues == null && !isLoading) ...[
            const SizedBox(height: 8),
            Text(
              'Dues load nahi ho paye${error != null ? ': $error' : ''}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.errorColor),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
          if (blocked) ...[
            const SizedBox(height: 8),
            const Text(
              'Cash-on-Delivery jobs are paused — pay your dues to receive them again. Online jobs are not affected.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.errorColor),
            ),
          ] else if (total > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Commission on cash jobs. Clear it before it reaches ₹${limit.toStringAsFixed(0)}'
              '${(dues?.maxDays ?? 0) > 0 ? ' or ${dues!.maxDays} days' : ''} to keep getting cash jobs.',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
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
          colors: [TechTheme.primary, TechTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: TechTheme.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).techSettlementTotalEarned, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(
                  '₹${totalEarned.toStringAsFixed(2)}',
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
              Text(AppLocalizations.of(context).techSettlementJobsCompleted, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
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
    final customerName = booking.customer?.name ?? AppLocalizations.of(context).techSettlementCustomerFallback;
    final date = booking.updatedAt;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TechnicianJobDetailScreen(booking: booking)),
      ),
      child: Container(
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
        ],
      ),
    ),
    );
  }
}

class _PaymentTile extends StatefulWidget {
  final Payment payment;
  final DueItem? pendingDue; // unpaid commission for this (cash) payment
  final bool paying;
  final bool anyPaying;
  final VoidCallback? onPayCommission;
  const _PaymentTile({
    required this.payment,
    this.pendingDue,
    this.paying = false,
    this.anyPaying = false,
    this.onPayCommission,
  });

  @override
  State<_PaymentTile> createState() => _PaymentTileState();
}

class _PaymentTileState extends State<_PaymentTile> {
  Payment get payment => widget.payment;

  Color get _statusColor {
    if (payment.isPaid) return AppTheme.successColor;
    if (payment.isFailed) return AppTheme.errorColor;
    if (payment.isRefunded) return AppTheme.warningColor;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final date = payment.createdAt;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InvoiceScreen(paymentId: payment.id)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text('₹${payment.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(payment.isPaid ? 'paid' : (payment.isRefunded ? 'refunded' : 'unpaid'), style: TextStyle(fontSize: 10.5, color: _statusColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (payment.isPaid && !payment.isVisitFee && payment.technicianEarning != null)
                  Text(AppLocalizations.of(context).techSettlementYourShare(payment.technicianEarning!.toStringAsFixed(2)),
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
          if (widget.pendingDue != null && widget.onPayCommission != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.anyPaying ? null : widget.onPayCommission,
                icon: widget.paying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payments_outlined, size: 18),
                label: Text('Pay commission ₹${widget.pendingDue!.amount.toStringAsFixed(2)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TechTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}