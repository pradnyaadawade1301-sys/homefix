// Category Service
import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../core/http_client.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../models/ai_model.dart';
import '../models/payment_model.dart';

class CategoryService {
  final HttpClient _httpClient;

  CategoryService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<List<Category>> getCategories() async {
    try {
      final response = await _httpClient.get(ApiConfig.categoriesList);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// Payment Service — UPI/GPay intent flow (create order -> app launches upi_uri ->
// customer confirms in-app after paying).
class PaymentService {
  final HttpClient _httpClient;

  PaymentService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<UpiOrder> createOrder(String bookingId, double amount) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.paymentOrders,
        data: {'booking_id': bookingId, 'amount': amount},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return UpiOrder.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// [upiStatus]/[upiResponseCode]/[upiApprovalRef] must come straight from the UPI
  /// app's OWN response to the launched intent (see PaymentScreen — upi_india's
  /// UpiResponse), never something the client invents: the backend only marks a
  /// payment (and its booking) paid when upiStatus == "SUCCESS" and rejects
  /// anything else (see UpiService.ConfirmPayment).
  Future<Payment> confirm(
    String transactionRef, {
    String? upiTxnId,
    required String upiStatus,
    String? upiResponseCode,
    String? upiApprovalRef,
    String method = 'upi',
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.paymentConfirm,
        data: {
          'transaction_ref': transactionRef,
          if (upiTxnId != null && upiTxnId.isNotEmpty) 'upi_txn_id': upiTxnId,
          'upi_status': upiStatus,
          if (upiResponseCode != null) 'upi_response_code': upiResponseCode,
          if (upiApprovalRef != null) 'upi_approval_ref': upiApprovalRef,
          'method': method,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Payment.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> markFailed(String transactionRef) async {
    try {
      await _httpClient.post(ApiConfig.paymentFail, data: {'transaction_ref': transactionRef});
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<List<Payment>> history() async {
    try {
      final response = await _httpClient.get(ApiConfig.paymentHistory);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// Technician KYC Service — authenticated: file upload, profile registration, own profile.
class TechnicianKycService {
  final HttpClient _httpClient;

  TechnicianKycService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Uploads a single file (government ID or profile photo) and returns its public URL.
  Future<String> uploadFile(File file) async {
    try {
      final filename = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: filename),
      });
      final response = await _httpClient.post(ApiConfig.uploads, data: formData);
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return data['url'] as String;
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Submits the technician KYC profile. Starts as approval_status = "pending".
  Future<TechnicianProfile> register({
    required String categoryId,
    required int experienceYears,
    required String address,
    required String governmentIdUrl,
    required String profilePhotoUrl,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.technicianRegister,
        data: {
          'category_id': categoryId,
          'experience_years': experienceYears,
          'address': address,
          'government_id_url': governmentIdUrl,
          'profile_photo_url': profilePhotoUrl,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return TechnicianProfile.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Fetches the logged-in technician's own profile, or null if they haven't
  /// submitted KYC yet (backend returns 404).
  Future<TechnicianProfile?> getMyProfile() async {
    try {
      final response = await _httpClient.get(ApiConfig.technicianMe);
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return TechnicianProfile.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(ApiEnvelope.errorMessage(e));
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// Technician Service — public browse endpoints, no auth required.
class TechnicianService {
  final HttpClient _httpClient;

  TechnicianService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<List<Technician>> getTechnicians({String? categoryId}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.techniciansList,
        queryParameters: {
          if (categoryId != null) 'category_id': categoryId,
        },
      );
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Technician.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<Technician> getTechnicianDetail(String technicianId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.technicianDetail}/$technicianId');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Technician.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Authenticated endpoint powering the nearby-technicians map/tracking screen.
  /// Pass the customer's current lat/lng to get results sorted nearest-first with a
  /// distance_km; omitted, the backend falls back to rating-first with no distance.
  Future<List<TechnicianNearby>> getAvailableNearby({
    required String categoryId,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.technicianAvailable,
        queryParameters: {
          'category_id': categoryId,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => TechnicianNearby.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// User Service
class UserService {
  final HttpClient _httpClient;

  UserService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<User> getProfile() async {
    try {
      final response = await _httpClient.get(ApiConfig.userProfile);
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return User.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _httpClient.put(ApiConfig.userProfile, data: data);
      final body = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return User.fromJson(body);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// Notification Service
class NotificationService {
  final HttpClient _httpClient;

  NotificationService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<List> getNotifications() async {
    try {
      final response = await _httpClient.get(ApiConfig.notificationsList);
      return ApiEnvelope.unwrap(response) as List? ?? [];
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _httpClient.patch('${ApiConfig.notificationsMarkRead}/$notificationId/read');
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// Address Service — GET/POST /users/me/addresses. Used by the "Book Technician"
// flow to let the customer pick a saved address or add a new one.
class AddressService {
  final HttpClient _httpClient;

  AddressService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<List<Address>> listAddresses() async {
    try {
      final response = await _httpClient.get(ApiConfig.userAddresses);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Address.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<Address> addAddress({
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.userAddresses,
        data: {
          'label': label,
          'line1': line1,
          if (line2 != null && line2.isNotEmpty) 'line2': line2,
          'city': city,
          'state': state,
          'pincode': pincode,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'is_default': isDefault,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Address.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// Generic file upload — POST /uploads (multipart, field "file"), returns the
// public URL. Shared by issue-report images, technician KYC, etc.
class UploadService {
  final HttpClient _httpClient;

  UploadService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<String> uploadFile(File file) async {
    try {
      final filename = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: filename),
      });
      final response = await _httpClient.post(ApiConfig.uploads, data: formData);
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return data['url'] as String;
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}

// AI Diagnosis Service — chat-based triage backed by Groq (see
// homefix_backend/internal/service/groq_service.go). Real API calls, no
// canned responses; requires a valid GROQ_API_KEY on the backend .env.
class AIService {
  final HttpClient _httpClient;

  AIService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<AIDiagnosisSession> startSession({String? categoryId}) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.aiSessions,
        data: {if (categoryId != null) 'category_id': categoryId},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return AIDiagnosisSession.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<String> sendMessage(String sessionId, String message) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.aiSessions}/$sessionId/messages',
        data: {'message': message},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return data['reply'] as String;
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<List<AIDiagnosisMessage>> history(String sessionId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.aiSessions}/$sessionId/messages');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => AIDiagnosisMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Uploads a recorded voice note and returns the transcribed text (via Groq
  /// Whisper on the backend — see internal/service/groq_service.go
  /// TranscribeAudio). Used by the Issue Details screen's voice recording button.
  Future<String> transcribeAudio(File audioFile) async {
    try {
      final filename = audioFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFile.path, filename: filename),
      });
      final response = await _httpClient.post(ApiConfig.aiTranscribe, data: formData);
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return data['text'] as String;
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}