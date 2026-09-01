import 'package:flutter/material.dart';
import '../models/ai_model.dart';
import '../services/service_locator.dart';

/// Drives the AI Diagnosis chat screen. One session per "issue report" —
/// created with the chosen category, then the customer and the AI exchange
/// messages until the customer decides to book a technician or start a live
/// consultation.
class AIProvider extends ChangeNotifier {
  final AIService _aiService;

  AIProvider({required AIService aiService}) : _aiService = aiService;

  AIDiagnosisSession? _session;
  List<AIDiagnosisMessage> _messages = [];
  bool _isSending = false;
  bool _isStarting = false;
  String? _error;

  AIDiagnosisSession? get session => _session;
  List<AIDiagnosisMessage> get messages => _messages;
  bool get isSending => _isSending;
  bool get isStarting => _isStarting;
  String? get error => _error;

  /// Starts a new session and immediately sends the customer's issue
  /// title+description as the opening message, so the AI has real context
  /// (matches spec step 4: "Send issue details ... to the Groq AI service").
  /// [displayText], if given, is shown in the chat bubble instead of
  /// [issueSummary] — used so attachment URLs sent to the AI don't clutter
  /// what the customer sees.
  Future<void> startWithIssue({
    String? categoryId,
    required String issueSummary,
    String? displayText,
  }) async {
    _isStarting = true;
    _error = null;
    _messages = [];
    notifyListeners();

    try {
      _session = await _aiService.startSession(categoryId: categoryId);
      _error = null;
      await sendMessage(issueSummary, displayText: displayText);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  /// Sends [message] to the AI. If [displayText] is given, it's shown in the
  /// chat bubble instead of [message] — used so attachment URLs sent to the
  /// AI don't clutter what the customer sees.
  Future<void> sendMessage(String message, {String? displayText}) async {
    final session = _session;
    if (session == null || message.trim().isEmpty) return;

    _isSending = true;
    _error = null;
    // Optimistically show the user's message immediately.
    _messages = [
      ..._messages,
      AIDiagnosisMessage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        sessionId: session.id,
        role: 'user',
        content: displayText ?? message,
        createdAt: DateTime.now(),
      ),
    ];
    notifyListeners();

    try {
      final reply = await _aiService.sendMessage(session.id, message);
      _messages = [
        ..._messages,
        AIDiagnosisMessage(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}-r',
          sessionId: session.id,
          role: 'assistant',
          content: reply,
          createdAt: DateTime.now(),
        ),
      ];
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void reset() {
    _session = null;
    _messages = [];
    _error = null;
    notifyListeners();
  }
}