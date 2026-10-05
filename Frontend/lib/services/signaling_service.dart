import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Debug-only logging: nothing is printed in release builds.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

class SignalingMessage {
  final String type;
  final String from;
  final String to;
  final dynamic data;

  SignalingMessage({
    required this.type,
    required this.from,
    required this.to,
    this.data,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      from: (json['from'] ?? '') as String,
      to: (json['to'] ?? '') as String,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'from': from,
        'to': to,
        if (data != null) 'data': data,
      };
}

typedef OnMessage = void Function(SignalingMessage message);

/// Ek hi SignalingService instance poore app me use karein (ideally app
/// login ke baad connect() karein aur logout/dispose pe disconnect() karein).
class SignalingService {
  final String serverUrl;
  final String userId;
  final String role; // "customer" | "technician"

  /// When true, [serverUrl] is already the COMPLETE WebSocket URL (e.g. built
  /// via `ApiConfig.wsCallUrl(consultationId, accessToken)` for the Live Video
  /// Consultation flow), so `connect()` uses it as-is instead of appending
  /// `?userId=&role=` query params.
  final bool isDirectUrl;

  WebSocketChannel? _channel;
  OnMessage? _onMessage;
  final List<SignalingMessage> _messageQueue = [];

  OnMessage? get onMessage => _onMessage;
  set onMessage(OnMessage? listener) {
    _onMessage = listener;
    if (listener != null && _messageQueue.isNotEmpty) {
      _log('SignalingService: Flushing ${_messageQueue.length} queued messages to listener.');
      for (final msg in List.from(_messageQueue)) {
        listener(msg);
      }
      _messageQueue.clear();
    }
  }

  bool get isConnected => _channel != null;

  SignalingService({
    required this.serverUrl,
    required this.userId,
    this.role = '',
    this.isDirectUrl = false,
  });

  void connect() {
    final uri = isDirectUrl
        ? Uri.parse(serverUrl)
        : Uri.parse('$serverUrl?userId=$userId&role=$role');
    _log('SignalingService: Connecting to $uri');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (raw) {
        _log('SignalingService: Received raw message: $raw');
        try {
          final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
          final msg = SignalingMessage.fromJson(decoded);
          if (_onMessage != null) {
            _onMessage!.call(msg);
          } else {
            _log('SignalingService: No listener registered. Queueing message of type: ${msg.type}');
            _messageQueue.add(msg);
          }
        } catch (e) {
          _log('SignalingService: Error parsing message: $e');
        }
      },
      onDone: () {
        _log('SignalingService: Connection closed.');
        _channel = null;
      },
      onError: (e) {
        _log('SignalingService: Error: $e');
      },
    );
  }

  void send(SignalingMessage message) {
    if (_channel == null) {
      _log('SignalingService: Cannot send message, not connected! Message type: ${message.type}');
      return;
    }
    final encoded = jsonEncode(message.toJson());
    _log('SignalingService: Sending message: $encoded');
    _channel?.sink.add(encoded);
  }

  void disconnect() {
    _log('SignalingService: Disconnecting.');
    _channel?.sink.close();
    _channel = null;
    _messageQueue.clear();
  }
}