import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shows past transactions (payments, refunds, wallet top-ups).
/// UI-only for now with sample data — wire this to your transactions/
/// wallet API once ready.
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  // TODO: Replace with real data from your transactions provider/API.
  static final List<_Txn> _sample = [
    _Txn(title: 'AC Repair & Service', date: '18 Aug 2026, 4:12 PM', amount: -899, type: _TxnType.payment),
    _Txn(title: 'Refund — Cancelled Booking', date: '27 Jul 2026, 11:03 AM', amount: 349, type: _TxnType.refund),
    _Txn(title: 'Plumbing — Tap Leakage', date: '02 Aug 2026, 6:45 PM', amount: -349, type: _TxnType.payment),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Transaction History')),
      body: _sample.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No transactions yet', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _sample.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final txn = _sample[index];
                final isCredit = txn.amount > 0;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.lightOutline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isCredit ? AppTheme.successColor : AppTheme.primaryColor).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCredit ? Icons.call_received_rounded : Icons.call_made_rounded,
                          color: isCredit ? AppTheme.successColor : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(txn.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                            const SizedBox(height: 3),
                            Text(txn.date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Text(
                        '${isCredit ? '+' : '-'}₹${txn.amount.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isCredit ? AppTheme.successColor : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

enum _TxnType { payment, refund }

class _Txn {
  final String title;
  final String date;
  final double amount;
  final _TxnType type;

  const _Txn({required this.title, required this.date, required this.amount, required this.type});
}