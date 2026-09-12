import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart' show FlutterRingtonePlayer;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/booking_service.dart';
import '../services/signaling_service.dart';
import 'video_call_screen.dart';

/// Shown to whichever side (customer or technician) is on the *receiving*
/// end of a booking audio call (see app.dart's onIncomingBookingCall) —
/// mirrors how a real phone call rings before you pick up. Unlike the old
/// behaviour of joining the call room the instant the FCM push landed, the
/// call room is only joined (== "answered", see CallHandler.join on the
/// backend) once the user actually taps Answer here.
///
/// The ringtone (started by app.dart right before this screen is pushed)
/// keeps looping the whole time this screen is up, exactly like the
/// incoming-consultation flow, and stops the moment the user answers,
/// declines, or the caller hangs up before either happens.
class IncomingBookingCallScreen extends StatefulWidget {
  final String bookingId;
  final String? peerDisplayName;

  const IncomingBookingCallScreen({
    super.key,
    required this.bookingId,
    this.peerDisplayName,
  });

  @override
  State<IncomingBookingCallScreen> createState() => _IncomingBookingCallScreenState();
}

class _IncomingBookingCallScreenState extends State<IncomingBookingCallScreen> {
  bool _responding = false;

  void _stopRingtone() => FlutterRingtonePlayer().stop();

  @override
  void dispose() {
    // Covers the "caller hung up before we answered" and "user backed out"
    // cases too — whatever route this screen leaves by, the ringtone must
    // not keep looping in the background.
    _stopRingtone();
    super.dispose();
  }

  Future<void> _answer() async {
    if (_responding) return;
    setState(() => _responding = true);
    _stopRingtone();

    try {
      final bookingService = context.read<BookingService>();
      final authProvider = context.read<AuthProvider>();

      final callInfo = await bookingService.getCallInfo(widget.bookingId);
      if (!mounted) return;
      final token = await authProvider.getValidAccessToken();
      if (!mounted) return;
      final myId = authProvider.currentUser?.id ?? '';

      if (token == null) {
        _fail('Could not answer — please sign in again.');
        return;
      }

      final signaling = SignalingService(
        serverUrl: ApiConfig.wsCallUrl(widget.bookingId, token),
        userId: myId,
        isDirectUrl: true,
      );
      // Joining the room is what marks the call "answered" on the backend
      // (see CallHandler.join) — nothing else needs to happen to accept.
      signaling.connect();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          signaling: signaling,
          myId: myId,
          peerId: widget.bookingId,
          isCaller: false,
          audioOnly: true,
          iceServers: callInfo.iceServers,
          peerDisplayName: widget.peerDisplayName,
        ),
      ));
    } catch (e) {
      _fail('Could not join the call: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  void _decline() {
    // No "reject" endpoint exists other than the call's own WebSocket room,
    // so briefly connect just long enough to relay a call-reject to the
    // caller (VideoCallScreen already ends the call on that message — see
    // its 'call-reject' case), then disconnect. This is why the caller's
    // side stops ringing/hangs up immediately instead of continuing to show
    // "Connecting..." until they give up and hang up manually.
    _stopRingtone();
    final authProvider = context.read<AuthProvider>();
    final myId = authProvider.currentUser?.id ?? '';
    final bookingId = widget.bookingId;
    Navigator.of(context).pop();
    _sendRejectThenDisconnect(authProvider: authProvider, myId: myId, bookingId: bookingId);
  }

  Future<void> _sendRejectThenDisconnect({
    required AuthProvider authProvider,
    required String myId,
    required String bookingId,
  }) async {
    SignalingService? signaling;
    try {
      final token = await authProvider.getValidAccessToken();
      if (token == null) return;
      signaling = SignalingService(
        serverUrl: ApiConfig.wsCallUrl(bookingId, token),
        userId: myId,
        isDirectUrl: true,
      );

      // Fixed delays here are a race: the caller's own socket can take
      // longer to connect than expected (InitiateCall's backend round trip
      // — DB writes, sending the FCM push itself — all finish BEFORE the
      // caller even starts connecting its socket), so if we sent-and-closed
      // on a timer we could disconnect before the caller ever joined the
      // room, and the reject would have nowhere to go. Instead, wait for
      // the backend's own 'peer-joined' confirmation that the caller's
      // socket is actually in the room, and only then send the reject —
      // this is what previously made "technician calls, customer declines
      // quickly" silently fail to hang up the technician's side, while the
      // reverse direction happened to work because the customer (caller)
      // tends to take longer to react, giving their socket time to connect
      // first.
      final peerJoined = Completer<void>();
      signaling.onMessage = (msg) {
        if (msg.type == 'peer-joined' && !peerJoined.isCompleted) {
          peerJoined.complete();
        }
      };
      signaling.connect();

      await peerJoined.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Caller never connected at all (e.g. their own call setup
          // failed) — nothing to notify, just clean up below.
        },
      );

      if (signaling.isConnected) {
        signaling.send(SignalingMessage(type: 'call-reject', from: myId, to: ''));
        // Brief pause so the message is flushed to the socket before we
        // close it — closing immediately after send can drop it.
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      // Best-effort — if this fails the caller simply keeps ringing until
      // they hang up themselves, which the backend still logs as a missed
      // call (see CallHandler.leave), so nothing is left in a broken state.
    } finally {
      signaling?.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.peerDisplayName?.trim();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _decline();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B2B26),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        child: Text(
                          (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Incoming audio call', style: TextStyle(color: Colors.white70, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        (name != null && name.isNotEmpty) ? name : 'Unknown',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  if (_responding)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _CallActionButton(
                            icon: Icons.call_end_rounded,
                            color: AppTheme.errorColor,
                            label: 'Decline',
                            onPressed: _decline,
                          ),
                          const SizedBox(width: 48),
                          _CallActionButton(
                            icon: Icons.call_rounded,
                            color: AppTheme.successColor,
                            label: 'Answer',
                            onPressed: _answer,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: label,
          backgroundColor: color,
          onPressed: onPressed,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}