import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart' show FlutterRingtonePlayer;
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/http_client.dart';
import 'core/theme.dart';
import 'config/api_config.dart';
import 'l10n/app_localizations.dart';
import 'providers/address_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/call_log_provider.dart';
import 'providers/category_provider.dart';
import 'providers/consultation_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/location_provider.dart';
import 'providers/payment_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/consultation/incoming_consultation_screen.dart';
import 'screens/technician/technician_kyc_screen.dart';
import 'screens/technician/technician_status_screen.dart';
import 'services/auth_service.dart';
import 'services/booking_service.dart';
import 'services/call_log_service.dart';
import 'services/consultation_service.dart';
import 'services/location_service.dart';
import 'services/service_locator.dart';
import 'services/signaling_service.dart';
import 'screens/video_call_screen.dart';
import 'screens/technician/technician_jobs_screen.dart';
import 'screens/notifications/notification_detail_screen.dart';
import 'screens/chat/booking_chat_screen.dart';
import 'main.dart' as app; // for fcmNotificationService, navigatorKey

/// Sends the current FCM token to the backend via the authenticated endpoint.
/// Called when the token is first obtained or refreshed.
Future<void> _registerFcmToken(HttpClient httpClient) async {
  final token = app.fcmNotificationService.fcmToken;
  if (token == null || token.isEmpty) return;
  try {
    await httpClient.post('/users/me/fcm-token', data: {'token': token});
    debugPrint('[FCM] Token registered with backend: $token');
  } catch (e) {
    debugPrint('[FCM] Failed to register token with backend: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late HttpClient _httpClient;
  late AuthService _authService;
  late BookingService _bookingService;
  late CategoryService _categoryService;
  late TechnicianService _technicianService;
  late TechnicianKycService _technicianKycService;
  late UserService _userService;
  late NotificationService _notificationService;
  late ConsultationService _consultationService;
  late CallLogService _callLogService;
  late UploadService _uploadService;
  late AIService _aiService;
  late PaymentService _paymentService;
  late AddressService _addressService;
  late ReviewService _reviewService;
  late LocaleProvider _localeProvider;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _localeProvider = LocaleProvider()..loadSavedLocale();
  }

  void _initializeServices() {
    const secureStorage = FlutterSecureStorage();
    _httpClient = HttpClient(secureStorage: secureStorage);
    _authService = AuthService(httpClient: _httpClient, secureStorage: secureStorage);
    _bookingService = BookingService(httpClient: _httpClient);
    _categoryService = CategoryService(httpClient: _httpClient);
    _technicianService = TechnicianService(httpClient: _httpClient);
    _technicianKycService = TechnicianKycService(httpClient: _httpClient);
    _userService = UserService(httpClient: _httpClient);
    _notificationService = NotificationService(httpClient: _httpClient);
    _consultationService = ConsultationService(httpClient: _httpClient);
    _callLogService = CallLogService(httpClient: _httpClient);
    _uploadService = UploadService(httpClient: _httpClient);
    _aiService = AIService(httpClient: _httpClient);
    _paymentService = PaymentService(httpClient: _httpClient);
    _addressService = AddressService(httpClient: _httpClient);
    _reviewService = ReviewService(httpClient: _httpClient);

    // Wire up FCM token registration: whenever Firebase issues a new token,
    // send it to the backend.
    app.fcmNotificationService.onTokenRefreshed = (token) {
      _registerFcmToken(_httpClient);
    };

    // `fcmNotificationService.initialize()` (called from main() before runApp())
    // already fetches the initial token — but at that point onTokenRefreshed
    // above wasn't wired up yet, so that first token was never sent to the
    // backend. Register it now if it's already available; otherwise the
    // onTokenRefreshed callback above will handle it once the token arrives.
    if (app.fcmNotificationService.fcmToken != null) {
      _registerFcmToken(_httpClient);
    }

    // Wire up notification tap: open that exact notification's message,
    // with a shortcut to the booking when the payload has a booking_id.
    // A chat message push ("New message" / type: booking_message, sent by
    // BookingService.SendMessage) is the one case that should skip the
    // generic detail screen entirely and land straight in that same chat
    // thread, matching what a normal messaging app does on tap.
    app.fcmNotificationService.onNotificationTap = (payload) {
      final title = (payload['title'] as String?) ?? 'HomeFix';
      final body = (payload['body'] as String?) ?? '';
      debugPrint('[FCM Navigate] title=$title body=$body payload=$payload');

      final type = payload['type'] as String?;
      final bookingId = payload['booking_id'] as String?;
      if (type == 'booking_message' && bookingId != null && bookingId.isNotEmpty) {
        final peerName = (payload['sender_name'] as String?)?.trim();
        app.navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => BookingChatScreen(
            bookingId: bookingId,
            peerName: (peerName != null && peerName.isNotEmpty) ? peerName : 'Chat',
          ),
        ));
        return;
      }

      app.navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(title: title, body: body, data: payload),
      ));
    };

    // Wire up incoming consultation requests: ring immediately (like a real
    // incoming call) and jump the technician straight to the
    // accept/decline screen — whether the app was already open on some
    // other screen, in the background, or freshly launched from the tap.
    // The ring itself keeps looping until IncomingConsultationScreen's own
    // pending-list sync takes over (or stops it once the list empties out
    // after accept/reject) — see incoming_consultation_screen.dart.
    app.fcmNotificationService.onIncomingConsultation = (payload) {
      debugPrint('[FCM] Incoming consultation request: $payload');
      FlutterRingtonePlayer().playRingtone(looping: true, volume: 1.0, asAlarm: false);
      app.navigatorKey.currentState?.pushNamed('/consultation-requests');
    };

    // Wire up an "Audio Call" about an active booking — either side
    // (technician or customer) may have started it (see
    // BookingService.InitiateCall on the backend), so this fires for
    // whichever one is on the receiving end: ring, fetch ICE servers +
    // confirm we're actually a participant (see BookingService.getCallInfo
    // -> GET /bookings/:id/call), then jump straight into the audio-only
    // call screen — the receiver shouldn't have to tap anything to answer,
    // same as the consultation flow above, just going directly to the call
    // instead of a request-list screen since there's nothing to
    // accept/decline here.
    app.fcmNotificationService.onIncomingBookingCall = (payload) async {
      debugPrint('[FCM] Incoming booking audio call: $payload');
      final bookingId = payload['booking_id'] as String?;
      if (bookingId == null) return;

      final navContext = app.navigatorKey.currentState?.context;
      if (navContext == null) return;

      FlutterRingtonePlayer().playRingtone(looping: true, volume: 1.0, asAlarm: false);

      try {
        final callInfo = await _bookingService.getCallInfo(bookingId);
        // Two awaits already happened above (or are about to) — the navigator
        // can unmount in that gap (screen popped, app backgrounded and torn
        // down, etc). Using a stale context after that throws a FlutterError,
        // so re-check .mounted after every await before touching navContext.
        if (!navContext.mounted) {
          FlutterRingtonePlayer().stop();
          return;
        }
        final token = await navContext.read<AuthProvider>().getValidAccessToken();
        if (!navContext.mounted) {
          FlutterRingtonePlayer().stop();
          return;
        }
        final myId = navContext.read<AuthProvider>().currentUser?.id ?? '';

        if (token == null) {
          FlutterRingtonePlayer().stop();
          return;
        }

        final signaling = SignalingService(
          serverUrl: ApiConfig.wsCallUrl(bookingId, token),
          userId: myId,
          isDirectUrl: true,
        );
        signaling.connect();

        FlutterRingtonePlayer().stop();
        if (!navContext.mounted) return;
        app.navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            signaling: signaling,
            myId: myId,
            peerId: bookingId, // room only ever has 2 sockets — exact id unused by the relay
            isCaller: false,
            audioOnly: true,
            iceServers: callInfo.iceServers,
            // The push payload only ever carries ONE of these two fields —
            // whichever name matches who's actually calling (see
            // BookingService.InitiateCall) — so it tells us unambiguously
            // whose name to show, unlike callInfo which always has both
            // (a booking always has both a customer and a technician).
            peerDisplayName: (payload['technician_name'] as String?) ??
                (payload['customer_name'] as String?),
          ),
        ));
      } catch (e) {
        debugPrint('[FCM] Failed to join booking call: $e');
        FlutterRingtonePlayer().stop();
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService: _authService)
            ..onAuthenticated = () => _registerFcmToken(_httpClient),
        ),
        ChangeNotifierProvider<LocaleProvider>.value(value: _localeProvider),
        ChangeNotifierProvider(
          create: (_) => BookingProvider(bookingService: _bookingService),
        ),
        Provider<BookingService>.value(value: _bookingService),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(categoryService: _categoryService),
        ),
        ChangeNotifierProvider(
          create: (_) => TechnicianProvider(technicianService: _technicianService),
        ),
        ChangeNotifierProvider(
          create: (_) => NearbyTechnicianProvider(technicianService: _technicianService),
        ),
        ChangeNotifierProvider(
          create: (_) => TechnicianKycProvider(kycService: _technicianKycService),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(userService: _userService),
        ),
        Provider<NotificationService>.value(value: _notificationService),
        ChangeNotifierProvider(
          create: (_) => ConsultationProvider(consultationService: _consultationService),
        ),
        ChangeNotifierProvider(
          create: (_) => CallLogProvider(service: _callLogService),
        ),
        Provider<UploadService>.value(value: _uploadService),
        Provider<AIService>.value(value: _aiService),
        ChangeNotifierProvider(
          create: (_) => AIProvider(aiService: _aiService),
        ),
        ChangeNotifierProvider(
          create: (_) => PaymentProvider(paymentService: _paymentService),
        ),
        ChangeNotifierProvider(
          create: (_) => AddressProvider(addressService: _addressService),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationProvider(locationService: LocationService()),
        ),
        Provider<ReviewService>.value(value: _reviewService),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) => MaterialApp(
          navigatorKey: app.navigatorKey,
          title: 'HomeFix Live',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          locale: localeProvider.locale,
          supportedLocales: LocaleProvider.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Splash decides where to go next (checks stored tokens), then navigates
          // via these named routes — do not remove any of them or splash will crash.
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/home': (context) => const HomeScreen(),
            '/technician-kyc': (context) => const TechnicianKycScreen(),
            '/technician-status': (context) => const TechnicianStatusScreen(),
            '/technician-home': (context) => TechnicianJobsScreen(key: TechnicianJobsScreen.globalKey),
            '/consultation-requests': (context) => const IncomingConsultationScreen(),
          },
        ),
      ),
    );
  }
}