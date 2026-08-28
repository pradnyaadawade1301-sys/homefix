import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme.dart';
import '../../providers/payment_provider.dart';
import 'invoice_screen.dart';

/// Pay a completed booking's amount via Razorpay Checkout. The customer sees a
/// GST-inclusive invoice breakdown, taps "Pay Now", and Razorpay's own hosted
/// Checkout sheet opens (cards, UPI, netbanking, wallets — whatever's enabled
/// on the account). Checkout's own success response (razorpay_payment_id +
/// razorpay_signature) is what actually gets sent back to the backend to
/// verify the payment — not a manual "I've paid" button. The backend
/// independently re-verifies the signature server-side before ever marking
/// the booking paid.
class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final double amount;
  final String bookingTitle;

  const PaymentScreen({
    Key? key,
    required this.bookingId,
    required this.amount,
    this.bookingTitle = 'Service booking',
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _Stage { review, opening, verifying, success, notVerified }

class _PaymentScreenState extends State<PaymentScreen> {
  _Stage _stage = _Stage.review;
  String? _statusMessage;
  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PaymentProvider>().reset());
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  /// Step 1 — ask the backend to create a real Razorpay order (this is where
  /// GST + repeat-customer discount get calculated). Then immediately open
  /// Razorpay's Checkout sheet with that order_id.
  Future<void> _startPayment() async {
    final provider = context.read<PaymentProvider>();
    final ok = await provider.createOrder(widget.bookingId, widget.amount);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? 'Could not start payment')));
      return;
    }

    final order = provider.order!;
    setState(() => _stage = _Stage.opening);

    final options = {
      'key': order.razorpayKeyId,
      'amount': order.amountPaise,
      'currency': order.currency,
      'order_id': order.razorpayOrderId,
      'name': 'HomeFix Live',
      'description': widget.bookingTitle,
      'timeout': 300, // seconds before Checkout auto-closes
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.review);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open payment sheet: $e')));
    }
  }

  /// Razorpay Checkout's OWN success callback — payment_id + signature are
  /// exactly what get sent to the backend for independent re-verification.
  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _stage = _Stage.verifying);

    final provider = context.read<PaymentProvider>();
    final confirmed = await provider.confirmPayment(
      razorpayPaymentId: response.paymentId ?? '',
      razorpaySignature: response.signature ?? '',
    );

    if (!mounted) return;
    if (confirmed) {
      setState(() => _stage = _Stage.success);
      // Invoice is generated the moment the backend marks the payment paid —
      // take the customer straight to it rather than making "View Invoice" a
      // button they might miss.
      final paymentId = provider.confirmedPayment?.id;
      if (paymentId != null && paymentId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => InvoiceScreen(paymentId: paymentId)),
          );
        });
      }
    } else {
      setState(() {
        _stage = _Stage.notVerified;
        _statusMessage = provider.error ?? 'This payment could not be verified as successful.';
      });
    }
  }

  /// Checkout reported a failure (declined card, cancelled by user, etc). Razorpay
  /// itself never charged the customer in this case, so nothing needs reversing —
  /// just let the app know so it can offer a retry.
  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    context.read<PaymentProvider>().cancelPayment();
    setState(() {
      _stage = _Stage.notVerified;
      _statusMessage = response.message?.isNotEmpty == true
          ? response.message
          : 'Payment was not completed.';
    });
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${response.walletName ?? 'external wallet'}...')),
    );
  }

  void _retry() {
    setState(() => _stage = _Stage.review);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Consumer<PaymentProvider>(
            builder: (context, provider, _) {
              switch (_stage) {
                case _Stage.success:
                  return _buildSuccess(provider);
                case _Stage.notVerified:
                  return _buildNotVerified();
                case _Stage.verifying:
                  return _buildVerifying();
                case _Stage.opening:
                  return _buildOpening();
                case _Stage.review:
                  return _buildReview(provider);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReview(PaymentProvider provider) {
    return ListView(
      children: [
        const SizedBox(height: 12),
        _buildInvoiceCard(order: null),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: provider.isCreatingOrder ? null : _startPayment,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: provider.isCreatingOrder
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Pay Now'),
          ),
        ),
        if (provider.error != null) ...[
          const SizedBox(height: 12),
          Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 12.5), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  /// GST-inclusive invoice breakdown, with the repeat-customer discount line
  /// shown once the order comes back (before that we only know the base amount
  /// the caller passed in).
  Widget _buildInvoiceCard({required dynamic order}) {
    final payment = order?.payment;
    final baseAmount = payment?.baseAmount ?? widget.amount;
    final gstAmount = payment?.gstAmount;
    final gstPercent = payment?.gstPercent;
    final total = payment?.amount ?? widget.amount;
    final isRepeat = payment?.isRepeatCustomer == true;
    final discountPercent = payment?.repeatDiscountPercent;
    final discountAmount = payment?.repeatDiscountAmount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(widget.bookingTitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 16),
          _invoiceRow('Service amount', '\u20B9${baseAmount.toStringAsFixed(2)}'),
          if (isRepeat && discountAmount != null) ...[
            const SizedBox(height: 8),
            _invoiceRow(
              'Repeat customer discount${discountPercent != null ? ' (${discountPercent.toStringAsFixed(0)}%)' : ''}',
              '-\u20B9${discountAmount.toStringAsFixed(2)}',
              valueColor: AppTheme.successColor,
            ),
          ],
          const SizedBox(height: 8),
          _invoiceRow(
            gstPercent != null ? 'GST (${gstPercent.toStringAsFixed(0)}%)' : 'GST',
            gstAmount != null ? '\u20B9${gstAmount.toStringAsFixed(2)}' : '\u2014',
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total payable', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                '\u20B9${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13.5, color: Colors.grey[700])),
        Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  Widget _buildOpening() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 60),
        CircularProgressIndicator(color: AppTheme.primaryColor),
        SizedBox(height: 20),
        Text('Opening payment sheet\u2026', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildVerifying() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 60),
        CircularProgressIndicator(color: AppTheme.primaryColor),
        SizedBox(height: 20),
        Text('Verifying your payment\u2026', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildNotVerified() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.errorColor),
        const SizedBox(height: 20),
        const Text('Payment not completed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          _statusMessage ?? 'This payment was not confirmed.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Try Again'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(PaymentProvider provider) {
    final payment = provider.confirmedPayment;
    return Column(
      children: [
        const SizedBox(height: 40),
        const CircleAvatar(radius: 40, backgroundColor: Color(0xFFE8F8EE), child: Icon(Icons.check_rounded, color: AppTheme.successColor, size: 44)),
        const SizedBox(height: 20),
        const Text('Payment Successful', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('\u20B9${(payment?.amount ?? widget.amount).toStringAsFixed(2)} paid', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        if (payment?.invoiceNumber != null) ...[
          const SizedBox(height: 4),
          Text('Invoice ${payment!.invoiceNumber}', style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
        ],
        const SizedBox(height: 28),
        if (payment != null) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => InvoiceScreen(paymentId: payment.id)),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('View Invoice'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}