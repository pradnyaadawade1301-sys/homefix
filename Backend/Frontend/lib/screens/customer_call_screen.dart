import 'package:flutter/material.dart';
import '../services/signaling_service.dart';
import 'video_call_screen.dart';

/// Customer isse open karega jab wo kisi technician ko video call
/// karna chahta hai. Ye "Calling..." dikhata hai jab tak technician
/// accept/reject nahi karta.
class CustomerCallScreen extends StatefulWidget {
  final SignalingService signaling;
  final String myId;
  final String technicianId;

  const CustomerCallScreen({
    super.key,
    required this.signaling,
    required this.myId,
    required this.technicianId,
  });

  @override
  State<CustomerCallScreen> createState() => _CustomerCallScreenState();
}

class _CustomerCallScreenState extends State<CustomerCallScreen> {
  String _status = 'Calling...';

  @override
  void initState() {
    super.initState();

    widget.signaling.onMessage = (msg) {
      if (!mounted) return;

      if (msg.type == 'call-accept') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              signaling: widget.signaling,
              myId: widget.myId,
              peerId: widget.technicianId,
              isCaller: true, // customer offer create karega
            ),
          ),
        );
      } else if (msg.type == 'call-reject') {
        setState(() => _status = 'Call declined');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (msg.type == 'user-unavailable') {
        setState(() => _status = 'Technician unavailable');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    };

    widget.signaling.send(SignalingMessage(
      type: 'call-request',
      from: widget.myId,
      to: widget.technicianId,
    ));
  }

  void _cancel() {
    widget.signaling.send(SignalingMessage(
      type: 'call-end',
      from: widget.myId,
      to: widget.technicianId,
    ));
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
                const Icon(Icons.build_circle, size: 100, color: Colors.white70),
                const SizedBox(height: 16),
                Text(_status, style: const TextStyle(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 8),
                Text(widget.technicianId, style: const TextStyle(color: Colors.white54)),
              ],
            ),
            FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: _cancel,
              child: const Icon(Icons.call_end, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}