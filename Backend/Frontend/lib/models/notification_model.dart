class Notification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // booking, payment, system, chat
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      relatedId: json['related_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'related_id': relatedId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'data': data,
    };
  }
}

class ChatMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderType; // user, technician, ai
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final List<String>? attachments;

  ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.attachments,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      senderId: json['sender_id'] as String,
      senderType: json['sender_type'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false,
      attachments: List<String>.from(json['attachments'] as List? ?? []),
    );
  }
}

class DiagnosisResult {
  final String id;
  final String bookingId;
  final String issue;
  final List<String> suggestions;
  final double estimatedCost;
  final String severity; // low, medium, high
  final String? recommendation;
  final DateTime createdAt;

  DiagnosisResult({
    required this.id,
    required this.bookingId,
    required this.issue,
    required this.suggestions,
    required this.estimatedCost,
    required this.severity,
    this.recommendation,
    required this.createdAt,
  });

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) {
    return DiagnosisResult(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      issue: json['issue'] as String,
      suggestions: List<String>.from(json['suggestions'] as List? ?? []),
      estimatedCost: (json['estimated_cost'] as num).toDouble(),
      severity: json['severity'] as String,
      recommendation: json['recommendation'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
