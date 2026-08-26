/// Returned by POST /payments/orders — everything the app needs to launch the
/// UPI intent (GPay/PhonePe/Paytm all register as handlers for `upi://pay`).
class UpiOrder {
  final Payment payment;
  final String upiUri;
  final String payeeVpa;
  final String payeeName;
  final String transactionRef;

  UpiOrder({
    required this.payment,
    required this.upiUri,
    required this.payeeVpa,
    required this.payeeName,
    required this.transactionRef,
  });

  factory UpiOrder.fromJson(Map<String, dynamic> json) {
    return UpiOrder(
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      upiUri: (json['upi_uri'] as String?) ?? '',
      payeeVpa: (json['payee_vpa'] as String?) ?? '',
      payeeName: (json['payee_name'] as String?) ?? '',
      transactionRef: (json['transaction_ref'] as String?) ?? '',
    );
  }
}

/// Matches backend `models.Payment` (created / paid / failed).
class Payment {
  final String id;
  final String bookingId;
  final String userId;
  final String transactionRef;
  final String? upiTxnId;
  final String? invoiceNumber;
  final double amount;
  final double? baseAmount;
  final double? gstAmount;
  final double? gstPercent;
  final String currency;
  final String? method;
  final String status; // created | paid | failed | refunded
  final bool verified; // true only once the UPI app itself reported SUCCESS
  final double? platformCommission;
  final double? technicianEarning;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.transactionRef,
    this.upiTxnId,
    this.invoiceNumber,
    required this.amount,
    this.baseAmount,
    this.gstAmount,
    this.gstPercent,
    required this.currency,
    this.method,
    required this.status,
    this.verified = false,
    this.platformCommission,
    this.technicianEarning,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
  bool get isRefunded => status == 'refunded';

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: (json['id'] as String?) ?? '',
      bookingId: (json['booking_id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      transactionRef: (json['transaction_ref'] as String?) ?? '',
      upiTxnId: json['upi_txn_id'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      baseAmount: (json['base_amount'] as num?)?.toDouble(),
      gstAmount: (json['gst_amount'] as num?)?.toDouble(),
      gstPercent: (json['gst_percent'] as num?)?.toDouble(),
      currency: (json['currency'] as String?) ?? 'INR',
      method: json['method'] as String?,
      status: (json['status'] as String?) ?? 'created',
      verified: json['verified'] as bool? ?? false,
      platformCommission: (json['platform_commission'] as num?)?.toDouble(),
      technicianEarning: (json['technician_earning'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }
}