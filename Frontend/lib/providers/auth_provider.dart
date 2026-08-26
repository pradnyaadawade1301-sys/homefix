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

  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
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

  /// Signup with name/phone/password, optional email, and role (customer/technician).
  Future<bool> signup({
    required String name,
    required String phone,
    required String password,
    String? email,
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
    } catch (e) {
      _isLoggedIn = false;
    }
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