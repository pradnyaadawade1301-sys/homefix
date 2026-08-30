class ApiConfig {
  // Google Places / Geocoding API key.
  // Get one from https://console.cloud.google.com/ :
  //   1. Create/select a project.
  //   2. APIs & Services -> Library -> enable "Places API" AND "Geocoding API".
  //   3. APIs & Services -> Credentials -> Create Credentials -> API key.
  //   4. (Recommended) Restrict the key to Android/iOS app + the 2 APIs above.
  // Billing must be enabled on the project (Google gives $200/month free credit,
  // more than enough for an address-autocomplete feature).
  static const String googlePlacesApiKey = 'PASTE_YOUR_GOOGLE_PLACES_API_KEY_HERE';

  // Backend Base URL - matches homefix_backend router (internal/router/router.go)
  // NOTE: backend is mapped to host port 8090 (see docker-compose.yml), not 8080,
  // to avoid clashing with other local projects.
  // static const String baseUrl = 'http://192.168.1.19:8090/api/v1'; // Real device via LAN Wi-Fi
  // static const String baseUrl = 'http://10.0.2.2:8090/api/v1'; // Android emulator
  static const String baseUrl = 'https://homefix-b61f.onrender.com/api/v1'; // Render production

  // Auth endpoints (backend: internal/router/router.go -> auth group)
  static const String authSignup = '/auth/signup';
  static const String authLogin = '/auth/login';
  static const String authGoogleLogin = '/auth/google';
  static const String authRequestOtp = '/auth/request-otp';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authRequestEmailOtp = '/auth/request-email-otp';
  static const String authVerifyEmailOtp = '/auth/verify-email-otp';
  static const String authRefresh = '/auth/refresh';
  static const String authSetPassword = '/auth/set-password';
  static const String authLogout = '/auth/logout';

  static const String userProfile = '/users/me';
  static const String userAddresses = '/users/me/addresses';
  static const String userFcmToken = '/users/me/fcm-token';

  static const String categoriesList = '/categories';

  static const String techniciansList = '/technicians'; // public browse: ?category_id=
  static const String technicianDetail = '/technicians'; // + /:id
  static const String technicianRegister = '/technicians';
  static const String technicianMe = '/technicians/me';
  static const String technicianAvailable = '/technicians/available';
  static const String technicianBookings = '/technicians'; // + /:id/bookings
  static const String technicianReviews = '/technicians'; // + /:id/reviews
  static const String reviews = '/reviews';
  static const String technicianRepeatCustomers = '/technicians'; // + /:id/repeat-customers
  static const String myRepeatTechnicians = '/me/repeat-technicians';

  static const String uploads = '/uploads'; // POST multipart "file" -> {url}

  static const String bookingCreate = '/bookings';
  static const String bookingList = '/bookings/me';
  static const String bookingDetail = '/bookings'; // + /:id
  static const String bookingCancel = '/bookings'; // + /:id/cancel
  static const String bookingMessages = '/bookings'; // + /:id/messages
  static const String bookingComplete = '/bookings'; // + /:id/complete
  static const String bookingSchedule = '/bookings/schedule'; // not yet implemented backend-side

  static const String paymentOrders = '/payments/orders';
  static const String paymentConfirm = '/payments/confirm';
  static const String paymentFail = '/payments/fail';
  static const String paymentHistory = '/payments/history';
  static String paymentInvoice(String paymentId) => '/payments/$paymentId/invoice';

  static const String walletBalance = '/wallet';
  static const String walletTransactions = '/wallet/transactions';

  static const String notificationsList = '/notifications';
  static const String notificationsMarkRead = '/notifications'; // + /:id/read

  static const String aiSessions = '/ai/sessions';
  static const String aiTranscribe = '/ai/transcribe';
  // Live Video Consultation (true peer-to-peer WebRTC call — see README section
  // "Live Consultation" for the full flow). Backend owns technician matching,
  // WebRTC signaling relay + ICE server config, duration billing and payment
  // capture. Matches internal/router/router.go's `/consultations` group exactly.
  static const String consultationRequest = '/consultations/request'; // POST -> {id, status: searching}
  static const String consultationStatus = '/consultations'; // + /:id -> GET poll while searching
  static const String consultationAccept = '/consultations'; // + /:id/accept -> POST (technician)
  static const String consultationReject = '/consultations'; // + /:id/reject -> POST (technician)
  static const String consultationCancel = '/consultations'; // + /:id/cancel -> POST (customer, while searching)
  static const String consultationCall = '/consultations'; // + /:id/call -> GET {consultation, room_id, ice_servers}
  static const String consultationEnd = '/consultations'; // + /:id/end -> POST {status, duration_seconds, amount}
  static const String consultationOnsite = '/consultations'; // + /:id/recommend-onsite -> POST (not yet backed — see escalate)
  static const String consultationEscalate = '/consultations'; // + /:id/escalate -> POST {address_id, problem_description}
  static const String consultationPayment = '/consultations'; // + /:id/payment -> POST {payment_method}
  static const String consultationRating = '/consultations'; // + /:id/rating -> POST {rating, comment}
  static const String consultationPending = '/consultations/pending'; // GET (technician) - incoming requests
  static const String consultationMine = '/consultations/mine'; // GET (customer) - own call history

  // WebRTC signaling (peer-to-peer video/audio call handshake only — see
  // internal/handler/call_handler.go). Auth via ?token= query param since WebSocket
  // upgrades can't reliably carry custom headers on every platform.
  static const String wsCallBase = '/ws/call'; // + /:id?token=<accessToken>
  static const String webrtcIceServers = '/webrtc/ice-servers'; // GET {ice_servers}

  /// ws(s)://host/api/v1/ws/call/:id?token=... for the given consultation/booking id.
  static String wsCallUrl(String id, String accessToken) {
    final wsBase = baseUrl.replaceFirst('http', 'ws'); // http->ws, https->wss
    return '$wsBase$wsCallBase/$id?token=$accessToken';
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Firebase — matches google-services.json
  static const String firebaseProjectId = 'homefix-live';
  static const String firebaseMessagingSenderId = '299649646704';

}