import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart' show FlutterRingtonePlayer;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../providers/consultation_provider.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import 'consultation/post_call_screen.dart';
import 'consultation/technician_post_call_screen.dart';

/// Actual video call UI - customer aur technician dono isi screen ko
/// use karte hain, bas [isCaller] flag alag hota hai.
class VideoCallScreen extends StatefulWidget {
  final SignalingService signaling;
  final String myId;
  final String peerId;
  final bool isCaller; // true = customer (offer create karega)
  final List<Map<String, dynamic>>? iceServers;

  /// True for a plain booking audio call (technician "Audio Call" button) —
  /// no camera is requested and the UI shows an avatar instead of video.
  /// False (default) is the normal Live Video Consultation experience.
  final bool audioOnly;
  /// Shown in the audio-only UI's avatar/name area — the *other* party's
  /// name (e.g. the technician's name on the customer's screen, or the
  /// customer's name on the technician's screen). Has no effect otherwise.
  final String? peerDisplayName;

  // Consultation context — when this call is a Live Video Consultation
  // (customer side, started from SearchingTechnicianScreen), these are set
  // so we can (a) tell the backend the call ended, which is what makes it
  // show up in call history, and (b) offer "Book a Slot" with the same
  // technician right after hangup.
  final String? consultationId;
  final String? categoryId;
  final String? categoryName;
  final String? technicianName;
  // Customer's display name — only set on the technician side (isCaller ==
  // false) when opened from IncomingConsultationScreen, so
  // TechnicianPostCallScreen can show "Send recommendation to <name>".
  final String? customerName;

