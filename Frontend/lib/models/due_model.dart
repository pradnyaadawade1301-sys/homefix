/// Matches backend `models.DueSummary` (GET /technician/dues).
class DueItem {
  final String id;
  final String? bookingId;
  final double amount;
  final String status; // "pending" | "paid"
  final DateTime createdAt;
  final DateTime? paidAt;

  DueItem({
    required this.id,
    this.bookingId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  bool get isPending => status == 'pending';

  factory DueItem.fromJson(Map<String, dynamic> json) => DueItem(
        id: (json['id'] as String?) ?? '',
        bookingId: json['booking_id'] as String?,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        status: (json['status'] as String?) ?? 'pending',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
        paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      );
}

class DueSummary {
  final double pendingTotal;
  final double limit;
  final int maxDays;
  final bool codBlocked;
  final String blockedReason;
  final DateTime? oldestDueAt;
  final List<DueItem> dues;

  DueSummary({
    required this.pendingTotal,
    required this.limit,
    required this.maxDays,
    required this.codBlocked,
    required this.blockedReason,
    this.oldestDueAt,
    required this.dues,
  });

  factory DueSummary.fromJson(Map<String, dynamic> json) => DueSummary(
        pendingTotal: (json['pending_total'] as num?)?.toDouble() ?? 0,
        limit: (json['limit'] as num?)?.toDouble() ?? 0,
        maxDays: (json['max_days'] as num?)?.toInt() ?? 0,
        codBlocked: (json['cod_blocked'] as bool?) ?? false,
        blockedReason: (json['blocked_reason'] as String?) ?? '',
        oldestDueAt: json['oldest_due_at'] != null ? DateTime.tryParse(json['oldest_due_at'] as String) : null,
        dues: ((json['dues'] as List?) ?? [])
            .map((e) => DueItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Matches backend `service.DueOrder` (POST /technician/dues/pay).
class DueOrder {
  final String razorpayOrderId;
  final String razorpayKeyId;
  final int amountPaise;
  final double amount;
  final String currency;

  DueOrder({
    required this.razorpayOrderId,
    required this.razorpayKeyId,
    required this.amountPaise,
    required this.amount,
    required this.currency,
  });

  factory DueOrder.fromJson(Map<String, dynamic> json) => DueOrder(
        razorpayOrderId: json['razorpay_order_id'] as String,
        razorpayKeyId: json['razorpay_key_id'] as String,
        amountPaise: (json['amount_paise'] as num).toInt(),
        amount: (json['amount'] as num).toDouble(),
        currency: (json['currency'] as String?) ?? 'INR',
      );
}