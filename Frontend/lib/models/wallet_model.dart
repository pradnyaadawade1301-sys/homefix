/// Matches backend `models.Wallet` (GET /wallet).
class Wallet {
  final String id;
  final String userId;
  final double balance;
  final DateTime updatedAt;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Matches backend `models.WalletTransaction` (GET /wallet/transactions).
class WalletTransaction {
  final String id;
  final String walletId;
  final String type; // "credit" | "debit"
  final double amount;
  final String? reason;
  final String? referenceId;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    this.reason,
    this.referenceId,
    required this.createdAt,
  });

  bool get isCredit => type == 'credit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: (json['id'] as String?) ?? '',
      walletId: (json['wallet_id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'credit',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}