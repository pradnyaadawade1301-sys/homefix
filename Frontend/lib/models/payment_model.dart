/// Returned by POST /payments/orders — everything the app needs to open
/// Razorpay's Checkout sheet for this order.
class RazorpayOrderResponse {
  final Payment payment;
  final String razorpayOrderId;
  final String razorpayKeyId;
  final int amountPaise;
  final String currency;

  RazorpayOrderResponse({
    required this.payment,
    required this.razorpayOrderId,
    required this.razorpayKeyId,
    required this.amountPaise,
    required this.currency,
  });

  factory RazorpayOrderResponse.fromJson(Map<String, dynamic> json) {
    return RazorpayOrderResponse(
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      razorpayOrderId: (json['razorpay_order_id'] as String?) ?? '',
      razorpayKeyId: (json['razorpay_key_id'] as String?) ?? '',
      amountPaise: (json['amount_paise'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?) ?? 'INR',
    );
  }
}

/// Matches backend `models.Payment` (created / paid / failed).
class Payment {
  final String id;
  final String bookingId;
  final String userId;
  final String transactionRef;
  final String? invoiceNumber;
  final double amount;
  final double? baseAmount;
  final double? gstAmount;
  final double? gstPercent;
  final String currency;
  final String? method;
  final String status; // created | paid | failed | refunded
  final bool verified; // true only once the Razorpay signature was independently re-verified server-side
  final bool isRepeatCustomer;
  final double? repeatDiscountPercent;
  final double? repeatDiscountAmount;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final double? platformCommission;
  final double? technicianEarning;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.transactionRef,
    this.invoiceNumber,
    required this.amount,
    this.baseAmount,
    this.gstAmount,
    this.gstPercent,
    required this.currency,
    this.method,
    required this.status,
    this.verified = false,
    this.isRepeatCustomer = false,
    this.repeatDiscountPercent,
    this.repeatDiscountAmount,
    this.razorpayOrderId,
    this.razorpayPaymentId,
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
      invoiceNumber: json['invoice_number'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      baseAmount: (json['base_amount'] as num?)?.toDouble(),
      gstAmount: (json['gst_amount'] as num?)?.toDouble(),
      gstPercent: (json['gst_percent'] as num?)?.toDouble(),
      currency: (json['currency'] as String?) ?? 'INR',
      method: json['method'] as String?,
      status: (json['status'] as String?) ?? 'created',
      verified: json['verified'] as bool? ?? false,
      isRepeatCustomer: json['is_repeat_customer'] as bool? ?? false,
      repeatDiscountPercent: (json['repeat_discount_percent'] as num?)?.toDouble(),
      repeatDiscountAmount: (json['repeat_discount_amount'] as num?)?.toDouble(),
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      platformCommission: (json['platform_commission'] as num?)?.toDouble(),
      technicianEarning: (json['technician_earning'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }
}

/// Matches backend `models.InvoiceDetail` — the full GST-compliant invoice
/// for one paid booking, everything the invoice screen/PDF needs in one
/// response. Returned by GET /payments/:id/invoice, only once a payment has
/// actually gone through.
class InvoiceDetail {
  final Payment payment;
  final String invoiceNumber;
  final String serviceCode;
  final String bookingId;
  final String categoryName;
  final String problemDescription;
  final String customerName;
  final String customerPhone;
  final String technicianName;
  final String technicianPhone;
  final String addressFormatted;
  final DateTime paidAt;
  final double baseAmount;
  final double cgstPercent;
  final double cgstAmount;
  final double sgstPercent;
  final double sgstAmount;
  final double totalAmount;
  final bool isRepeatCustomer;
  final double? repeatDiscountPercent;
  final double? repeatDiscountAmount;

  InvoiceDetail({
    required this.payment,
    required this.invoiceNumber,
    required this.serviceCode,
    required this.bookingId,
    required this.categoryName,
    this.problemDescription = '',
    required this.customerName,
    required this.customerPhone,
    this.technicianName = '',
    this.technicianPhone = '',
    this.addressFormatted = '',
    required this.paidAt,
    required this.baseAmount,
    required this.cgstPercent,
    required this.cgstAmount,
    required this.sgstPercent,
    required this.sgstAmount,
    required this.totalAmount,
    this.isRepeatCustomer = false,
    this.repeatDiscountPercent,
    this.repeatDiscountAmount,
  });

  double get gstTotal => cgstAmount + sgstAmount;

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    return InvoiceDetail(
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      invoiceNumber: (json['invoice_number'] as String?) ?? '',
      serviceCode: (json['service_code'] as String?) ?? '',
      bookingId: (json['booking_id'] as String?) ?? '',
      categoryName: (json['category_name'] as String?) ?? '',
      problemDescription: (json['problem_description'] as String?) ?? '',
      customerName: (json['customer_name'] as String?) ?? '',
      customerPhone: (json['customer_phone'] as String?) ?? '',
      technicianName: (json['technician_name'] as String?) ?? '',
      technicianPhone: (json['technician_phone'] as String?) ?? '',
      addressFormatted: (json['address_formatted'] as String?) ?? '',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : DateTime.now(),
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0.0,
      cgstPercent: (json['cgst_percent'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (json['cgst_amount'] as num?)?.toDouble() ?? 0.0,
      sgstPercent: (json['sgst_percent'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgst_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      isRepeatCustomer: json['is_repeat_customer'] as bool? ?? false,
      repeatDiscountPercent: (json['repeat_discount_percent'] as num?)?.toDouble(),
      repeatDiscountAmount: (json['repeat_discount_amount'] as num?)?.toDouble(),
    );
  }
}