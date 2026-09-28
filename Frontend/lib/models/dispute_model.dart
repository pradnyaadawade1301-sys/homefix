// Dispute-related models.
//
// IMPORTANT: field names kept in exact sync with backend JSON
// (see homefix_backend/internal/admin/admin.go — Dispute, DisputeEvidence).

class Dispute {
  final String id;
  final String? bookingId;
  final String? consultationId;
  final String raisedBy;
  final String reason;
  final String status; // open | under_review | resolved_refund | resolved_partial | resolved_rejected
  final double? refundAmount;
  final String? adminNotes;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? raisedByName;

  Dispute({
    required this.id,
    this.bookingId,
    this.consultationId,
    required this.raisedBy,
    required this.reason,
    required this.status,
    this.refundAmount,
    this.adminNotes,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.raisedByName,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: json['id'] as String? ?? '',
      bookingId: json['booking_id'] as String?,
      consultationId: json['consultation_id'] as String?,
      raisedBy: json['raised_by'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      adminNotes: json['admin_notes'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      raisedByName: json['raised_by_name'] as String?,
    );
  }

  bool get isResolved => status.startsWith('resolved');
}

class DisputeEvidence {
  final String id;
  final String disputeId;
  final String uploadedBy;
  final String fileUrl;
  final String? note;
  final DateTime createdAt;

  DisputeEvidence({
    required this.id,
    required this.disputeId,
    required this.uploadedBy,
    required this.fileUrl,
    this.note,
    required this.createdAt,
  });

  factory DisputeEvidence.fromJson(Map<String, dynamic> json) {
    return DisputeEvidence(
      id: json['id'] as String? ?? '',
      disputeId: json['dispute_id'] as String? ?? '',
      uploadedBy: json['uploaded_by'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// One message in the live-chat thread attached to a dispute — the
/// customer/technician talking directly to HomeFix support, separate from
/// the one-shot reason + evidence. senderRole is "user" (customer/tech) or
/// "admin" (support); attachmentUrl/attachmentType are set when the message
/// is (or includes) a photo or video instead of just text.
class DisputeMessage {
  final String id;
  final String disputeId;
  final String? senderId;
  final String senderRole; // user | admin
  final String message;
  final String? attachmentUrl;
  final String? attachmentType; // image | video
  final DateTime createdAt;
  final String? senderName;

  DisputeMessage({
    required this.id,
    required this.disputeId,
    this.senderId,
    required this.senderRole,
    required this.message,
    this.attachmentUrl,
    this.attachmentType,
    required this.createdAt,
    this.senderName,
  });

  bool get isFromSupport => senderRole == 'admin';
  bool get hasImage => attachmentType == 'image' && attachmentUrl != null;
  bool get hasVideo => attachmentType == 'video' && attachmentUrl != null;

  factory DisputeMessage.fromJson(Map<String, dynamic> json) {
    return DisputeMessage(
      id: json['id'] as String? ?? '',
      disputeId: json['dispute_id'] as String? ?? '',
      senderId: json['sender_id'] as String?,
      senderRole: json['sender_role'] as String? ?? 'user',
      message: json['message'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      senderName: json['sender_name'] as String?,
    );
  }
}

/// GET /disputes/:id returns {"dispute": ..., "evidence": [...]}.
class DisputeDetail {
  final Dispute dispute;
  final List<DisputeEvidence> evidence;

  DisputeDetail({required this.dispute, required this.evidence});

  factory DisputeDetail.fromJson(Map<String, dynamic> json) {
    return DisputeDetail(
      dispute: Dispute.fromJson(json['dispute'] as Map<String, dynamic>),
      evidence: (json['evidence'] as List? ?? [])
          .map((e) => DisputeEvidence.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}