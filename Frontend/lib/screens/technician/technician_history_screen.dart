import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import 'technician_job_detail_screen.dart';

/// Technician's past-jobs list — every booking that's no longer active
/// (completed or cancelled), most recent first. Reached via the "History"
/// tab in [TechnicianJobsScreen]'s bottom nav.
///
/// Deliberately reuses [BookingProvider.bookings] (the same list the "Jobs"
/// tab reads from — see TechnicianJobsScreenState._load, which already keeps
/// it refreshed) rather than a separate fetch, since the technician's full
/// job list already includes historical jobs; this screen just filters to
/// the finished ones instead of hitting a new endpoint.
class TechnicianHistoryScreen extends StatelessWidget {
  const TechnicianHistoryScreen({Key? key}) : super(key: key);

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.bookings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = provider.bookings.where((b) => b.status == 'completed' || b.status == 'cancelled').toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (history.isEmpty) {
          return ListView(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.22),
              Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No past jobs yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Completed and cancelled jobs will show up here',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: history.length,
          itemBuilder: (context, i) => _HistoryCard(
            booking: history[i],
            statusColor: _statusColor(history[i].status),
            dateLabel: _formatDate(history[i].createdAt),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Booking booking;
  final Color statusColor;
  final String dateLabel;

  const _HistoryCard({required this.booking, required this.statusColor, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final customer = booking.customer;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TechnicianJobDetailScreen(booking: booking),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  booking.status == 'completed' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.categoryName.isNotEmpty ? booking.categoryName : 'Service request',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${customer?.name.isNotEmpty == true ? customer!.name : 'Customer'} • $dateLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (booking.displayPrice != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '\u20b9${booking.displayPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  booking.status[0].toUpperCase() + booking.status.substring(1),
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}