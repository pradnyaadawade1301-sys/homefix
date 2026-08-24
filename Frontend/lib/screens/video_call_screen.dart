import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

/// Actual video call UI - customer aur technician dono isi screen ko
/// use karte hain, bas [isCaller] flag alag hota hai.
class VideoCallScreen extends StatefulWidget {
  final SignalingService signaling;
  final String myId;
  final String peerId;
  final bool isCaller; // true = customer (offer create karega)

  const VideoCallScreen({
    super.key,
    required this.signaling,
    required this.myId,
    required this.peerId,
    required this.isCaller,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  late final WebRTCService _webrtc;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _webrtc = WebRTCService(
      signaling: widget.signaling,
      peerId: widget.peerId,
      myId: widget.myId,
    );

    _webrtc.onLocalStream = (stream) {
      _localRenderer.srcObject = stream;
      if (mounted) setState(() {});
    };
    _webrtc.onRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      if (mounted) setState(() => _connecting = false);
    };
    _webrtc.onCallEnded = () {
      if (mounted) Navigator.of(context).pop();
    };

    widget.signaling.onMessage = (msg) async {
      switch (msg.type) {
        case 'offer':
          await _webrtc.handleOffer(Map<String, dynamic>.from(msg.data as Map));
          break;
        case 'answer':
          await _webrtc.handleAnswer(Map<String, dynamic>.from(msg.data as Map));
          break;
        case 'ice-candidate':
          await _webrtc.handleRemoteIceCandidate(Map<String, dynamic>.from(msg.data as Map));
          break;
        case 'call-end':
          _endCall(notifyPeer: false);
          break;
      }
    };

    await _webrtc.init();

    if (widget.isCaller) {
      await _webrtc.createOffer();
    }
    // isCaller == false (technician) to bas wait karega, offer upar wale
    // signaling.onMessage handler se 'offer' case me apne aap handle ho jayega.
  }

  void _endCall({bool notifyPeer = true}) async {
    if (notifyPeer) {
      widget.signaling.send(SignalingMessage(
        type: 'call-end',
        from: widget.myId,
        to: widget.peerId,
      ));
    }
    await _webrtc.hangUp();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtc.hangUp();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          if (_connecting)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text('Connecting...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          Positioned(
            top: 40,
            right: 20,
            width: 120,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RTCVideoView(_localRenderer, mirror: true),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                onPressed: () => _endCall(),
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}