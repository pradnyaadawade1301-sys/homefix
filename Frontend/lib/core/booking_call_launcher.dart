import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../services/signaling_service.dart';
import '../screens/video_call_screen.dart';

/// Mirrors the status whitelist in BookingService.InitiateCall on the
/// backend: a call is allowed once a technician is assigned and the job has
/// at least started — and stays allowed even after the job is marked
/// completed (e.g. the customer following up about the finished work), so
/// this only excludes the states where there's genuinely no one to call yet
/// (still just 'requested'/'pending_technician') or the booking is dead
/// (cancelled). Screens should use this to disable/hide their "Call" button
/// up front, instead of letting the user tap it and only then surfacing the
/// backend's "a call can only be started while the job is active" error.
bool isCallableBookingStatus(String status) {
  switch (status) {
    case 'accepted':
    case 'on_the_way':
    case 'arrived':
    case 'inspecting':
    case 'in_progress':
    case 'completed':
      return true;
    default:
      return false;
  }
}

/// Starts an in-app, peer-to-peer audio call about an active booking —
/// used by BOTH sides: the technician's "Call" button on the job detail
/// screen and the customer's "Call" button on the tracking screen. Either
/// caller notifies the *other* side via FCM (see
/// BookingService.InitiateCall on the backend), which rings and auto-joins
/// the same room (see app.dart's onIncomingBookingCall).
///
/// [peerDisplayName] is the name to show on the calling screen for the
/// *other* party (the customer's name when a technician calls, or the
/// technician's name when a customer calls) — the caller's own screen
/// already has this on hand (e.g. from the booking detail it's showing),
/// so there's no need to wait on a round trip just to get it.
Future<void> startBookingAudioCall(
  BuildContext context, {
  required String bookingId,
  required String peerDisplayName,
}) async {
  final bookingProvider = context.read<BookingProvider>();
  final authProvider = context.read<AuthProvider>();

  // Simple "connecting" feedback while we notify the backend/peer — this
  // can take a moment on a slow connection and there's nothing to show
  // yet (no call screen to push to until we have ICE servers + room id).
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final callInfo = await bookingProvider.initiateCall(bookingId);
    final token = await authProvider.getValidAccessToken();
    final myId = authProvider.currentUser?.id ?? '';

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the spinner

    if (token == null) {
      _showError(context, 'Could not start the call — please sign in again.');
      return;
    }

    final signaling = SignalingService(
      serverUrl: ApiConfig.wsCallUrl(bookingId, token),
      userId: myId,
      isDirectUrl: true,
    );
    signaling.connect();

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoCallScreen(
        signaling: signaling,
        myId: myId,
        peerId: bookingId, // room only ever has 2 sockets — exact id unused by the relay
        isCaller: true,
        audioOnly: true,
        iceServers: callInfo.iceServers,
        peerDisplayName: peerDisplayName,
      ),
    ));
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the spinner
    _showError(context, e.toString().replaceFirst('Exception: ', ''));
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}