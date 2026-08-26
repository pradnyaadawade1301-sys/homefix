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

  /// Technician side: customer ka offer receive karke answer bhejta hai.
  Future<void> handleOffer(Map<String, dynamic> data) async {
    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, data['type'] as String),
    );
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
  }

  Future<void> handleRemoteIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );
    await peerConnection?.addCandidate(candidate);
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