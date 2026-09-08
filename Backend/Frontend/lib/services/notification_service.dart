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

  /// Callback invoked when a notification is tapped, carrying the full
  /// payload — `title`, `body`, and the notification's custom `data` map
  /// merged together — so the app can show that exact notification's
  /// message and/or navigate to the relevant screen.
  void Function(Map<String, dynamic> payload)? onNotificationTap;

  /// Callback invoked the moment a "New consultation request" push arrives
  /// while the app is in the foreground (data['type'] == 'consultation_request').
  /// Unlike [onNotificationTap], this fires immediately without the user
  /// having to tap anything — used to start ringing + jump the technician
  /// straight to the incoming-request screen, like a real incoming call.
  void Function(Map<String, dynamic> payload)? onIncomingConsultation;

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

      // 2. Android notification channels (required for Android 8+)
      const androidChannel = AndroidNotificationChannel(
        'homefix_notifications',
        'HomeFix Notifications',
        description: 'Notifications about bookings, payments, and consultations',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      // Separate, higher-priority channel just for incoming consultation call
      // requests — Importance.max forces a heads-up (pop-over) banner with
      // sound even while the app is backgrounded, which the shared
      // 'homefix_notifications' channel (Importance.high) doesn't guarantee
      // on all OEMs. The backend tags consultation_request pushes with this
      // channel id (see internal/service/firebase_service.go AndroidConfig),
      // so Android itself displays + sounds the alert in background/killed
      // state without any Dart code needing to run.
      const incomingCallChannel = AndroidNotificationChannel(
        'incoming_calls',
        'Incoming Consultation Calls',
        description: 'Alerts for incoming live video consultation requests',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      final flutterPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (flutterPlugin != null) {
        await flutterPlugin.createNotificationChannel(androidChannel);
        await flutterPlugin.createNotificationChannel(incomingCallChannel);
        debugPrint('[FCM] Notification channels created');
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
        final payload = _toTapPayload(initialMessage);
        if (initialMessage.data['type'] == 'consultation_request') {
          onIncomingConsultation?.call(payload);
        } else {
          _handleNotificationTap(payload);
        }
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

    // Incoming consultation request: ring + jump straight to the
    // accept/decline screen immediately, instead of waiting for the user to
    // tap a notification banner — matches how a real incoming call behaves.
    if (message.data['type'] == 'consultation_request') {
      onIncomingConsultation?.call(_toTapPayload(message));
      return;
    }

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handles a notification tap when the app was in the background.
  Future<void> _onNotificationOpenedApp(RemoteMessage message) async {
    debugPrint('[FCM OpenedApp] data: ${message.data}');
    final payload = _toTapPayload(message);
    if (message.data['type'] == 'consultation_request') {
      onIncomingConsultation?.call(payload);
      return;
    }
    _handleNotificationTap(payload);
  }

  /// Merges a RemoteMessage's title/body with its custom data map into the
  /// single payload shape [onNotificationTap] expects.
  Map<String, dynamic> _toTapPayload(RemoteMessage message) {
    return {
      'title': message.notification?.title ?? 'HomeFix',
      'body': message.notification?.body ?? '',
      ...message.data,
    };
  }

  /// Handles a tap on a local notification displayed by this service.
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM LocalTap] payload: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationTap(payload);
      } catch (e) {
        debugPrint('[FCM] Error parsing local notification payload: $e');
      }
    }
  }

  /// Invokes the tap callback with the notification's title/body/data.
  void _handleNotificationTap(Map<String, dynamic> payload) {
    debugPrint('[FCM] Handling notification tap with payload: $payload');
    onNotificationTap?.call(payload);
  }

  // ────────────────── Local Notification Display ──────────────────

  /// Displays a local notification for a foreground FCM message.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'HomeFix';
    final body = message.notification?.body ?? '';
    final payload = jsonEncode(_toTapPayload(message));

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
    appId: '1:299649646704:android:c55aa0e209775eb3b6b4b5',
    messagingSenderId: '299649646704',
    projectId: 'homefix-live',
    storageBucket: 'homefix-live.firebasestorage.app',
  );
}