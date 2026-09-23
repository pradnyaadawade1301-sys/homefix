import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../screens/booking/booking_tracking_screen.dart';
import '../screens/technician/technician_job_detail_screen.dart';
import '../screens/chat/booking_chat_screen.dart';
import '../screens/payment/invoice_screen.dart';
import '../screens/consultation/post_call_screen.dart';
import '../screens/notifications/notification_detail_screen.dart';

/// Types that mean "something changed on this booking" — see
/// BookingService/RazorpayService on the backend for where each is sent.
/// All of them carry a booking_id and land the user on that booking's own
/// screen (tracking for a customer, the job detail for a technician).
const _bookingStatusTypes = {
  'booking_status',
  'booking_accepted',
  'booking_assigned',
  'booking_rejected',
  'booking_estimate',
  'warranty_claim',
  'booking_call_incoming',
};

/// Single place that decides which screen a notification (tapped from the
/// in-app list, or from the push notification itself) should open — used by
/// both NotificationsScreen and app.dart's onNotificationTap so the two
/// stay in sync instead of drifting apart. Known types land straight on the
/// relevant screen (booking tracking, invoice, chat thread, consultation);
/// anything else falls back to the generic NotificationDetailScreen.
Future<void> openNotificationTarget(
  BuildContext context, {
  required String title,
  required String body,
  Map<String, dynamic>? data,
  String? createdAt,
}) async {
  final type = data?['type'] as String?;
  final bookingId = data?['booking_id'] as String?;
  final consultationId = data?['consultation_id'] as String?;

  if (type == 'booking_message' && bookingId != null && bookingId.isNotEmpty) {
    final peerName = (data?['sender_name'] as String?)?.trim();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingChatScreen(
        bookingId: bookingId,
        peerName: (peerName != null && peerName.isNotEmpty) ? peerName : 'Chat',
      ),
    ));
    return;
  }

  if (type != null && _bookingStatusTypes.contains(type) && bookingId != null && bookingId.isNotEmpty) {
    await _openBooking(context, bookingId);
    return;
  }

  if ((type == 'invoice_ready' || type == 'payment_success') && bookingId != null && bookingId.isNotEmpty) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(bookingId: bookingId)));
    return;
  }

  if (type != null && type.startsWith('consultation') && consultationId != null && consultationId.isNotEmpty) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostCallScreen(consultationId: consultationId, categoryId: '', categoryName: ''),
    ));
    return;
  }

  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => NotificationDetailScreen(title: title, body: body, data: data, createdAt: createdAt),
  ));
}

/// Routes by role, same as NotificationDetailScreen used to do on its own
/// "View Booking" button — a technician needs the full Booking object for
/// TechnicianJobDetailScreen, so that's fetched first; a customer just needs
/// the id for BookingTrackingScreen.
Future<void> _openBooking(BuildContext context, String bookingId) async {
  final role = context.read<AuthProvider>().currentUser?.role;
  if (role != 'technician') {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingTrackingScreen(bookingId: bookingId)));
    return;
  }

  final provider = context.read<BookingProvider>();
  try {
    await provider.fetchBookingDetail(bookingId);
    if (!context.mounted) return;
    final booking = provider.selectedBooking;
    if (booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load this job')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TechnicianJobDetailScreen(booking: booking)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load this job: $e')));
  }
}
