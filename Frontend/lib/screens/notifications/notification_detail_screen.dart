import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../booking/booking_tracking_screen.dart';
import '../consultation/post_call_screen.dart';

/// Opened when the user taps a push-notification popup (foreground local
/// notification, background tap, or a terminated-state launch) so they land
/// on that exact notification's message instead of just the app's home
/// screen. Shows the title/body every push carries, plus a shortcut button
/// when the notification's data payload includes a `booking_id` or a
/// `consultation_id` (e.g. "Technician's recommendation is ready" — see
/// ConsultationService.RecommendOnsite on the backend, which sends
/// type: "consultation_recommendation" with the consultation_id).
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
    final consultationId = data?['consultation_id'] as String?;
    final type = data?['type'] as String?;

    // Different label depending on what the consultation notification was
    // actually about, so the button reads naturally either way.
    final isRecommendation = type == 'consultation_recommendation';
    final consultationButtonLabel = isRecommendation ? 'View Recommendation' : 'View Consultation';
    final consultationButtonIcon = isRecommendation ? Icons.assignment_turned_in_outlined : Icons.videocam_outlined;

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
              child: Icon(
                isRecommendation ? Icons.assignment_turned_in_outlined : Icons.notifications_rounded,
                color: AppTheme.primaryColor,
              ),
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
            if (consultationId != null && consultationId.isNotEmpty) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      // categoryId/categoryName are only used for the very
                      // first frame's title before PostCallScreen's own
                      // refreshStatus() call fetches the real consultation
                      // (including its actual category) — from a
                      // notification tap we only have the id, so these start
                      // blank and get replaced the moment that fetch lands.
                      builder: (_) => PostCallScreen(
                        consultationId: consultationId,
                        categoryId: '',
                        categoryName: '',
                      ),
                    ));
                  },
                  icon: Icon(consultationButtonIcon, size: 18),
                  label: Text(consultationButtonLabel),
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