import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/payment_provider.dart';

/// Shows the payment methods actually used via Razorpay, pulled from real
/// payment history (`PaymentProvider.loadHistory`) — not a locally faked
/// "add UPI/card" list. Razorpay Checkout itself decides what methods are
/// offered at payment time (UPI, cards, netbanking, wallets); this screen
/// just surfaces what was actually used before, most recent first.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadHistory();
    });
  }

  IconData _iconFor(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return Icons.account_balance_wallet_outlined;
      case 'card':
      case 'credit_card':
      case 'debit_card':
        return Icons.credit_card_rounded;
      case 'netbanking':
        return Icons.account_balance_outlined;
      case 'wallet':
        return Icons.wallet_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  String _labelFor(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'card':
      case 'credit_card':
        return 'Credit Card';
      case 'debit_card':
        return 'Debit Card';
      case 'netbanking':
        return 'Netbanking';
      case 'wallet':
        return 'Wallet';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Payment Methods')),
      body: Consumer<PaymentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingHistory) {
            return const Center(child: CircularProgressIndicator());
          }

          // Only successfully paid transactions, deduped by method, most
          // recent first — this is what was actually charged via Razorpay.
          final paid = provider.history.where((p) => p.status == 'paid').toList()
            ..sort((a, b) => b.id.compareTo(a.id));
          final seen = <String>{};
          final methods = <String>[];
          for (final p in paid) {
            final m = (p.method ?? '').trim();
            if (m.isEmpty || seen.contains(m.toLowerCase())) continue;
            seen.add(m.toLowerCase());
            methods.add(m);
          }

          return RefreshIndicator(
            onRefresh: () => context.read<PaymentProvider>().loadHistory(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (methods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.payment_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No payments made yet',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  )
                else
                  ...methods.asMap().entries.map((entry) {
                    final index = entry.key;
                    final method = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconFor(method), color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_labelFor(method),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                if (index == 0) ...[
                                  const SizedBox(height: 3),
                                  const Text('Last used',
                                      style: TextStyle(
                                          color: AppTheme.successColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These are the methods you\'ve actually paid with via Razorpay. '
                        'At checkout you can pick any method Razorpay supports — '
                        'cards, UPI, netbanking, or wallets.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}