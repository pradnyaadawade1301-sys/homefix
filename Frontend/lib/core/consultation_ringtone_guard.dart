import 'package:flutter_ringtone_player/flutter_ringtone_player.dart' show FlutterRingtonePlayer;

class ConsultationRingtoneGuard {
  static bool _isRinging = false;

  static void start() {
    if (_isRinging) return;
    _isRinging = true;
    FlutterRingtonePlayer().playRingtone(looping: true, volume: 1.0, asAlarm: false);
  }

  static void stop() {
    if (!_isRinging) return;
    _isRinging = false;
    FlutterRingtonePlayer().stop();
  }
}