/// One real audio-call attempt, as returned by GET /calls/history — a proper
/// phone-style call log entry: who it was with, when, and whether it was
/// picked up. Used by both the customer's Consult > Call tab and the
/// technician's History > Call tab (same endpoint, scoped to whoever is
/// logged in).
enum CallLogStatus { ringing, received, missed, rejected }

CallLogStatus _statusFromString(String s) {
  switch (s) {
    case 'received':
      return CallLogStatus.received;
    case 'missed':
      return CallLogStatus.missed;
    case 'rejected':
      return CallLogStatus.rejected;
    default:
      return CallLogStatus.ringing;
  }
}

class CallLogEntry {
  final String id;
  final String? bookingId;
  final String? consultationId;
  final String peerName;
  final String peerRole; // "technician" or "customer"
  final String categoryName;
  final bool isOutgoing;
  final CallLogStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  CallLogEntry({
    required this.id,
    this.bookingId,
    this.consultationId,
    required this.peerName,
    required this.peerRole,
    required this.categoryName,
    required this.isOutgoing,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds,
  });

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    return CallLogEntry(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString(),
      consultationId: json['consultation_id']?.toString(),
      peerName: (json['peer_name'] as String?) ?? '',
      peerRole: (json['peer_role'] as String?) ?? '',
      categoryName: (json['category_name'] as String?) ?? '',
      isOutgoing: json['is_outgoing'] == true,
      status: _statusFromString(json['status'] as String? ?? 'ringing'),
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      answeredAt: json['answered_at'] != null ? DateTime.parse(json['answered_at'] as String).toLocal() : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String).toLocal() : null,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  bool get isMissed => status == CallLogStatus.missed;
}