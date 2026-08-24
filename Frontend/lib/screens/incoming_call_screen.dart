import 'package:flutter/material.dart';
import '../services/signaling_service.dart';
import 'video_call_screen.dart';

/// Technician ke app me jab bhi 'call-request' message aaye, is screen
/// ko push kar dena (dekhein README ke "Technician side wiring" section).
class IncomingCallScreen extends StatelessWidget {
  final SignalingService signaling;
  final String myId;
  final String callerId; // customer ki id

  const IncomingCallScreen({
    super.key,
    required this.signaling,
    required this.myId,
    required this.callerId,
  });

  void _accept(BuildContext context) {
    signaling.send(SignalingMessage(type: 'call-accept', from: myId, to: callerId));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          signaling: signaling,
          myId: myId,
          peerId: callerId,
          isCaller: false, // technician customer ke offer ka wait karega
        ),
      ),
    );
  }

  void _reject(BuildContext context) {
    signaling.send(SignalingMessage(type: 'call-reject', from: myId, to: callerId));
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
                  callerId,
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