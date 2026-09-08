import 'package:flutter/material.dart';
import '../models/payment_model.dart';
import '../services/service_locator.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentService _paymentService;

  PaymentProvider({required PaymentService paymentService}) : _paymentService = paymentService;

  RazorpayOrderResponse? _order;
  Payment? _confirmedPayment;
  List<Payment> _history = [];
  InvoiceDetail? _invoice;
  bool _isCreatingOrder = false;
  bool _isConfirming = false;
  bool _isLoadingHistory = false;
  bool _isLoadingInvoice = false;
  String? _error;

  RazorpayOrderResponse? get order => _order;
  Payment? get confirmedPayment => _confirmedPayment;
  List<Payment> get history => _history;
  InvoiceDetail? get invoice => _invoice;
  bool get isCreatingOrder => _isCreatingOrder;
  bool get isConfirming => _isConfirming;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingInvoice => _isLoadingInvoice;
  String? get error => _error;

  /// Step 1 — ask the backend to create a real Razorpay order for this booking's
  /// amount. Returns everything PaymentScreen needs to open Razorpay Checkout
  /// (razorpay_order_id + the public key_id + amount in paise).
  Future<bool> createOrder(String bookingId, double amount) async {
    _isCreatingOrder = true;
    _error = null;
    _order = null;
    _confirmedPayment = null;
    notifyListeners();
    try {
      _order = await _paymentService.createOrder(bookingId, amount);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isCreatingOrder = false;
      notifyListeners();
    }
  }

  /// Step 2 — after Razorpay Checkout's success callback fires, its OWN response
  /// (razorpay_payment_id + razorpay_signature) is what gets sent here — never a
  /// client-invented "yes I paid". The backend independently re-verifies the
  /// signature server-side before ever marking the payment (and its booking) paid.
  Future<bool> confirmPayment({
    required String razorpayPaymentId,
    required String razorpaySignature,
    String method = 'razorpay',
  }) async {
    final orderId = _order?.razorpayOrderId;
    if (orderId == null || orderId.isEmpty) {
      _error = 'No active payment to confirm';
      notifyListeners();
      return false;
    }
    _isConfirming = true;
    _error = null;
    notifyListeners();
    try {
      _confirmedPayment = await _paymentService.confirm(
        orderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
        method: method,
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isConfirming = false;
      notifyListeners();
    }
  }

  /// If Checkout is dismissed, cancelled, or reports failure without the
  /// customer paying.
  Future<void> cancelPayment() async {
    final orderId = _order?.razorpayOrderId;
    if (orderId == null || orderId.isEmpty) return;
    try {
      await _paymentService.markFailed(orderId);
    } catch (_) {
      // best-effort — the payment just stays "created" if this fails, which is fine
    }
  }

  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    _error = null;
    notifyListeners();
    try {
      _history = await _paymentService.history();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  void reset() {
    _order = null;
    _confirmedPayment = null;
    _error = null;
    notifyListeners();
  }

  /// Recovery check for when the app process was killed mid-checkout (Razorpay
  /// Checkout runs as a separate external activity, so Android can reclaim the
  /// Flutter process while it's in the background) — the customer may have
  /// actually been charged even though this in-memory provider's `_order` is
  /// gone and Checkout's success callback never reached us. Called when
  /// PaymentScreen opens, before showing "Pay Now" again, so we don't charge
  /// the customer a second time for an already-paid booking.
  Future<bool> checkExistingPayment(String bookingId) async {
    try {
      final payments = await _paymentService.history();
      for (final p in payments) {
        if (p.bookingId == bookingId && p.isPaid) {
          _confirmedPayment = p;
          notifyListeners();
          return true;
        }
      }
    } catch (_) {
      // Best-effort — if this check fails (e.g. offline), fall through to the
      // normal review/pay flow rather than blocking the screen.
    }
    return false;
  }

  /// Loads the full GST invoice for a payment — call right after a successful
  /// confirmPayment() to drive the auto-shown Invoice screen, or later from
  /// Payment History to view/re-download a past invoice.
  Future<bool> loadInvoice(String paymentId) async {
    _isLoadingInvoice = true;
    _error = null;
    notifyListeners();
    try {
      _invoice = await _paymentService.getInvoice(paymentId);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoadingInvoice = false;
      notifyListeners();
    }
  }

  /// Technician-side equivalent of [loadInvoice] — looked up by booking
  /// since the technician never has a payment ID handy. See
  /// PaymentService.getInvoiceByBooking.
  Future<bool> loadInvoiceByBooking(String bookingId) async {
    _isLoadingInvoice = true;
    _error = null;
    notifyListeners();
    try {
      _invoice = await _paymentService.getInvoiceByBooking(bookingId);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoadingInvoice = false;
      notifyListeners();
    }
  }
}