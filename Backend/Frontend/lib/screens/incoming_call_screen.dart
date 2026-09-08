import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart' show FlutterRingtonePlayer;
import '../services/signaling_service.dart';
import 'video_call_screen.dart';

/// Technician ke app me jab bhi 'call-request' message aaye, is screen
/// ko push kar dena (dekhein README ke "Technician side wiring" section).
class IncomingCallScreen extends StatefulWidget {
  final SignalingService signaling;
  final String myId;
  final String callerId; // customer ki id

  const IncomingCallScreen({
    super.key,
    required this.signaling,
    required this.myId,
    required this.callerId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  void initState() {
    super.initState();
    // Ringtone bajti rahe jab tak technician accept/reject na kare (loop).
    FlutterRingtonePlayer().playRingtone(looping: true, volume: 1.0, asAlarm: false);
  }

  void _stopRingtone() => FlutterRingtonePlayer().stop();

  @override
  void dispose() {
    _stopRingtone();
    super.dispose();
  }

  void _accept(BuildContext context) {
    _stopRingtone();
    widget.signaling.send(SignalingMessage(type: 'call-accept', from: widget.myId, to: widget.callerId));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          signaling: widget.signaling,
          myId: widget.myId,
          peerId: widget.callerId,
          isCaller: false, // technician customer ke offer ka wait karega
        ),
      ),
    );
  }

  void _reject(BuildContext context) {
    _stopRingtone();
    widget.signaling.send(SignalingMessage(type: 'call-reject', from: widget.myId, to: widget.callerId));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const Icon(Icons.person, size: 100, color: Colors.white70),
                const SizedBox(height: 16),
                const Text(
                  'Incoming video call',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.callerId,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'reject',
                  backgroundColor: Colors.red,
                  onPressed: () => _reject(context),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: 'accept',
                  backgroundColor: Colors.green,
                  onPressed: () => _accept(context),
                  child: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}