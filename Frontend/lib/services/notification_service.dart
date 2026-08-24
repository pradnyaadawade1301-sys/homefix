import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton that manages Firebase Cloud Messaging (FCM) operations:
/// - Firebase initialization
/// - FCM token generation and refresh
/// - Foreground / background / terminated notification handling
/// - Android 13+ notification permission request
/// - Notification channel creation
/// - Local notification display for foreground messages
/// - Deep-link / navigation routing on notification tap
///
/// Access globally via [FcmNotificationService.instance].
class FcmNotificationService {
  static final FcmNotificationService _instance = FcmNotificationService._();
  factory FcmNotificationService() => _instance;
  FcmNotificationService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  /// The current FCM registration token. Null until Firebase initializes.
  String? get fcmToken => _fcmToken;

  /// Callback invoked when a notification is tapped, carrying the
  /// payload data map so the app can navigate to the relevant screen.
  void Function(Map<String, dynamic>? data)? onNotificationTap;

  /// Set this callback to send the FCM token to your backend whenever
  /// it is first obtained or refreshed. Called with the new token value.
  void Function(String token)? onTokenRefreshed;

  bool _initialized = false;

  // ────────────────── Initialization ──────────────────

  /// Initializes Firebase, FCM, local notifications, and all listeners.
  /// Must be called once from main() before runApp().
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Firebase Core
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[FCM] Firebase initialized successfully');

      _messaging = FirebaseMessaging.instance;

      // 2. Android notification channel (required for Android 8+)
      const androidChannel = AndroidNotificationChannel(
        'homefix_notifications',
        'HomeFix Notifications',
        description: 'Notifications about bookings, payments, and consultations',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      final flutterPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (flutterPlugin != null) {
        await flutterPlugin.createNotificationChannel(androidChannel);
        debugPrint('[FCM] Notification channel created');
      }

      // 3. Initialize local notifications plugin
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      // 4. Request notification permission (Android 13+)
      await _requestPermission();

      // 5. Get the current FCM token
      await _refreshToken();

      // 6. Listen for token refresh
      _messaging!.onTokenRefresh.listen(_onTokenRefresh);

      // 7. Set up foreground message handler (shows local notification)
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 8. Set up notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

      // 9. Check if app was opened from a terminated-state notification
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from terminated notification');
        _handleNotificationTap(initialMessage.data);
      }

      _initialized = true;
      debugPrint('[FCM] FcmNotificationService fully initialized');
    } catch (e, stack) {
      debugPrint('[FCM] Initialization error: $e\n$stack');
    }
  }

  // ────────────────── Token Management ──────────────────

  /// Fetches the current FCM token from Firebase.
  Future<String?> _refreshToken() async {
    try {
      _fcmToken = await _messaging?.getToken();
      debugPrint('[FCM] Token: $_fcmToken');
      if (_fcmToken != null) {
        onTokenRefreshed?.call(_fcmToken!);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
      return null;
    }
  }

  /// Called when Firebase issues a new token (e.g. app reinstall, security rotation).
  void _onTokenRefresh(String newToken) {
    debugPrint('[FCM] Token refreshed: $newToken');
    _fcmToken = newToken;
    onTokenRefreshed?.call(newToken);
  }

  // ────────────────── Permission Handling ──────────────────

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ (API 33) requires runtime permission for notifications.
      final flutterPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (flutterPlugin != null) {
        final granted = await flutterPlugin.requestNotificationsPermission();
        debugPrint('[FCM] Notification permission granted: $granted');
      }
    } else if (Platform.isIOS) {
      final settings = await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] iOS permission: ${settings?.authorizationStatus}');
    }
  }

  // ────────────────── Message Handling ──────────────────

  /// Handles messages received while the app is in the foreground.
  /// Shows a local notification since FCM doesn't display foreground
  /// notifications automatically.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM Foreground] message: ${message.messageId}');
    debugPrint('[FCM Foreground] title: ${message.notification?.title}');
    debugPrint('[FCM Foreground] body: ${message.notification?.body}');
    debugPrint('[FCM Foreground] data: ${message.data}');

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handles a notification tap when the app was in the background.
  Future<void> _onNotificationOpenedApp(RemoteMessage message) async {
    debugPrint('[FCM OpenedApp] data: ${message.data}');
    _handleNotificationTap(message.data);
  }

  /// Handles a tap on a local notification displayed by this service.
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM LocalTap] payload: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationTap(data);
      } catch (e) {
        debugPrint('[FCM] Error parsing local notification payload: $e');
      }
    }
  }

  /// Routes notification data to the appropriate screen via the callback.
  void _handleNotificationTap(Map<String, dynamic>? data) {
    debugPrint('[FCM] Handling notification tap with data: $data');
    onNotificationTap?.call(data);
  }

  // ────────────────── Local Notification Display ──────────────────

  /// Displays a local notification for a foreground FCM message.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'HomeFix';
    final body = message.notification?.body ?? '';
    final payload = message.data.isNotEmpty ? jsonEncode(message.data) : null;

    const androidDetails = AndroidNotificationDetails(
      'homefix_notifications',
      'HomeFix Notifications',
      channelDescription: 'Notifications about bookings, payments, and consultations',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
    debugPrint('[FCM] Local notification displayed: id=$id title=$title');
  }

  // ────────────────── Cleanup ──────────────────

  /// Disposes of resources (call on app dispose if needed).
  void dispose() {
    // Currently no resources to dispose; token listener is managed by Firebase.
  }
}

/// Generated by FlutterFire CLI or equivalent — provides the default
/// Firebase options for the current platform.
///
/// If this file doesn't exist in your project, run:
///   flutterfire configure --project=homefix-live
/// Or create it manually with the values from google-services.json.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) {
      return android;
    }
      throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBCOMKYqH0f44oMieGbRljGewoZbXWLO_Y',
    appId: '1:299649646704:android:a3d43695262f40edb6b4b5',
    messagingSenderId: '299649646704',
    projectId: 'homefix-live',
    storageBucket: 'homefix-live.firebasestorage.app',
  );
}
  

