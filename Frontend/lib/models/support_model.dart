// General "Contact Support" live chat message — reachable from the Profile
// screen, talking directly to HomeFix support, not tied to any specific
// booking/dispute (see DisputeMessage in dispute_model.dart for that
// booking-scoped equivalent).
class SupportMessage {
  final String id;
  final String userId;
  final String senderRole; // user | admin
  final String message;
  final String? attachmentUrl;
  final String? attachmentType; // image | video
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.userId,
    required this.senderRole,
    required this.message,
    this.attachmentUrl,
    this.attachmentType,
    required this.createdAt,
  });

  bool get isFromSupport => senderRole == 'admin';
  bool get hasImage => attachmentType == 'image' && attachmentUrl != null;
  bool get hasVideo => attachmentType == 'video' && attachmentUrl != null;

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      senderRole: json['sender_role'] as String? ?? 'user',
      message: json['message'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}