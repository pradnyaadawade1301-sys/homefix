import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  final SignalingService signaling;
  final String peerId; // doosre user (technician ya customer) ki id
  final String myId;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  /// ICE server config for RTCPeerConnection. Pass the backend's
  /// ice_servers (see GET /consultations/:id/call — includes STUN + a
  /// short-lived TURN credential) so calls still connect when both sides
  /// are behind strict/symmetric NAT (common on mobile data), where plain
  /// STUN alone can't establish a direct path.
  final Map<String, dynamic> _rtcConfig;

  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function()? onCallEnded;

  WebRTCService({
    required this.signaling,
    required this.peerId,
    required this.myId,
    List<Map<String, dynamic>>? iceServers,
  }) : _rtcConfig = {
          'iceServers': (iceServers != null && iceServers.isNotEmpty)
              ? iceServers
              : [
                  {'urls': 'stun:stun.l.google.com:19302'},
                ],
        };

  Future<void> init() async {
    peerConnection = await createPeerConnection(_rtcConfig);

    peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      signaling.send(SignalingMessage(
        type: 'ice-candidate',
        from: myId,
        to: peerId,
        data: candidate.toMap(),
      ));
    };

    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream?.call(remoteStream!);
      }
    };

    peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        onCallEnded?.call();
      }
    };

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    onLocalStream?.call(localStream!);

    for (final track in localStream!.getTracks()) {
      await peerConnection!.addTrack(track, localStream!);
    }
  }

  /// Customer side: offer create karke technician ko bhejta hai.
  Future<void> createOffer() async {
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    signaling.send(SignalingMessage(
      type: 'offer',
      from: myId,
      to: peerId,
      data: {'sdp': offer.sdp, 'type': offer.type},
    ));
  }

  // ICE candidates from the peer can legitimately arrive before we've called
  // setRemoteDescription (offer/answer) — WebRTC forbids addCandidate() until
  // then. Without buffering, any candidate that races ahead of the SDP is
  // silently dropped (flutter_webrtc throws, caught nowhere), which weakens
  // or fully breaks connectivity depending on how many were lost — a classic
  // source of "sometimes connects, sometimes doesn't".
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  /// Technician side: customer ka offer receive karke answer bhejta hai.
  Future<void> handleOffer(Map<String, dynamic> data) async {
    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, data['type'] as String),
    );
    await _flushPendingCandidates();
    final answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);
    signaling.send(SignalingMessage(
      type: 'answer',
      from: myId,
      to: peerId,
      data: {'sdp': answer.sdp, 'type': answer.type},
    ));
  }

  /// Customer side: technician ka answer receive karta hai.
  Future<void> handleAnswer(Map<String, dynamic> data) async {
    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, data['type'] as String),
    );
    await _flushPendingCandidates();
  }

  Future<void> _flushPendingCandidates() async {
    _remoteDescriptionSet = true;
    for (final c in _pendingCandidates) {
      await peerConnection?.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  Future<void> handleRemoteIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );
    if (!_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
    await peerConnection?.addCandidate(candidate);
  }

  /// Mutes/unmutes the mic by toggling the local audio track directly —
  /// cheaper than renegotiating and works even mid-call. Returns the new
  /// enabled state so the caller doesn't have to track it separately.
  bool toggleMic() {
    final audioTracks = localStream?.getAudioTracks() ?? [];
    if (audioTracks.isEmpty) return false;
    final newEnabled = !audioTracks.first.enabled;
    for (final track in audioTracks) {
      track.enabled = newEnabled;
    }
    return newEnabled;
  }

  /// Enables/disables the camera without stopping the track, so the peer
  /// connection and its senders stay intact — just a black frame goes out.
  bool toggleCamera() {
    final videoTracks = localStream?.getVideoTracks() ?? [];
    if (videoTracks.isEmpty) return false;
    final newEnabled = !videoTracks.first.enabled;
    for (final track in videoTracks) {
      track.enabled = newEnabled;
    }
    return newEnabled;
  }

  /// Flips between front and back camera on the existing video track.
  Future<void> switchCamera() async {
    final videoTracks = localStream?.getVideoTracks() ?? [];
    if (videoTracks.isEmpty) return;
    await Helper.switchCamera(videoTracks.first);
  }

  Future<void> hangUp() async {
    for (final track in localStream?.getTracks() ?? []) {
      await track.stop();
    }
    await localStream?.dispose();
    await peerConnection?.close();
    localStream = null;
    peerConnection = null;
  }
}