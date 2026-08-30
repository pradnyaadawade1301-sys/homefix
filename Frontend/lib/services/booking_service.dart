import '../config/api_config.dart';
import '../core/http_client.dart';
import '../models/booking_model.dart';

class BookingService {
  final HttpClient _httpClient;

  BookingService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Creates a booking. Field names match createBookingBody in
  /// homefix_backend/internal/handler/booking_handler.go exactly.
  Future<Booking> createBooking({
    required String categoryId,
    required String addressId,
    String? technicianId,
    String? problemDescription,
    DateTime? scheduledAt,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.bookingCreate,
        data: {
          'category_id': categoryId,
          'address_id': addressId,
          if (technicianId != null) 'technician_id': technicianId,
          if (problemDescription != null) 'problem_description': problemDescription,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Booking.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer's own bookings — GET /bookings/me. Each booking carries the
  /// assigned technician's details (name/phone/rating) once one is assigned.
  Future<List<Booking>> getUserBookings({String? status}) async {
    try {
      final response = await _httpClient.get(ApiConfig.bookingList);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      final bookings = list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
      if (status == null) return bookings;
      return bookings.where((b) => b.status == status).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician's assigned jobs — GET /technicians/:id/bookings. Each booking
  /// carries the customer's name/phone and the job address. `technicianId` is
  /// the technician RECORD id (from TechnicianProfile.id / GET /technicians/me),
  /// not the user id.
  Future<List<Booking>> getTechnicianBookings(String technicianId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.technicianBookings}/$technicianId/bookings');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customers who have booked this technician more than once — GET
  /// /technicians/:id/repeat-customers. `technicianId` is the technician
  /// RECORD id (from TechnicianProfile.id / GET /technicians/me), not the user id.
  Future<List<RepeatCustomer>> getRepeatCustomers(String technicianId) async {
    try {
      final response = await _httpClient.get(
          '${ApiConfig.technicianRepeatCustomers}/$technicianId/repeat-customers');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => RepeatCustomer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// A specific customer's past bookings with this technician, with pricing/tier
  /// info attached — GET /technicians/:id/customers/:customerId/history. Reached
  /// by tapping a customer on the "My Customers" (repeat customers) screen.
  Future<List<ServiceHistoryEntry>> getServiceHistory(String technicianId, String customerId) async {
    try {
      final response = await _httpClient.get(
          '${ApiConfig.technicianRepeatCustomers}/$technicianId/customers/$customerId/history');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => ServiceHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer side — technicians the logged-in customer has booked more than
  /// once. GET /me/repeat-technicians (customer id comes from the JWT).
  Future<List<RepeatTechnician>> getRepeatTechnicians() async {
    try {
      final response = await _httpClient.get(ApiConfig.myRepeatTechnicians);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => RepeatTechnician.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer side — every past booking the logged-in customer has made with a
  /// specific technician (date, work/category, status, payment). Reached by
  /// tapping a technician on the "My Technicians" screen.
  /// GET /me/repeat-technicians/:technicianId/history.
  Future<List<ServiceHistoryEntry>> getMyServiceHistoryWithTechnician(String technicianId) async {
    try {
      final response =
          await _httpClient.get('${ApiConfig.myRepeatTechnicians}/$technicianId/history');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => ServiceHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<Booking> getBookingDetail(String bookingId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.bookingDetail}/$bookingId');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Booking.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<List<BookingStatusHistory>> getBookingHistory(String bookingId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.bookingDetail}/$bookingId/history');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => BookingStatusHistory.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Chat history for a booking — GET /bookings/:id/messages. Server checks
  /// the caller is either the booking's customer or its assigned technician.
  Future<List<BookingMessage>> getMessages(String bookingId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.bookingDetail}/$bookingId/messages');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => BookingMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Sends a chat message — POST /bookings/:id/messages.
  Future<BookingMessage> sendMessage(String bookingId, String content) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.bookingDetail}/$bookingId/messages',
        data: {'content': content},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return BookingMessage.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    try {
      await _httpClient.post(
        '${ApiConfig.bookingCancel}/$bookingId/cancel',
        data: {'reason': reason},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician accepts a requested booking — POST /bookings/:id/accept.
  Future<void> acceptBooking(String bookingId, String technicianId) async {
    try {
      await _httpClient.post(
        '${ApiConfig.bookingDetail}/$bookingId/accept',
        data: {'technician_id': technicianId},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician marks themselves as having reached the customer's location —
  /// POST /bookings/:id/arrived. Backend generates a fresh OTP and pushes it
  /// to the customer only; this call doesn't return the code itself.
  Future<void> markArrived(String bookingId, String technicianId) async {
    try {
      await _httpClient.post(
        '${ApiConfig.bookingDetail}/$bookingId/arrived',
        data: {'technician_id': technicianId},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician submits the OTP the customer read out to them — POST
  /// /bookings/:id/verify-otp. On success the booking moves to in_progress.
  Future<void> verifyArrivalOtp(String bookingId, String technicianId, String otp) async {
    try {
      await _httpClient.post(
        '${ApiConfig.bookingDetail}/$bookingId/verify-otp',
        data: {'technician_id': technicianId, 'otp': otp},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician updates job progress — PATCH /bookings/:id/status.
  /// status: accepted | on_the_way | in_progress | completed | cancelled
  Future<void> updateBookingStatus(String bookingId, String status, {String? note}) async {
    try {
      await _httpClient.patch(
        '${ApiConfig.bookingDetail}/$bookingId/status',
        data: {'status': status, if (note != null) 'note': note},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> completeBooking(String bookingId, double finalPrice) async {
    try {
      await _httpClient.post(
        '${ApiConfig.bookingComplete}/$bookingId/complete',
        data: {'final_price': finalPrice},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  // --- Physical Inspection -> Estimate -> Approval ---

  /// Technician submits a labour+parts estimate after inspecting the job on
  /// site — POST /bookings/:id/estimate. Moves the booking to
  /// awaiting_estimate_approval.
  Future<BookingEstimate> submitEstimate({
    required String bookingId,
    required String technicianId,
    required List<BookingEstimateItem> items,
    String? note,
  }) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.bookingDetail}/$bookingId/estimate',
        data: {
          'technician_id': technicianId,
          'items': items.map((i) => i.toRequestJson()).toList(),
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return BookingEstimate.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// The most recently submitted estimate for a booking (any status) — GET
  /// /bookings/:id/estimate. Powers both the customer's approval card and
  /// the technician's "estimate sent, waiting on customer" state.
  Future<BookingEstimate?> getLatestEstimate(String bookingId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.bookingDetail}/$bookingId/estimate');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>?;
      if (data == null) return null;
      return BookingEstimate.fromJson(data);
    } catch (e) {
      // No estimate submitted yet (404) is a normal, expected state — not an error.
      if (ApiEnvelope.errorMessage(e).toLowerCase().contains('no estimate')) return null;
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Full negotiation history for a booking (every estimate ever submitted,
  /// oldest first) — GET /bookings/:id/estimates.
  Future<List<BookingEstimate>> listEstimates(String bookingId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.bookingDetail}/$bookingId/estimates');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => BookingEstimate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer approves or declines a pending estimate — POST
  /// /bookings/:id/estimate/:estimateId/respond. Either way the booking
  /// returns to in_progress; `note` is the customer's reason on decline.
  Future<void> respondToEstimate({
    required String bookingId,
    required String estimateId,
    required String action, // 'approve' | 'decline'
    String? note,
  }) async {
    try {
      await _httpClient.post(
        '${ApiConfig.bookingDetail}/$bookingId/estimate/$estimateId/respond',
        data: {
          'action': action,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  // --- Before/After job proof photos ---
  //
  // The file itself is uploaded separately via UploadService.uploadFile
  // (POST /uploads, generic multipart -> {url}); these calls just attach
  // the resulting URL to the booking.

  /// Technician attaches a before/after proof photo — POST /bookings/:id/photos.
  Future<BookingJobPhoto> addJobPhoto({
    required String bookingId,
    required String photoType, // 'before' | 'after'
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.bookingDetail}/$bookingId/photos',
        data: {
          'photo_type': photoType,
          'image_url': imageUrl,
          if (caption != null && caption.isNotEmpty) 'caption': caption,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return BookingJobPhoto.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// All before/after photos for a booking, oldest first — GET /bookings/:id/photos.
  Future<List<BookingJobPhoto>> listJobPhotos(String bookingId) async {
    try {
      final response = await _httpClient.get('${ApiConfig.bookingDetail}/$bookingId/photos');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => BookingJobPhoto.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}