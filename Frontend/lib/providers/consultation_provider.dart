import 'package:flutter/material.dart';
import '../models/consultation_model.dart';
import '../services/consultation_service.dart';

/// State for the Live Video Consultation flow, on both the customer side
/// (request -> searching -> accepted -> in_call) and the technician side
/// (pending requests list -> accept/reject -> call info).
class ConsultationProvider extends ChangeNotifier {
  final ConsultationService _consultationService;

  ConsultationProvider({required ConsultationService consultationService})
      : _consultationService = consultationService;

  // --- Technician: pending requests -----------------------------------
  List<ConsultationRequest> _pendingRequests = [];
  bool _isLoadingPending = false;

  List<ConsultationRequest> get pendingRequests => _pendingRequests;
  bool get isLoadingPending => _isLoadingPending;

  // --- Customer: current consultation (search/status) -------------------
  Consultation? _current;
  bool _isLoading = false;
  String? _error;

  Consultation? get current => _current;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Technician: refresh the pending-requests list and update listeners.
  /// Used by [IncomingConsultationScreen] via RefreshIndicator / Consumer.
  Future<void> loadPending() async {
    _isLoadingPending = true;
    notifyListeners();
    try {
      _pendingRequests = await _consultationService.getPending();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  /// Technician: same fetch as [loadPending], but also returns the list
  /// directly — used for lightweight background polling (e.g. the jobs
  /// dashboard banner) that keeps its own local copy instead of listening
  /// to [pendingRequests] via Consumer.
  Future<List<ConsultationRequest>> fetchPendingRequests() async {
    try {
      final requests = await _consultationService.getPending();
      _pendingRequests = requests;
      _error = null;
      notifyListeners();
      return requests;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Technician: accept a pending request. Updates [current] with the
  /// accepted consultation (status flips to accepted on the backend).
  Future<Consultation> acceptRequest(String consultationId) async {
    try {
      final consultation = await _consultationService.accept(consultationId);
      _current = consultation;
      _pendingRequests = _pendingRequests.where((r) => r.consultationId != consultationId).toList();
      _error = null;
      notifyListeners();
      return consultation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Technician: decline a pending (instant/ringing) request. [reason] is
  /// optional free text explaining why — shown to the customer.
  Future<void> rejectRequest(String consultationId, {String? reason}) async {
    try {
      await _consultationService.reject(consultationId, reason: reason);
      _pendingRequests = _pendingRequests.where((r) => r.consultationId != consultationId).toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch room_id + ICE servers needed to open the WebRTC call screen.
  Future<Consultation> getCallInfo(String consultationId) async {
    try {
      final consultation = await _consultationService.getCallInfo(consultationId);
      _current = consultation;
      notifyListeners();
      return consultation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // --- Customer: request / poll / cancel a consultation ------------------

  /// Customer: kick off a new consultation request. Backend starts matching
  /// a technician; resulting status is typically "searching".
  Future<Consultation> requestConsultation({
    required String categoryId,
    required String categoryName,
    String? note,
    String? preferredTechnicianId,
    DateTime? scheduledAt,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final consultation = await _consultationService.requestConsultation(
        categoryId: categoryId,
        categoryName: categoryName,
        note: note,
        preferredTechnicianId: preferredTechnicianId,
        scheduledAt: scheduledAt,
      );
      _current = consultation;
      _error = null;
      return consultation;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Customer: poll while status == searching/pending.
  Future<Consultation> refreshStatus(String consultationId) async {
    try {
      final consultation = await _consultationService.getStatus(consultationId);
      _current = consultation;
      _error = null;
      notifyListeners();
      return consultation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Customer: cancel their own request while still searching.
  Future<void> cancelRequest(String consultationId) async {
    try {
      await _consultationService.cancel(consultationId);
      if (_current?.id == consultationId) {
        _current = _current!.copyWith(status: ConsultationStatus.cancelled);
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Called when the call ends (either side) to report duration + amount for
  /// billing, then clears the local error state.
  Future<void> endCall(String consultationId, {required int durationSeconds, required double amount}) async {
    try {
      await _consultationService.end(consultationId, durationSeconds: durationSeconds, amount: amount);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> rateConsultation(String consultationId, {required int rating, String? comment}) async {
    try {
      await _consultationService.rate(consultationId, rating: rating, comment: comment);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // --- Customer: consultation call history -------------------------------
  List<Consultation> _history = [];
  bool _isLoadingHistory = false;

  List<Consultation> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;

  /// Customer: fetch past video consultations for the history screen.
  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _history = await _consultationService.getMine();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Customer: convert a finished consultation into a real (optionally
  /// scheduled) booking with the same technician.
  Future<void> escalateToBooking(
    String consultationId, {
    required String addressId,
    String? problemDescription,
    String? notes,
    DateTime? scheduledAt,
  }) async {
    try {
      await _consultationService.escalate(
        consultationId,
        addressId: addressId,
        problemDescription: problemDescription,
        notes: notes,
        scheduledAt: scheduledAt,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearCurrent() {
    _current = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // --- Technician: upcoming scheduled consultations -----------------------
  List<Consultation> _upcoming = [];
  bool _isLoadingUpcoming = false;

  List<Consultation> get upcoming => _upcoming;
  bool get isLoadingUpcoming => _isLoadingUpcoming;

  /// Technician: refresh the upcoming (scheduled/confirmed) list and update
  /// listeners. Used by [UpcomingConsultationsScreen] via RefreshIndicator /
  /// Consumer.
  Future<void> loadUpcoming() async {
    _isLoadingUpcoming = true;
    notifyListeners();
    try {
      _upcoming = await _consultationService.getUpcoming();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingUpcoming = false;
      notifyListeners();
    }
  }

  /// Technician: same fetch as [loadUpcoming], but also returns the list
  /// directly — used for lightweight background polling (e.g. the jobs
  /// dashboard banner) that keeps its own local copy instead of listening
  /// to [upcoming] via Consumer. Mirrors [fetchPendingRequests].
  Future<List<Consultation>> fetchUpcomingList() async {
    try {
      final list = await _consultationService.getUpcoming();
      _upcoming = list;
      _error = null;
      notifyListeners();
      return list;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> confirmScheduled(String consultationId) async {
    try {
      await _consultationService.confirmScheduled(consultationId);
      _upcoming = _upcoming.map((c) => c.id == consultationId ? c.copyWith(status: ConsultationStatus.confirmed) : c).toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Technician: decline a scheduled slot ahead of time. [reason] is optional
  /// free text explaining why — shown to the customer.
  Future<void> declineScheduled(String consultationId, {String? reason}) async {
    try {
      await _consultationService.declineScheduled(consultationId, reason: reason);
      _upcoming = _upcoming.where((c) => c.id != consultationId).toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}