class ApiConfig {
  // Backend Base URL - matches homefix_backend router (internal/router/router.go)
  // NOTE: backend is mapped to host port 8090 (see docker-compose.yml), not 8080,
  // to avoid clashing with other local projects.
  // Running on a REAL Android device over Wi-Fi: phone and PC must be on the same
  // network. Update the IP below any time your PC's Wi-Fi IP changes (check via
  // `ipconfig` -> IPv4 Address under your active Wi-Fi adapter).
static const String baseUrl = 'http://192.168.1.8:8090/api/v1';  // static const String baseUrl = 'https://api.homefixlive.com/api/v1'; // Production

  // Auth endpoints (backend: internal/router/router.go -> auth group)
  static const String authSignup = '/auth/signup';
  static const String authLogin = '/auth/login';
  static const String authRequestOtp = '/auth/request-otp';
  static const String authVerifyOtp = '/auth/verify-otp';
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