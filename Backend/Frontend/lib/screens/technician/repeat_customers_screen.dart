import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/contact_actions.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/category_provider.dart' show TechnicianKycProvider;
import 'customer_service_history_screen.dart';

/// Technician-facing "My Customers" screen — lists customers who have booked
/// this technician more than once, most-frequent first. Backed by
/// GET /technicians/:id/repeat-customers (see booking_service.dart ->
/// getRepeatCustomers, booking_provider.dart -> fetchRepeatCustomers).
class RepeatCustomersScreen extends StatefulWidget {
  const RepeatCustomersScreen({Key? key}) : super(key: key);

  @override
  State<RepeatCustomersScreen> createState() => _RepeatCustomersScreenState();
}

class _RepeatCustomersScreenState extends State<RepeatCustomersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final kyc = context.read<TechnicianKycProvider>();
    if (kyc.profile == null) {
      await kyc.loadMyProfile();
    }
    final technicianId = kyc.profile?.id;
    if (technicianId != null && mounted) {
      await context.read<BookingProvider>().fetchRepeatCustomers(technicianId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repeat Customers')),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingRepeatCustomers) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.repeatCustomers.isEmpty) {
            return _ErrorState(message: provider.error!, onRetry: _load);
          }
          final customers = provider.repeatCustomers;
          if (customers.isEmpty) {
            return _EmptyState(onRefresh: _load);
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _RepeatCustomerCard(
                customer: customers[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerServiceHistoryScreen(customer: customers[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RepeatCustomerCard extends StatelessWidget {
  final RepeatCustomer customer;
  final VoidCallback onTap;
  const _RepeatCustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightOutline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name.isNotEmpty ? customer.name : 'Customer',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last booked: ${dateFmt.format(customer.lastBookingAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${customer.totalBookings} bookings',
                  style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              if (customer.phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.call_outlined, size: 20, color: AppTheme.primaryColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => callContact(context, customer.phone),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No repeat customers yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Customers who book you more than once will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}