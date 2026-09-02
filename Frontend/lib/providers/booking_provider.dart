import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService;

  List<Booking> _bookings = [];
  Booking? _selectedBooking;
  List<BookingStatusHistory> _history = [];
  List<RepeatCustomer> _repeatCustomers = [];
  List<RepeatTechnician> _repeatTechnicians = [];
  List<ServiceHistoryEntry> _serviceHistory = [];
  bool _isLoading = false;
  bool _isLoadingRepeatCustomers = false;
  bool _isLoadingRepeatTechnicians = false;
  bool _isLoadingServiceHistory = false;
  String? _error;

  BookingProvider({required BookingService bookingService}) : _bookingService = bookingService;

  List<Booking> get bookings => _bookings;
  Booking? get selectedBooking => _selectedBooking;
  List<BookingStatusHistory> get history => _history;
  List<RepeatCustomer> get repeatCustomers => _repeatCustomers;
  List<RepeatTechnician> get repeatTechnicians => _repeatTechnicians;
  List<ServiceHistoryEntry> get serviceHistory => _serviceHistory;
  bool get isLoading => _isLoading;
  bool get isLoadingRepeatCustomers => _isLoadingRepeatCustomers;
  bool get isLoadingRepeatTechnicians => _isLoadingRepeatTechnicians;
  bool get isLoadingServiceHistory => _isLoadingServiceHistory;
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

  /// Technician side — "My Customers". Customers who have booked this
  /// technician more than once. `technicianId` is the technician RECORD id
  /// (TechnicianProfile.id), not the user id.
  Future<void> fetchRepeatCustomers(String technicianId) async {
    _isLoadingRepeatCustomers = true;
    _error = null;
    notifyListeners();

    try {
      _repeatCustomers = await _bookingService.getRepeatCustomers(technicianId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingRepeatCustomers = false;
      notifyListeners();
    }
  }

  /// Customer side — technicians the logged-in customer has booked more than
  /// once, for the "My Technicians" screen.
  Future<void> fetchRepeatTechnicians() async {
    _isLoadingRepeatTechnicians = true;
    _error = null;
    notifyListeners();

    try {
      _repeatTechnicians = await _bookingService.getRepeatTechnicians();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingRepeatTechnicians = false;
      notifyListeners();
    }
  }

  /// Customer side — every past booking with a specific (repeat) technician.
  /// Reached by tapping a technician on the "My Technicians" screen. Reuses
  /// the same _serviceHistory/isLoadingServiceHistory state as the
  /// technician-side fetchServiceHistory, since only one such screen is ever
  /// open at a time.
  Future<void> fetchMyServiceHistoryWithTechnician(String technicianId) async {
    _isLoadingServiceHistory = true;
    _error = null;
    notifyListeners();

    try {
      _serviceHistory = await _bookingService.getMyServiceHistoryWithTechnician(technicianId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingServiceHistory = false;
      notifyListeners();
    }
  }

  /// A specific customer's past bookings with this technician (with pricing/tier
  /// info) — reached by tapping a customer on the "My Customers" screen.
  Future<void> fetchServiceHistory(String technicianId, String customerId) async {
    _isLoadingServiceHistory = true;
    _error = null;
    notifyListeners();

    try {
      _serviceHistory = await _bookingService.getServiceHistory(technicianId, customerId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingServiceHistory = false;
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
      _currentEstimate = await _bookingService.getLatestEstimate(bookingId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Pending Job Brief ---
  // Transient holder that carries the guided-question answers (+ AI
  // diagnosis / consultation notes once available) from IssueDetailsScreen /
  // AIDiagnosisScreen through to BookTechnicianScreen, without threading a
  // new constructor param through every screen in that chain. Set as the
  // customer answers guided questions; read + cleared once actually used in
  // [createBooking] (via the `notes` param below) so it never leaks into an
  // unrelated later booking.
  JobBrief? _pendingJobBrief;
  JobBrief? get pendingJobBrief => _pendingJobBrief;
  void setPendingJobBrief(JobBrief brief) => _pendingJobBrief = brief;
  void updatePendingJobBrief(JobBrief Function(JobBrief current) update) {
    _pendingJobBrief = update(_pendingJobBrief ?? const JobBrief());
  }

  List<String> _pendingJobBriefImages = const [];
  List<String> get pendingJobBriefImages => _pendingJobBriefImages;
  void setPendingJobBriefImages(List<String> urls) => _pendingJobBriefImages = urls;

  void clearPendingJobBrief() {
    _pendingJobBrief = null;
    _pendingJobBriefImages = const [];
  }

  Future<Booking> createBooking({
    required String categoryId,
    required String addressId,
    String? problemDescription,
    String? notes,
    List<String>? images,
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
        notes: notes,
        images: images,
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
      notifyListeners();
    }
  }

  /// Customer cancels a booking that hasn't started yet (see the backend's
  /// own guard — already in_progress/completed/cancelled bookings are
  /// rejected with a clear error message in [_error]). Rather than dropping
  /// the booking from the list, it's refreshed in place so it shows up as
  /// "Cancelled" — same as Uber keeps a cancelled trip in your history
  /// instead of hiding it. Returns true on success so callers can drive a
  /// confirmation snackbar / dialog.
  Future<bool> cancelBooking(String bookingId, String reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _bookingService.cancelBooking(bookingId, reason);
      _error = null;
      final idx = _bookings.indexWhere((b) => b.id == bookingId);
      final refreshed = await _bookingService.getBookingDetail(bookingId);
      if (idx != -1) {
        _bookings[idx] = refreshed;
      }
      if (_selectedBooking?.id == bookingId) {
        _selectedBooking = refreshed;
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
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
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _selectedBooking = await _bookingService.getBookingDetail(bookingId);
      _bookings[idx] = _selectedBooking!;
    }
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// Technician taps "I've arrived" — backend generates an OTP and sends it to
/// the customer only. Goes through the same generic status-update endpoint
/// as every other status transition (PATCH /bookings/:id/status) — there is
/// no separate "/arrived" endpoint on the backend (BookingService.markArrived
/// used to call one that doesn't exist, which is why the button silently did
/// nothing). Refreshes the selected/local booking so the technician side
/// re-renders into the "arrived, waiting for OTP" state.
Future<void> markArrived(String bookingId, String technicianId) async {
  await updateBookingStatus(bookingId, 'arrived', note: 'Technician has arrived');
}

/// Technician submits the OTP the customer read out to them. Returns true on
/// success (wrong/expired OTP surfaces via [error] and returns false so the
/// UI can show an inline message without throwing).
Future<bool> verifyArrivalOtp(String bookingId, String technicianId, String otp) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    await _bookingService.verifyArrivalOtp(bookingId, technicianId, otp);
    _error = null;
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _selectedBooking = await _bookingService.getBookingDetail(bookingId);
      _bookings[idx] = _selectedBooking!;
    }
    return true;
  } catch (e) {
    _error = e.toString();
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

Future<void> completeBooking(
  String bookingId,
  double finalPrice, {
  bool warrantyEnabled = false,
  int? warrantyDays,
}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    await _bookingService.completeBooking(bookingId, finalPrice, warrantyEnabled: warrantyEnabled, warrantyDays: warrantyDays);
    _error = null;
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _selectedBooking = await _bookingService.getBookingDetail(bookingId);
      _bookings[idx] = _selectedBooking!;
    }
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// Customer taps "Claim Warranty" on a completed booking still within its
/// warranty window. On success, the new claim booking is prepended to the
/// list so it shows up immediately without a full refresh.
Future<bool> raiseWarrantyClaim(String bookingId, {String note = ''}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();
  try {
    final claim = await _bookingService.raiseWarrantyClaim(bookingId, note: note);
    _bookings.insert(0, claim);
    _error = null;
    return true;
  } catch (e) {
    _error = e.toString();
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

// --- Physical Inspection -> Estimate -> Approval ---

BookingEstimate? _currentEstimate;
List<BookingEstimate> _estimateHistory = [];
bool _isLoadingEstimate = false;

BookingEstimate? get currentEstimate => _currentEstimate;
List<BookingEstimate> get estimateHistory => _estimateHistory;
bool get isLoadingEstimate => _isLoadingEstimate;

/// Loads the most recent estimate for a booking (any status) — call this
/// whenever a booking detail screen opens so the estimate card can render
/// alongside the normal tracking view.
Future<void> fetchLatestEstimate(String bookingId) async {
  _isLoadingEstimate = true;
  notifyListeners();

  try {
    _currentEstimate = await _bookingService.getLatestEstimate(bookingId);
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoadingEstimate = false;
    notifyListeners();
  }
}

/// Full negotiation history for a booking (every submitted estimate).
Future<void> fetchEstimateHistory(String bookingId) async {
  _isLoadingEstimate = true;
  notifyListeners();

  try {
    _estimateHistory = await _bookingService.listEstimates(bookingId);
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoadingEstimate = false;
    notifyListeners();
  }
}

/// Technician submits a labour+parts estimate after inspecting the job.
/// Returns true on success; on failure [error] is set and the UI can show
/// it inline without a throw.
Future<bool> submitEstimate({
  required String bookingId,
  required String technicianId,
  required List<BookingEstimateItem> items,
  String? note,
}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    _currentEstimate = await _bookingService.submitEstimate(
      bookingId: bookingId,
      technicianId: technicianId,
      items: items,
      note: note,
    );
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _selectedBooking = await _bookingService.getBookingDetail(bookingId);
      _bookings[idx] = _selectedBooking!;
    }
    return true;
  } catch (e) {
    _error = e.toString();
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// Customer approves or declines the currently pending estimate. Returns
/// true on success.
Future<bool> respondToEstimate({
  required String bookingId,
  required String estimateId,
  required String action, // 'approve' | 'decline'
  String? note,
}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    await _bookingService.respondToEstimate(
      bookingId: bookingId,
      estimateId: estimateId,
      action: action,
      note: note,
    );
    _currentEstimate = await _bookingService.getLatestEstimate(bookingId);
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _selectedBooking = await _bookingService.getBookingDetail(bookingId);
      _bookings[idx] = _selectedBooking!;
    }
    return true;
  } catch (e) {
    _error = e.toString();
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

// --- Before/After job proof photos ---

List<BookingJobPhoto> _jobPhotos = [];
bool _isLoadingJobPhotos = false;

List<BookingJobPhoto> get jobPhotos => _jobPhotos;
List<BookingJobPhoto> get beforePhotos => _jobPhotos.where((p) => p.isBefore).toList();
List<BookingJobPhoto> get afterPhotos => _jobPhotos.where((p) => p.isAfter).toList();
bool get isLoadingJobPhotos => _isLoadingJobPhotos;

/// Loads every before/after photo for a booking — call whenever a booking
/// detail/tracking screen opens so the gallery can render alongside status.
Future<void> fetchJobPhotos(String bookingId) async {
  _isLoadingJobPhotos = true;
  notifyListeners();

  try {
    _jobPhotos = await _bookingService.listJobPhotos(bookingId);
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoadingJobPhotos = false;
    notifyListeners();
  }
}

/// Technician attaches a before/after proof photo. The file must already be
/// uploaded (see UploadService.uploadFile) — this just records its URL
/// against the booking. Returns true on success.
Future<bool> addJobPhoto({
  required String bookingId,
  required String photoType, // 'before' | 'after'
  required String imageUrl,
  String? caption,
}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final photo = await _bookingService.addJobPhoto(
      bookingId: bookingId,
      photoType: photoType,
      imageUrl: imageUrl,
      caption: caption,
    );
    _jobPhotos = [..._jobPhotos, photo];
    return true;
  } catch (e) {
    _error = e.toString();
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
}