import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/payment_provider.dart';
import '../../models/payment_model.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadHistory();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.successColor;
      case 'failed':
        return AppTheme.errorColor;
      case 'refunded':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'created':
        return 'Pending';
      case 'paid':
        return 'Paid';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: RefreshIndicator(
        onRefresh: () => context.read<PaymentProvider>().loadHistory(),
        child: Consumer<PaymentProvider>(
          builder: (context, provider, _) {
            if (provider.isLoadingHistory && provider.history.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null && provider.history.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        provider.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => context.read<PaymentProvider>().loadHistory(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              );
            }
            if (provider.history.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: provider.history.length,
              itemBuilder: (context, i) {
                final p = provider.history[i];
                return _TransactionCard(payment: p, statusColor: _statusColor(p.status), statusLabel: _statusLabel(p.status));
              },
            );
          },
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Payment payment;
  final Color statusColor;
  final String statusLabel;
  const _TransactionCard({required this.payment, required this.statusColor, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${payment.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (payment.method != null)
            Text(
              'Method: ${payment.method!.toUpperCase()}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
          if (payment.invoiceNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              'Invoice: ${payment.invoiceNumber}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}