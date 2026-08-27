import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../booking/booking_tracking_screen.dart';

/// Opened when the user taps a push-notification popup (foreground local
/// notification, background tap, or a terminated-state launch) so they land
/// on that exact notification's message instead of just the app's home
/// screen. Shows the title/body every push carries, plus a "View Booking"
/// shortcut when the notification's data payload includes a booking_id.
class NotificationDetailScreen extends StatelessWidget {
  final String title;
  final String body;
  final Map<String, dynamic>? data;

  const NotificationDetailScreen({
    Key? key,
    required this.title,
    required this.body,
    this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bookingId = data?['booking_id'] as String?;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_rounded, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(fontSize: 14.5, color: Colors.grey[800], height: 1.4),
            ),
            if (bookingId != null && bookingId.isNotEmpty) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BookingTrackingScreen(bookingId: bookingId),
                    ));
                  },
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('View Booking'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}