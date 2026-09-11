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