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

  /// Technician updates job progress — PATCH /bookings/:id/status.
  /// status: accepted | in_progress | completed | cancelled
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
}