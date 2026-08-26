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
  final List<Map<String, dynamic>>? iceServers;

  const VideoCallScreen({
    super.key,
    required this.signaling,
    required this.myId,
    required this.peerId,
    required this.isCaller,
    this.iceServers,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  late final WebRTCService _webrtc;
  bool _connecting = true;
  bool _offerSent = false;
  bool _peerJoined = false;
  bool _initDone = false;

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
      iceServers: widget.iceServers,
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
        case 'peer-joined':
          // Backend confirms BOTH sockets are now in the room. Only safe
          // moment to send the offer — before this, the other side's
          // socket might not exist yet and the relay would silently drop
          // it (no queueing for late joiners), leaving the call stuck on
          // "Connecting..." forever.
          _peerJoined = true;
          await _maybeSendOffer();
          break;
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
        case 'peer-left':
          _endCall(notifyPeer: false);
          break;
      }
    };

    await _webrtc.init();
    _initDone = true;
    // Covers the case where 'peer-joined' arrived (or was queued) before
    // getUserMedia/createPeerConnection finished — try again now that
    // _webrtc.peerConnection actually exists.
    await _maybeSendOffer();
  }

  /// Sends the WebRTC offer exactly once, and only once both (a) our own
  /// WebRTC setup has finished (peerConnection exists) and (b) the backend
  /// has confirmed the other side's socket is in the room too. Safe to call
  /// from either the 'peer-joined' handler or right after init() — whichever
  /// happens second is what actually triggers the send.
  Future<void> _maybeSendOffer() async {
    if (!widget.isCaller || _offerSent || !_peerJoined || !_initDone) return;
    _offerSent = true;
    await _webrtc.createOffer();
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