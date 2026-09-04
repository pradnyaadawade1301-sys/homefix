import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  await Firebase.initializeApp();

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? token = await messaging.getToken();
  print("FCM TOKEN: $token");

  runApp(const MyApp());
}