  const VideoCallScreen({
    super.key,
    required this.signaling,
    required this.myId,
    required this.peerId,
    required this.isCaller,
    this.iceServers,
    this.audioOnly = false,
    this.peerDisplayName,
    this.consultationId,
    this.categoryId,
    this.categoryName,
    this.technicianName,
    this.customerName,
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
  bool _micOn = true;
  bool _cameraOn = true;
  bool _ringing = false;
  DateTime? _connectedAt;

  /// One-shot "calling..." feedback for the caller (customer) — a single
  /// short tone (NOT the looping incoming-call ringtone) so the caller gets
  /// light audio confirmation without it sounding like their own phone is
  /// receiving an incoming call. Only the technician (receiver) gets the
  /// real looping ring, on the incoming-request screen before they even open
  /// this screen — see incoming_consultation_screen.dart / app.dart.
  void _startRingback() {
    if (!widget.isCaller || _ringing) return;
    _ringing = true;
    FlutterRingtonePlayer().playNotification();
  }

  void _stopRingback() {
    _ringing = false;
  }

  @override
  void initState() {
    super.initState();
    _startRingback();
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
      audioOnly: widget.audioOnly,
    );

    _webrtc.onLocalStream = (stream) {
      _localRenderer.srcObject = stream;
      if (mounted) setState(() {});
    };
    _webrtc.onRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      _stopRingback();
      _connectedAt ??= DateTime.now();
      if (mounted) setState(() => _connecting = false);
    };
    _webrtc.onCallEnded = () {
      _stopRingback();
      _endCall(notifyPeer: false);
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
        case 'call-reject':
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

  void _toggleMic() {
    final enabled = _webrtc.toggleMic();
    setState(() => _micOn = enabled);
  }

  void _toggleCamera() {
    final enabled = _webrtc.toggleCamera();
    setState(() => _cameraOn = enabled);
  }

  Future<void> _switchCamera() async {
    await _webrtc.switchCamera();
  }

  bool _ended = false;

  void _endCall({bool notifyPeer = true}) async {
    // Guards against this firing twice — once from the user's own tap, and
    // again from the onConnectionState callback that fires when hangUp()
    // below closes the peer connection locally. Without this, the second
    // call could pop an extra screen off the navigation stack.
    if (_ended) return;
    _ended = true;
    _stopRingback();

    if (notifyPeer) {
      widget.signaling.send(SignalingMessage(
        type: 'call-end',
        from: widget.myId,
        to: widget.peerId,
      ));
    }
    await _webrtc.hangUp();
    if (!mounted) return;

    // Report the call as ended so the backend flips it from "in_call" to
    // "ended" — without this the consultation stays stuck mid-call forever
    // and never shows up in the customer's call history. Only the customer
    // side carries consultationId (the technician side of this same screen
    // has it as null), so this only fires once per call.
    if (widget.consultationId != null) {
      final durationSeconds = _connectedAt != null
          ? DateTime.now().difference(_connectedAt!).inSeconds
          : 0;
      try {
        await context.read<ConsultationProvider>().endCall(
              widget.consultationId!,
              durationSeconds: durationSeconds,
              amount: 0,
            );
      } catch (_) {
        // Non-fatal — the customer can still see the call ended locally;
        // history may just be briefly stale if this particular call failed.
      }

      if (!mounted) return;

      if (widget.isCaller) {
        // Customer side.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PostCallScreen(
            consultationId: widget.consultationId!,
            categoryId: widget.categoryId ?? '',
            categoryName: widget.categoryName ?? '',
            technicianName: widget.technicianName,
          ),
        ));
      } else {
        // Technician side — previously just Navigator.pop()'d here with no
        // way to tell the customer what was found on the call. Now opens a
        // simple "send a recommendation" form instead.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => TechnicianPostCallScreen(
            consultationId: widget.consultationId!,
            categoryName: widget.categoryName ?? '',
            customerName: widget.customerName,
          ),
        ));
      }
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopRingback();
    // Null out the callbacks before hangUp()/dispose — if the underlying
    // service finishes some background work (a late ICE candidate, a stream
    // event) after this screen is gone, an un-nulled callback would still
    // fire and call setState() on a disposed State, crashing with
    // "setState() called on disposed widget."
    _webrtc.onLocalStream = null;
    _webrtc.onRemoteStream = null;
    _webrtc.onCallEnded = null;
    widget.signaling.onMessage = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtc.hangUp();
    // Without this, the client-side socket to /ws/call/:id stays open in the
    // background even after this screen is popped — the server never sees a
    // close frame, so it keeps treating the room as occupied for up to the
    // 60s keepalive timeout. Since a room caps at 2 sockets, the very next
    // call attempt on the same room finds it "full" and never gets
    // peer-joined, hanging on "Connecting..." forever — then the attempt
    // after that works again once the stale socket finally times out. This
    // is the exact odd/even alternating failure pattern.
    widget.signaling.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioOnly) {
      return _buildAudioOnlyUI();
    }
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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    widget.isCaller ? 'Ringing...' : 'Connecting...',
                    style: const TextStyle(color: Colors.white),
                  ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _controlButton(
                  icon: _micOn ? Icons.mic : Icons.mic_off,
                  onPressed: _toggleMic,
                  active: _micOn,
                ),
                const SizedBox(width: 18),
                _controlButton(
                  icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                  onPressed: _toggleCamera,
                  active: _cameraOn,
                ),
                const SizedBox(width: 18),
                _controlButton(
                  icon: Icons.cameraswitch,
                  onPressed: _switchCamera,
                  active: true,
                ),
                const SizedBox(width: 18),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () => _endCall(),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plain-audio-call UI: no camera preview at all (no camera was even
  /// requested — see WebRTCService's audioOnly branch), just the peer's
  /// name/avatar, a call-status label, and mic/end-call controls. Used for
  /// a technician's "Audio Call" about an active booking.
  Widget _buildAudioOnlyUI() {
    final name = widget.peerDisplayName?.trim();
    final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white12,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name != null && name.isNotEmpty ? name : 'HomeFix',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              _connecting ? (widget.isCaller ? 'Calling...' : 'Connecting...') : 'Audio call in progress',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _controlButton(
                  icon: _micOn ? Icons.mic : Icons.mic_off,
                  onPressed: _toggleMic,
                  active: _micOn,
                ),
                const SizedBox(width: 24),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () => _endCall(),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Round call-control button — filled white when the feature is on
  /// (mic/camera live), filled red when off, so state is readable at a
  /// glance without reading the icon.
  Widget _controlButton({required IconData icon, required VoidCallback onPressed, required bool active}) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white24 : Colors.red,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}