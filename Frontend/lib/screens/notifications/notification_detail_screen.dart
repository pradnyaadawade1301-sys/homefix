import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../booking/booking_tracking_screen.dart';
import '../technician/technician_job_detail_screen.dart';
import '../consultation/post_call_screen.dart';

/// Opened when the user taps a push-notification popup (foreground local
/// notification, background tap, or a terminated-state launch) so they land
/// on that exact notification's message instead of just the app's home
/// screen. Shows the title/body every push carries, plus a shortcut button
/// when the notification's data payload includes a `booking_id` or a
/// `consultation_id` (e.g. "Technician's recommendation is ready" — see
/// ConsultationService.RecommendOnsite on the backend, which sends
/// type: "consultation_recommendation" with the consultation_id).
class NotificationDetailScreen extends StatefulWidget {
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? createdAt;

  const NotificationDetailScreen({
    Key? key,
    required this.title,
    required this.body,
    this.data,
    this.createdAt,
  }) : super(key: key);

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _openingBooking = false;

  /// "View Booking" used to always push the CUSTOMER-facing
  /// BookingTrackingScreen, regardless of who was actually logged in. A
  /// technician tapping "New booking request" landed on the customer's own
  /// tracking view (call/chat-the-technician buttons and all) instead of
  /// their job screen. Route by role instead, and — since the technician
  /// screen needs a full Booking object, not just an id — fetch it first.
  Future<void> _openBooking(String bookingId) async {
    final role = context.read<AuthProvider>().currentUser?.role;
    if (role == 'technician') {
      setState(() => _openingBooking = true);
      try {
        final provider = context.read<BookingProvider>();
        await provider.fetchBookingDetail(bookingId);
        if (!mounted) return;
        final booking = provider.selectedBooking;
        if (booking == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load this job')),
          );
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TechnicianJobDetailScreen(booking: booking),
        ));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load this job: $e')),
        );
      } finally {
        if (mounted) setState(() => _openingBooking = false);
      }
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookingTrackingScreen(bookingId: bookingId),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingId = widget.data?['booking_id'] as String?;
    final consultationId = widget.data?['consultation_id'] as String?;
    final type = widget.data?['type'] as String?;

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
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              widget.body,
              style: TextStyle(fontSize: 14.5, color: Colors.grey[800], height: 1.4),
            ),
            if (widget.createdAt != null && widget.createdAt!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final dt = DateTime.tryParse(widget.createdAt!)?.toLocal();
                if (dt == null) return const SizedBox.shrink();
                return Text(
                  DateFormat('d MMM yyyy, h:mm a').format(dt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                );
              }),
            ],
            if (bookingId != null && bookingId.isNotEmpty) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openingBooking ? null : () => _openBooking(bookingId),
                  icon: _openingBooking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.local_shipping_outlined, size: 18),
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