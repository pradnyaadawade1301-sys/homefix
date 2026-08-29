import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  User? _currentUser;
  String? _accessToken;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  AuthProvider({required AuthService authService}) : _authService = authService;

  /// Called whenever the user becomes authenticated — fresh login, signup,
  /// or a restored session. Used to (re)register the FCM push token with the
  /// backend, since the very first token fetch on app start happens before
  /// the user is logged in and that registration call fails silently (401).
  void Function()? onAuthenticated;

  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;

  /// Guaranteed-fresh token — refreshes first if the cached one has expired.
  /// [accessToken] above is only set once at login/session-restore and never
  /// updated when the HTTP client silently refreshes it for REST calls, so
  /// it can go stale after ~15 minutes. Use this instead right before a
  /// one-shot handshake outside the normal REST flow, e.g. opening the
  /// /ws/call/:id WebSocket for a video call — otherwise the call can fail
  /// with a 401 even though every other screen in the app works fine.
  Future<String?> getValidAccessToken() async {
    final fresh = await _authService.getValidAccessToken();
    if (fresh != null && fresh != _accessToken) {
      _accessToken = fresh;
    }
    return _accessToken;
  }
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  /// Login with email OR phone (identifier) + password.
  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(identifier, password);
      _currentUser = response.user;
      _accessToken = response.accessToken;
      _isLoggedIn = true;
      _error = null;
      onAuthenticated?.call();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoggedIn = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signup with name/phone/password/email (required) and role (customer/technician).
  Future<bool> signup({
    required String name,
    required String phone,
    required String password,
    required String email,
    String role = 'customer',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.signup(
        name: name,
        phone: phone,
        password: password,
        email: email,
        role: role,
      );
      _currentUser = response.user;
      _accessToken = response.accessToken;
      _isLoggedIn = true;
      _error = null;
      onAuthenticated?.call();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoggedIn = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkLoginStatus() async {
    try {
      _isLoggedIn = await _authService.isLoggedIn();
      // isLoggedIn() only tells us a token exists in storage — it never
      // used to update _accessToken, so a restored session left it null
      // forever (until the next fresh login/signup call). Any screen that
      // read AuthProvider.accessToken directly — e.g. starting a video
      // call — would then fail with "Could not start/join the call" even
      // though every other REST call kept working fine.
      _accessToken = _isLoggedIn ? _authService.currentAccessToken : null;
      if (_isLoggedIn) onAuthenticated?.call();
    } catch (e) {
      _isLoggedIn = false;
      _accessToken = null;
    }
    notifyListeners();
  }

  /// Restores the in-memory user after a resumed session. SplashScreen calls
  /// this right after it fetches the profile via UserProvider — checkLoginStatus
  /// alone can't populate this since it only confirms the stored token exists.
  void setCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    try {
      await _authService.logout();
      _currentUser = null;
      _accessToken = null;
      _isLoggedIn = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Sends a 6-digit code to `email` for the post-signup verification step.
  /// Returns an error message on failure, or null on success.
  Future<String?> requestEmailOtp(String email) async {
    try {
      await _authService.requestEmailOtp(email);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Verifies the code sent by requestEmailOtp. Returns an error message on
  /// failure, or null on success. Also flips currentUser.emailVerified locally
  /// so the UI updates without a full profile refetch.
  Future<String?> verifyEmailOtp(String email, String otp) async {
    try {
      await _authService.verifyEmailOtp(email, otp);
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWithEmailVerified(true);
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}