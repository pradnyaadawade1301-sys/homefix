import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/http_client.dart';
import 'core/theme.dart';
import 'providers/address_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/category_provider.dart';
import 'providers/consultation_provider.dart';
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
import 'services/consultation_service.dart';
import 'services/location_service.dart';
import 'services/service_locator.dart';
import 'screens/technician/technician_jobs_screen.dart';
import 'screens/notifications/notification_detail_screen.dart';
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
  late UploadService _uploadService;
  late AIService _aiService;
  late PaymentService _paymentService;
  late AddressService _addressService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
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
    _uploadService = UploadService(httpClient: _httpClient);
    _aiService = AIService(httpClient: _httpClient);
    _paymentService = PaymentService(httpClient: _httpClient);
    _addressService = AddressService(httpClient: _httpClient);

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
    app.fcmNotificationService.onNotificationTap = (payload) {
      final title = (payload['title'] as String?) ?? 'HomeFix';
      final body = (payload['body'] as String?) ?? '';
      debugPrint('[FCM Navigate] title=$title body=$body payload=$payload');
      app.navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(title: title, body: body, data: payload),
      ));
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
      ],
      child: MaterialApp(
        navigatorKey: app.navigatorKey,
        title: 'HomeFix Live',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
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
          '/technician-home': (context) => const TechnicianJobsScreen(),
          '/consultation-requests': (context) => const IncomingConsultationScreen(),
        },
      ),
    );
  }
}