import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/firebase_messaging_handler.dart';

/// Global FCM notification service instance — accessed from app.dart
/// and any screen that needs to navigate on notification tap.
final FcmNotificationService fcmNotificationService = FcmNotificationService();

/// Global navigator key so a notification tap (which fires outside any
/// screen's BuildContext — could be from a killed/background app) can still
/// push a screen onto the app's navigator.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and FCM
  await fcmNotificationService.initialize();

  // Set the background message handler (must be top-level function)
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  debugPrint('[FCM] App starting with Firebase initialized');

  runApp(const MyApp());
}