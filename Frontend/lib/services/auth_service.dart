import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../core/http_client.dart';
import '../models/user_model.dart';

class AuthService {
  final HttpClient _httpClient;
  final FlutterSecureStorage _secureStorage;

  AuthService({
    required HttpClient httpClient,
    required FlutterSecureStorage secureStorage,
  })  : _httpClient = httpClient,
        _secureStorage = secureStorage;

  /// Login with email OR phone (identifier) + password.
  /// Backend: POST /auth/login { identifier, password }
  Future<AuthResponse> login(String identifier, String password) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.authLogin,
        data: {'identifier': identifier, 'password': password},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final authResponse = AuthResponse.fromJson(data);
      await _httpClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );
      return authResponse;
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Signup with name/email/phone/password/role ("customer" or "technician").
  /// Backend: POST /auth/signup { name, email, phone, password, role }
  Future<AuthResponse> signup({
    required String name,
    required String phone,
    required String password,
    String? email,
    String role = 'customer',
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.authSignup,
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'role': role,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final authResponse = AuthResponse.fromJson(data);
      await _httpClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );
      return authResponse;
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Phone OTP flow (backend: /auth/request-otp, /auth/verify-otp).
  Future<void> requestOtp(String phone) async {
    try {
      await _httpClient.post(ApiConfig.authRequestOtp, data: {'phone': phone});
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<AuthResponse> verifyOtp(String phone, String otp) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.authVerifyOtp,
        data: {'phone': phone, 'otp': otp},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final authResponse = AuthResponse.fromJson(data);
      await _httpClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );
      return authResponse;
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> logout() async {
    try {
      await _httpClient.clearTokens();
      await _secureStorage.deleteAll();
    } catch (e) {
      rethrow;
    }
  }

  /// Email-verification OTP flow, used right after signup (backend:
  /// /auth/request-email-otp, /auth/verify-email-otp). Separate from the phone
  /// OTP flow above — this only marks email_verified, it doesn't log the user in.
  Future<void> requestEmailOtp(String email) async {
    try {
      await _httpClient.post(ApiConfig.authRequestEmailOtp, data: {'email': email});
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> verifyEmailOtp(String email, String otp) async {
    try {
      await _httpClient.post(ApiConfig.authVerifyEmailOtp, data: {'email': email, 'otp': otp});
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      await _httpClient.loadStoredTokens();
      return _httpClient.getAccessToken() != null;
    } catch (e) {
      return false;
    }
  }
}