import 'package:flutter/material.dart';
import '../services/signaling_service.dart';
import '../screens/incoming_call_screen.dart';

/// Wraps [SignalingService] so it can be created/recreated once the logged-in
/// user's id + role are known, and — for technicians — automatically pops up
/// [IncomingCallScreen] whenever a `call-request` arrives, no matter which
/// screen the technician is currently on.
///
/// Wired into MultiProvider in app.dart via ChangeNotifierProxyProvider,
/// listening to AuthProvider so it connects right after login/auto-login.
class SignalingProvider extends ChangeNotifier {
  SignalingService? _service;
  SignalingService? get service => _service;
  bool get isConnected => _service?.isConnected ?? false;

  String? _role;
  GlobalKey<NavigatorState>? _navigatorKey;

  void connect({
    required String wsUrl,
    required String userId,
    required String role, // "customer" | "technician"
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    // Already connected as this exact user — nothing to do.
    if (_service != null && _service!.userId == userId && _service!.isConnected) return;

    _service?.disconnect();
    _role = role;
    _navigatorKey = navigatorKey;

    final svc = SignalingService(serverUrl: wsUrl, userId: userId, role: role);
    _service = svc;
    svc.connect();
    _listenForIncomingCalls();
    notifyListeners();
  }

  /// Re-attaches the "waiting for an incoming call" listener. VideoCallScreen
  /// takes over `onMessage` for the duration of a call (to handle
  /// offer/answer/ice), so a technician must call this again once they're
  /// back on a screen where they should receive new call requests (e.g. in
  /// `TechnicianStatusScreen`'s initState, or right after a call ends).
  void listenForIncomingCalls() => _listenForIncomingCalls();

  void _listenForIncomingCalls() {
    final svc = _service;
    if (svc == null || _role != 'technician' || _navigatorKey == null) return;
    svc.onMessage = (msg) {
      if (msg.type == 'call-request') {
        _navigatorKey!.currentState?.push(MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            signaling: svc,
            myId: svc.userId,
            callerId: msg.from,
          ),
        ));
      }
    };
  }

  void disconnect() {
    _service?.disconnect();
    _service = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service?.disconnect();
    super.dispose();
  }
}