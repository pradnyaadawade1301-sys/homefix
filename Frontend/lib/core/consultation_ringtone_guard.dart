import 'package:flutter_ringtone_player/flutter_ringtone_player.dart' show FlutterRingtonePlayer;

// BUG #16 FIX: process-wide guard so the looping consultation ringtone is
// never started twice (e.g. once from the FCM foreground-message callback
// in app.dart, and again from IncomingConsultationScreen's own
// pending-list sync if that screen is already open when the push arrives).
// Both call sites go through this instead of calling FlutterRingtonePlayer
// directly. Kept in its own file (rather than inside app.dart) so it can be
// imported by screens without creating an app.dart <-> screen import cycle.
class ConsultationRingtoneGuard {
  static bool _isRinging = false;

  static void start() {
    if (_isRinging) return; // already looping — don't stack a second one
    _isRinging = true;
    FlutterRingtonePlayer().playRingtone(looping: true, volume: 1.0, asAlarm: false);
  }

  static void stop() {
    if (!_isRinging) return;
    _isRinging = false;
    FlutterRingtonePlayer().stop();
  }
}