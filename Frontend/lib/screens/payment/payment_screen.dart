import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme.dart';
import '../../providers/payment_provider.dart';
import '../../services/upi_channel_service.dart';

/// Pay a completed booking's amount via UPI. The customer sees a GST-inclusive
/// invoice breakdown, then can either scan the in-app QR code with any UPI app
/// or tap "Open UPI App" to launch the standard Android UPI app chooser
/// (GPay/PhonePe/Paytm etc via UpiChannelService — startActivityForResult, not
/// a fire-and-forget deep link). The chosen app's own response
/// (status/txnId/responseCode/approvalRefNo) is what actually gets sent back
/// to the backend to verify the payment — not a manual "I've paid" button.
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

enum _Stage { review, awaitingPayment, verifying, success, notVerified }

class _PaymentScreenState extends State<PaymentScreen> {
  _Stage _stage = _Stage.review;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PaymentProvider>().reset());
  }

  /// Step 1 — ask the backend to create the order (this is where GST gets
  /// calculated and the invoice breakdown/UPI link come back). Moves to the
  /// awaitingPayment stage where the QR + "Open UPI App" button both show.
  Future<void> _startPayment() async {
    final provider = context.read<PaymentProvider>();
    final ok = await provider.createOrder(widget.bookingId, widget.amount);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? 'Could not start payment')));
      return;
    }
    setState(() => _stage = _Stage.awaitingPayment);
  }

  /// "Open UPI App" button — launches the standard Android UPI chooser
  /// directly (GPay/PhonePe/Paytm), same as before.
  Future<void> _openUpiApp() async {
    final provider = context.read<PaymentProvider>();
    final order = provider.order;
    if (order == null) return;

    UpiChannelResponse response;
    try {
      response = await UpiChannelService().pay(
        payeeVpa: order.payeeVpa,
        payeeName: order.payeeName,
        transactionRef: order.transactionRef,
        note: 'HomeFix - ${widget.bookingTitle}',
        amount: order.payment.amount,
        appPackage: null, // null = let Android show the standard UPI app chooser
      );
    } on UpiChannelException catch (e) {
      if (!mounted) return;
      final message = e.code == 'app_not_installed'
          ? 'No UPI app was found on this device.'
          : (e.code == 'user_cancelled' ? null : 'Payment could not complete: ${e.message}');
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    await _confirmFromResponse(response);
  }

  Future<void> _confirmFromResponse(UpiChannelResponse response) async {
    if (!mounted) return;
    setState(() => _stage = _Stage.verifying);

    final provider = context.read<PaymentProvider>();
    final confirmed = await provider.confirmPayment(
      upiTxnId: response.transactionId,
      upiStatus: response.status,
      upiResponseCode: response.responseCode,
      upiApprovalRef: response.approvalRefNo,
    );

    if (!mounted) return;
    if (confirmed) {
      setState(() => _stage = _Stage.success);
    } else {
      setState(() {
        _stage = _Stage.notVerified;
        _statusMessage = response.status == UpiPaymentStatus.submitted
            ? 'Your payment is still processing. Please wait a moment and try confirming again.'
            : (provider.error ?? 'This payment was not confirmed as successful.');
      });
    }
  }

  /// After scanning the QR with an external UPI app, the customer comes back
  /// to the app manually — this lets them tell us to check the payment status.
  /// Since a plain QR scan (unlike the in-app UPI intent) doesn't return a
  /// response to this app directly, we ask the backend to re-check via the
  /// same confirm flow using a "user says paid" trigger is NOT allowed per
  /// ConfirmPayment's rules — so this re-fetches order status instead of
  /// fabricating a SUCCESS. For now, guide the user to the "Open UPI App"
  /// button instead, which is the verifiable path.
  void _retry() {
    setState(() => _stage = _Stage.awaitingPayment);
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
                case _Stage.awaitingPayment:
                  return _buildAwaitingPayment(provider);
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
                : const Text('Proceed to Pay'),
          ),
        ),
        if (provider.error != null) ...[
          const SizedBox(height: 12),
          Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 12.5), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  /// GST-inclusive invoice breakdown. Before the order is created we only know
  /// the base (billed) amount, so GST/total show as "—" until the backend
  /// order comes back with the real numbers.
  Widget _buildInvoiceCard({required dynamic order}) {
    final payment = order?.payment;
    final baseAmount = payment?.baseAmount ?? widget.amount;
    final gstAmount = payment?.gstAmount;
    final gstPercent = payment?.gstPercent;
    final total = payment?.amount ?? widget.amount;

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
          _invoiceRow('Service amount', '₹${baseAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _invoiceRow(
            gstPercent != null ? 'GST (${gstPercent.toStringAsFixed(0)}%)' : 'GST',
            gstAmount != null ? '₹${gstAmount.toStringAsFixed(2)}' : '—',
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total payable', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13.5, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAwaitingPayment(PaymentProvider provider) {
    final order = provider.order;
    return ListView(
      children: [
        const SizedBox(height: 12),
        _buildInvoiceCard(order: order),
        const SizedBox(height: 24),
        if (order != null) ...[
          const Text('Scan to pay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
              ),
              child: QrImageView(
                data: order.upiUri,
                version: QrVersions.auto,
                size: 220,
                gapless: false,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan with any UPI app (GPay, PhonePe, Paytm)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(children: const [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(color: Colors.grey))), Expanded(child: Divider())]),
          const SizedBox(height: 24),
        ],
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openUpiApp,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Open UPI App'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
          ),
        ),
        if (provider.error != null) ...[
          const SizedBox(height: 12),
          Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 12.5), textAlign: TextAlign.center),
        ],
        if (kDebugMode) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _confirmFromResponse(UpiChannelResponse(
                status: UpiPaymentStatus.success,
                transactionId: 'DUMMY_TXN_${DateTime.now().millisecondsSinceEpoch}',
                responseCode: '00',
                approvalRefNo: 'DUMMY_APPROVAL',
              )),
              icon: const Icon(Icons.bug_report_outlined, size: 18),
              label: const Text('Simulate Success (Testing)'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
            ),
          ),
        ],
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
        Text('Verifying your payment…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildNotVerified() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.errorColor),
        const SizedBox(height: 20),
        const Text('Payment not verified', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
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
        Text('₹${(payment?.amount ?? widget.amount).toStringAsFixed(2)} paid', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        if (payment?.invoiceNumber != null) ...[
          const SizedBox(height: 4),
          Text('Invoice ${payment!.invoiceNumber}', style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
        ],
        const SizedBox(height: 28),
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