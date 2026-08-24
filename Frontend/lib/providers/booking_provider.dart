import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService;

  List<Booking> _bookings = [];
  Booking? _selectedBooking;
  List<BookingStatusHistory> _history = [];
  bool _isLoading = false;
  String? _error;

  BookingProvider({required BookingService bookingService}) : _bookingService = bookingService;

  List<Booking> get bookings => _bookings;
  Booking? get selectedBooking => _selectedBooking;
  List<BookingStatusHistory> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Customer side — "My Bookings". Each booking includes the assigned
  /// technician's details once one is assigned.
  Future<void> fetchUserBookings({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bookings = await _bookingService.getUserBookings(status: status);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Technician side — "My Jobs". `technicianId` is the technician RECORD id
  /// (TechnicianProfile.id), not the user id. Each booking includes the
  /// customer's name/phone and the job address.
  Future<void> fetchTechnicianBookings(String technicianId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bookings = await _bookingService.getTechnicianBookings(technicianId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBookingDetail(String bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedBooking = await _bookingService.getBookingDetail(bookingId);
      _history = await _bookingService.getBookingHistory(bookingId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Booking> createBooking({
    required String categoryId,
    required String addressId,
    String? problemDescription,
    DateTime? scheduledAt,
    String? preferredTechnicianId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final booking = await _bookingService.createBooking(
        categoryId: categoryId,
        addressId: addressId,
        problemDescription: problemDescription,
        scheduledAt: scheduledAt,
        technicianId: preferredTechnicianId,
      );
      _bookings.insert(0, booking);
      _error = null;
      notifyListeners();
      return booking;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _bookingService.cancelBooking(bookingId, reason);
      _bookings.removeWhere((b) => b.id == bookingId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Technician accepts a "requested" job.
  Future<void> acceptBooking(String bookingId, String technicianId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _bookingService.acceptBooking(bookingId, technicianId);
      _error = null;
      await fetchTechnicianBookings(technicianId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Technician moves a job forward: in_progress, etc.
  Future<void> updateBookingStatus(String bookingId, String status, {String? note}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _bookingService.updateBookingStatus(bookingId, status, note: note);
      _error = null;
      await fetchBookingDetail(bookingId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeBooking(String bookingId, double finalPrice) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _bookingService.completeBooking(bookingId, finalPrice);
      _error = null;
      await fetchBookingDetail(bookingId);
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
}