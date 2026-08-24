import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/payment_provider.dart';
import '../../services/upi_channel_service.dart';

/// Pay a completed booking's amount via UPI. The customer enters their UPI ID,
/// then Android's standard UPI app chooser opens (whichever apps - GPay,
/// PhonePe, Paytm etc - are installed on the device), via UpiChannelService
/// (startActivityForResult through a platform channel we own - not a
/// fire-and-forget deep link). The chosen app's own response
/// (status/txnId/responseCode/approvalRefNo) is what actually gets sent back
/// to the backend to verify the payment - not a manual "I've paid" button.
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

enum _Stage { review, enterUpi, payingViaUpi, verifying, success, notVerified }

class _PaymentScreenState extends State<PaymentScreen> {
  _Stage _stage = _Stage.review;
  String? _statusMessage;
  final _upiIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PaymentProvider>().reset());
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    super.dispose();
  }

  void _goToEnterUpi() {
    setState(() => _stage = _Stage.enterUpi);
  }

  Future<void> _payNow() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<PaymentProvider>();
    final ok = await provider.createOrder(widget.bookingId, widget.amount);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? 'Could not start payment')));
      return;
    }

    final order = provider.order!;
    setState(() => _stage = _Stage.payingViaUpi);

    UpiChannelResponse response;
    try {
      response = await UpiChannelService().pay(
        payeeVpa: order.payeeVpa,
        payeeName: order.payeeName,
        transactionRef: order.transactionRef,
        note: 'HomeFix - ${widget.bookingTitle}',
        amount: widget.amount,
        appPackage: null, // null = let Android show the standard UPI app chooser
      );
    } on UpiChannelException catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.enterUpi);
      final message = e.code == 'app_not_installed'
          ? 'No UPI app was found on this device.'
          : (e.code == 'user_cancelled' ? null : 'Payment could not complete: ${e.message}');
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _stage = _Stage.verifying);

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

  Future<void> _retry() async {
    setState(() => _stage = _Stage.enterUpi);
  }

  /// TESTING ONLY — bypasses the real UPI app round-trip and pretends it
  /// returned SUCCESS, so you can carry on testing the rest of the booking
  /// flow (e.g. on an emulator, or while GPay/UPI isn't wired up yet).
  /// Gated behind kDebugMode so it never ships in a release build.
  /// The confirm call still goes to your real backend — it just fakes the
  /// UPI app's response instead of actually opening GPay.
  Future<void> _dummyPaySuccess() async {
    final provider = context.read<PaymentProvider>();

    // Make sure an order exists (in case this is tapped before a real
    // attempt was made and createOrder was never called).
    if (provider.order == null) {
      final ok = await provider.createOrder(widget.bookingId, widget.amount);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Could not start payment')),
        );
        return;
      }
    }

    setState(() => _stage = _Stage.verifying);

    final confirmed = await provider.confirmPayment(
      upiTxnId: 'DUMMY_TXN_${DateTime.now().millisecondsSinceEpoch}',
      upiStatus: UpiPaymentStatus.success,
      upiResponseCode: '00',
      upiApprovalRef: 'DUMMY_APPROVAL',
    );

    if (!mounted) return;
    if (confirmed) {
      setState(() => _stage = _Stage.success);
    } else {
      setState(() {
        _stage = _Stage.notVerified;
        _statusMessage = provider.error ?? 'Dummy confirm was rejected by the backend.';
      });
    }
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
                case _Stage.enterUpi:
                case _Stage.payingViaUpi:
                  return _buildEnterUpi(provider);
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
        _buildAmountCard(),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _goToEnterUpi,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Pay Now'),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountCard() {
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
          const SizedBox(height: 8),
          Text(
            '₹${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
          ),
          const SizedBox(height: 4),
          const Text('Amount to pay', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEnterUpi(PaymentProvider provider) {
    final busy = provider.isCreatingOrder || _stage == _Stage.payingViaUpi;
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          const SizedBox(height: 12),
          _buildAmountCard(),
          const SizedBox(height: 28),
          const Text('Enter your UPI ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _upiIdController,
            enabled: !busy,
            decoration: InputDecoration(
              hintText: 'yourname@bank',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Please enter your UPI ID';
              final upiPattern = RegExp(r'^[\w.\-]{2,256}@[a-zA-Z]{2,64}$');
              if (!upiPattern.hasMatch(v)) return 'Enter a valid UPI ID, e.g. name@bank';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: busy ? null : _payNow,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.account_balance_wallet_outlined),
              label: Text(
                provider.isCreatingOrder
                    ? 'Starting…'
                    : (_stage == _Stage.payingViaUpi ? 'Opening your UPI app…' : 'Pay Now'),
              ),
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
                onPressed: busy ? null : _dummyPaySuccess,
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('Simulate Success (Testing)'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
              ),
            ),
          ],
        ],
      ),
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
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _dummyPaySuccess,
              icon: const Icon(Icons.bug_report_outlined, size: 18),
              label: const Text('Simulate Success (Testing)'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
            ),
          ),
        ],
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
        Text('₹${widget.amount.toStringAsFixed(2)} paid', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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