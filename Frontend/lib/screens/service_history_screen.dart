import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shows the customer's past service bookings (completed / cancelled).
/// UI-only for now with sample data — wire this to your bookings
/// provider/API and filter by status ('completed' / 'cancelled') once ready.
class ServiceHistoryScreen extends StatelessWidget {
  const ServiceHistoryScreen({Key? key}) : super(key: key);

  // TODO: Replace with real data from your bookings provider/API,
  // filtered to closed-out statuses (completed / cancelled).
  static final List<_HistoryItem> _sampleHistory = [
    _HistoryItem(
      title: 'AC Repair & Service',
      date: '18 Aug 2026',
      amount: 899,
      completed: true,
    ),
    _HistoryItem(
      title: 'Plumbing — Tap Leakage',
      date: '02 Aug 2026',
      amount: 349,
      completed: true,
    ),
    _HistoryItem(
      title: 'Electrical Wiring Check',
      date: '27 Jul 2026',
      amount: 0,
      completed: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Service History')),
      body: _sampleHistory.isEmpty
          ? const _EmptyState(
              icon: Icons.history_rounded,
              title: 'No service history yet',
              subtitle: 'Completed and cancelled bookings will show up here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _sampleHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _HistoryCard(item: _sampleHistory[index]),
            ),
    );
  }
}

class _HistoryItem {
  final String title;
  final String date;
  final double amount;
  final bool completed;

  const _HistoryItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.completed,
  });
}

class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;

  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
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
              color: (item.completed ? AppTheme.successColor : AppTheme.errorColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.completed ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
              color: item.completed ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(item.date, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.completed)
                Text('₹${item.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 3),
              Text(
                item.completed ? 'Completed' : 'Cancelled',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: item.completed ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}