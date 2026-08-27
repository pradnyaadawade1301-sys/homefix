import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/category_provider.dart' show TechnicianKycProvider;

/// Technician-facing Service History screen for a single (repeat) customer —
/// every past booking they've made with this technician, with pricing/tier
/// info (first-time vs repeat-customer discount) attached. Reached by tapping
/// a customer on the "My Customers" (repeat customers) screen. Backed by
/// GET /technicians/:id/customers/:customerId/history.
///
/// Named CustomerServiceHistoryScreen (not ServiceHistoryScreen) because
/// lib/screens/service_history_screen.dart already owns that name for the
/// customer's own "My Bookings history" — two different screens for two
/// different audiences that happened to get the same name in an earlier pass.
class CustomerServiceHistoryScreen extends StatefulWidget {
  final RepeatCustomer customer;
  const CustomerServiceHistoryScreen({Key? key, required this.customer}) : super(key: key);

  @override
  State<CustomerServiceHistoryScreen> createState() => _CustomerServiceHistoryScreenState();
}

class _CustomerServiceHistoryScreenState extends State<CustomerServiceHistoryScreen> {
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
      await context.read<BookingProvider>().fetchServiceHistory(technicianId, widget.customer.customerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name.isNotEmpty ? widget.customer.name : 'Service History'),
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingServiceHistory) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.serviceHistory.isEmpty) {
            return _ErrorState(message: provider.error!, onRetry: _load);
          }
          final entries = provider.serviceHistory;
          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No service history yet')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ServiceHistoryCard(entry: entries[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceHistoryCard extends StatelessWidget {
  final ServiceHistoryEntry entry;
  const _ServiceHistoryCard({required this.entry});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'in_progress':
        return AppTheme.warningColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = entry.booking;
    final payment = entry.payment;
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.categoryName.isNotEmpty ? booking.categoryName : 'Service',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(booking.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  booking.status.replaceAll('_', ' '),
                  style: TextStyle(color: _statusColor(booking.status), fontWeight: FontWeight.w600, fontSize: 11.5),
                ),
              ),
            ],
          ),
          if (booking.customer != null && booking.customer!.name.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline, size: 15, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking.customer!.name,
                    style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                dateFmt.format(booking.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
              ),
            ],
          ),
          if (booking.address != null && booking.address!.formatted.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking.address!.formatted,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
          if (booking.problemDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Issue: ${booking.problemDescription}',
              style: const TextStyle(fontSize: 13.5),
            ),
          ],
          const Divider(height: 24),
          if (payment != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\u20B9${payment.amount.toStringAsFixed(0)} paid',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (payment.isRepeatCustomer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      payment.repeatDiscountPercent != null
                          ? 'Repeat • ${payment.repeatDiscountPercent!.toStringAsFixed(0)}% off'
                          : 'Repeat customer',
                      style: const TextStyle(color: AppTheme.tertiaryColor, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'First-time',
                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ] else
            Text(
              booking.displayPrice != null
                  ? '\u20B9${booking.displayPrice!.toStringAsFixed(0)} (unpaid)'
                  : 'Not paid yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
            Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
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