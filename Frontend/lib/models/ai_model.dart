// AI diagnosis chat models — match homefix_backend/internal/models/ai_notification.go
// (AIDiagnosisSession, AIDiagnosisMessage) exactly.

class AIDiagnosisSession {
  final String id;
  final String userId;
  final String? bookingId;
  final String? categoryId;
  final String status;
  final DateTime createdAt;

  AIDiagnosisSession({
    required this.id,
    required this.userId,
    this.bookingId,
    this.categoryId,
    required this.status,
    required this.createdAt,
  });

  factory AIDiagnosisSession.fromJson(Map<String, dynamic> json) {
    return AIDiagnosisSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookingId: json['booking_id'] as String?,
      categoryId: json['category_id'] as String?,
      status: (json['status'] as String?) ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AIDiagnosisMessage {
  final String id;
  final String sessionId;
  final String role; // "user" | "assistant"
  final String content;
  final DateTime createdAt;

  AIDiagnosisMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory AIDiagnosisMessage.fromJson(Map<String, dynamic> json) {
    return AIDiagnosisMessage(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}