/// Status machine for a live video consultation.
///
/// searching -> ringing -> accepted -> in_call -> ended
///                   \-> rejected/no_technician (customer sees error, can retry)
/// in_call -> on_site_recommended -> booking_created
class ConsultationStatus {
  static const String searching = 'searching';
  static const String ringing = 'ringing'; // Backend assigned a technician, awaiting their accept/decline
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String noTechnician = 'no_technician';
  static const String inCall = 'in_call';
  static const String ended = 'ended';
  static const String cancelled = 'cancelled';
}

/// One ICE server entry for RTCPeerConnection config (STUN has no credentials;
/// TURN gets a fresh short-lived username/credential minted per call by the
/// backend — see GET /consultations/:id/call).
class IceServer {
  final List<String> urls;
  final String? username;
  final String? credential;

  IceServer({required this.urls, this.username, this.credential});

  factory IceServer.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    return IceServer(
      urls: rawUrls is List ? rawUrls.map((e) => e.toString()).toList() : [rawUrls.toString()],
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'urls': urls,
        if (username != null) 'username': username,
        if (credential != null) 'credential': credential,
      };
}

class Consultation {
  final String id;
  final String customerId;
  final String? technicianId;
  final String categoryId;
  final String categoryName;
  final String status;
  final String? roomId; // == id; the call's WebRTC signaling room (see ws/call/:id)
  final List<IceServer> iceServers;
  final String? customerName;
  final String? technicianName;
  final int estimatedDurationMinutes;
  final double consultationFee;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final double? amount;
  final String? paymentStatus; // pending | paid | failed
  final DateTime createdAt;

  Consultation({
    required this.id,
    required this.customerId,
    this.technicianId,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    this.roomId,
    this.iceServers = const [],
    this.customerName,
    this.technicianName,
    this.estimatedDurationMinutes = 15,
    this.consultationFee = 199,
    this.startTime,
    this.endTime,
    this.durationSeconds,
    this.amount,
    this.paymentStatus,
    required this.createdAt,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'] as String,
      customerId: json['customer_id'] as String? ?? '',
      technicianId: json['technician_id'] as String?,
      categoryId: json['category_id'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      status: json['status'] as String? ?? ConsultationStatus.searching,
      roomId: json['room_id'] as String? ?? json['id'] as String?,
      iceServers: (json['ice_servers'] as List?)
              ?.map((e) => IceServer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      customerName: json['customer_name'] as String?,
      technicianName: json['technician_name'] as String?,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int? ?? 15,
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ?? 199,
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time'] as String) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time'] as String) : null,
      durationSeconds: json['duration_seconds'] as int?,
      amount: (json['amount'] as num?)?.toDouble(),
      paymentStatus: json['payment_status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Consultation copyWith({
    String? status,
    String? roomId,
    List<IceServer>? iceServers,
    String? technicianId,
    String? technicianName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? amount,
    String? paymentStatus,
  }) {
    return Consultation(
      id: id,
      customerId: customerId,
      technicianId: technicianId ?? this.technicianId,
      categoryId: categoryId,
      categoryName: categoryName,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      iceServers: iceServers ?? this.iceServers,
      customerName: customerName,
      technicianName: technicianName ?? this.technicianName,
      estimatedDurationMinutes: estimatedDurationMinutes,
      consultationFee: consultationFee,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      amount: amount ?? this.amount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt,
    );
  }
}

/// A pending consultation request as seen by a technician (incoming call card).
class ConsultationRequest {
  final String consultationId;
  final String customerName;
  final String categoryName;
  final int estimatedDurationMinutes;
  final double consultationFee;
  final String? customerNote;

  ConsultationRequest({
    required this.consultationId,
    required this.customerName,
    required this.categoryName,
    required this.estimatedDurationMinutes,
    required this.consultationFee,
    this.customerNote,
  });

  factory ConsultationRequest.fromJson(Map<String, dynamic> json) {
    return ConsultationRequest(
      consultationId: json['consultation_id'] as String? ?? json['id'] as String,
      customerName: json['customer_name'] as String? ?? 'Customer',
      categoryName: json['category_name'] as String? ?? '',
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int? ?? 15,
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ?? 199,
      customerNote: json['customer_note'] as String?,
    );
  }
}