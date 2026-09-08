import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';

/// Global FCM notification service instance — accessed from app.dart
/// and any screen that needs to navigate on notification tap.
final FcmNotificationService fcmNotificationService = FcmNotificationService();

/// Global navigator key so a notification tap (which fires outside any
/// screen's BuildContext — could be from a killed/background app) can still
/// push a screen onto the app's navigator.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // This sets up everything: Firebase init, creates the Android notification
  // channels ("homefix_notifications" / "incoming_calls") that the backend's
  // pushes target, requests the Android 13+ POST_NOTIFICATIONS permission,
  // fetches the FCM token, and wires up foreground/background/tap listeners.
  // Previously this file only called Firebase.initializeApp() + getToken()
  // directly and skipped all of that — so pushes arrived at the device with
  // a channel ID that was never created, and Android silently dropped them
  // even though the backend saw a successful send and notification
  // permission was granted.
  await fcmNotificationService.initialize();

  runApp(const MyApp());
}