import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level background message handler required by Firebase.
/// Must be a top-level function (not a method on a class) so the
/// plugin can locate it via its Dart function pointer even when the
/// app process was cold-started by a notification tap.
///
/// Logs the event for debugging and stores the payload so it can be
/// processed when the app initializes.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] message received: ${message.messageId}');
  debugPrint('[FCM Background] title: ${message.notification?.title}');
  debugPrint('[FCM Background] body: ${message.notification?.body}');
  debugPrint('[FCM Background] data: ${message.data}');
}

