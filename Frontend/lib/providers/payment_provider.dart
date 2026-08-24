import 'package:flutter/material.dart';
import '../models/payment_model.dart';
import '../services/service_locator.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentService _paymentService;

  PaymentProvider({required PaymentService paymentService}) : _paymentService = paymentService;

  UpiOrder? _order;
  Payment? _confirmedPayment;
  List<Payment> _history = [];
  bool _isCreatingOrder = false;
  bool _isConfirming = false;
  bool _isLoadingHistory = false;
  String? _error;

  UpiOrder? get order => _order;
  Payment? get confirmedPayment => _confirmedPayment;
  List<Payment> get history => _history;
  bool get isCreatingOrder => _isCreatingOrder;
  bool get isConfirming => _isConfirming;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;

  /// Step 1 — ask the backend for a upi://pay deep link for this booking's amount.
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

  /// Step 2 — after GPay (via upi_india's startTransaction) returns control to the
  /// app, its OWN response (status/txnId/responseCode/approvalRefNo) is what gets
  /// sent here — never a client-invented "yes I paid". The backend only marks the
  /// payment (and its booking) paid when upiStatus is a real SUCCESS.
  Future<bool> confirmPayment({
    String? upiTxnId,
    required String upiStatus,
    String? upiResponseCode,
    String? upiApprovalRef,
    String method = 'upi',
  }) async {
    final ref = _order?.transactionRef;
    if (ref == null) {
      _error = 'No active payment to confirm';
      notifyListeners();
      return false;
    }
    _isConfirming = true;
    _error = null;
    notifyListeners();
    try {
      _confirmedPayment = await _paymentService.confirm(
        ref,
        upiTxnId: upiTxnId,
        upiStatus: upiStatus,
        upiResponseCode: upiResponseCode,
        upiApprovalRef: upiApprovalRef,
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

  /// If the customer backs out of their UPI app without paying.
  Future<void> cancelPayment() async {
    final ref = _order?.transactionRef;
    if (ref == null) return;
    try {
      await _paymentService.markFailed(ref);
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
}