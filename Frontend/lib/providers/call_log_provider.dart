import 'package:flutter/material.dart';

import '../models/call_log_model.dart';
import '../services/call_log_service.dart';

/// Backs the real Call History list — used by both the customer's Consult >
/// Call tab and the technician's History > Call tab.
class CallLogProvider extends ChangeNotifier {
  final CallLogService _service;

  CallLogProvider({required CallLogService service}) : _service = service;

  List<CallLogEntry> _calls = [];
  bool _isLoading = false;
  String? _error;

  List<CallLogEntry> get calls => _calls;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// This booking's calls only, oldest first — used by the booking chat to
  /// show "Voice call"/"Video call" rows inline. Doesn't touch the shared
  /// list/loading state, so it's safe to call from a polling timer.
  Future<List<CallLogEntry>> callsForBooking(String bookingId) async {
    final all = await _service.getHistory();
    final list = all.where((c) => c.bookingId == bookingId).toList();
    list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return list;
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _calls = await _service.getHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}