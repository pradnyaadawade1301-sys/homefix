import '../config/api_config.dart';
import '../core/http_client.dart';
import '../models/consultation_model.dart';

/// Wraps the backend's `/consultations` group (see ApiConfig for the exact
/// endpoint list). The backend owns technician matching, WebRTC signaling
/// room/ICE config, duration billing and payment capture — this class is a
/// thin REST wrapper only.
class ConsultationService {
  final HttpClient _httpClient;

  ConsultationService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Customer: kicks off a new consultation request. Backend starts matching
  /// a technician and returns status "searching".
     Future<Consultation> requestConsultation({
    required String categoryId,
    required String categoryName,
    String? note,
    String? area,
    String? aiDiagnosisSessionId,
    String? preferredTechnicianId,
    DateTime? scheduledAt,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.consultationRequest,
        data: {
          'category_id': categoryId,
          'category_name': categoryName,
          if (note != null && note.isNotEmpty) 'note': note,
          if (area != null && area.isNotEmpty) 'area': area,
          if (aiDiagnosisSessionId != null && aiDiagnosisSessionId.isNotEmpty) 'ai_diagnosis_session_id': aiDiagnosisSessionId,
          if (preferredTechnicianId != null) 'preferred_technician_id': preferredTechnicianId,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Consultation.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
  /// Poll while status == searching/pending.
  Future<Consultation> getStatus(String id) async {
    try {
      final response = await _httpClient.get('${ApiConfig.consultationStatus}/$id');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Consultation.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician: accepts a pending consultation request.
  Future<Consultation> accept(String id) async {
    try {
      final response = await _httpClient.post('${ApiConfig.consultationAccept}/$id/accept');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Consultation.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician: declines a pending (instant/ringing) consultation request.
  /// [reason] is optional free text explaining why — shown to the customer.
  Future<void> reject(String id, {String? reason}) async {
    try {
      await _httpClient.post(
        '${ApiConfig.consultationReject}/$id/reject',
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer: cancels their own request while still searching.
  Future<void> cancel(String id) async {
    try {
      await _httpClient.post('${ApiConfig.consultationCancel}/$id/cancel');
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Once accepted, fetches room_id + ice_servers needed to open the WebRTC
  /// call (see ApiConfig.wsCallUrl). Backend shape is expected to be either
  /// `{consultation: {...}, room_id, ice_servers}` or those fields flattened
  /// directly onto the consultation object — both are handled here.
  Future<Consultation> getCallInfo(String id) async {
    try {
      final response = await _httpClient.get('${ApiConfig.consultationCall}/$id/call');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final consultationJson = (data['consultation'] as Map<String, dynamic>?) ?? data;
      final merged = <String, dynamic>{
        ...consultationJson,
        if (data['room_id'] != null) 'room_id': data['room_id'],
        if (data['ice_servers'] != null) 'ice_servers': data['ice_servers'],
      };
      return Consultation.fromJson(merged);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> end(String id, {required int durationSeconds, required double amount}) async {
    try {
      await _httpClient.post(
        '${ApiConfig.consultationEnd}/$id/end',
        data: {'duration_seconds': durationSeconds, 'amount': amount},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  Future<void> rate(String id, {required int rating, String? comment}) async {
    try {
      await _httpClient.post(
        '${ApiConfig.consultationRating}/$id/rating',
        data: {'rating': rating, if (comment != null) 'comment': comment},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician: consultation requests currently awaiting their response.
  Future<List<ConsultationRequest>> getPending() async {
    try {
      final response = await _httpClient.get(ApiConfig.consultationPending);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => ConsultationRequest.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer: their own past consultations (video calls), most recent first —
  /// powers the call-history screen.
  Future<List<Consultation>> getMine() async {
    try {
      final response = await _httpClient.get(ApiConfig.consultationMine);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Consultation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician: sends a simple post-call recommendation (problem summary +
  /// optional suggested price) so the customer can Accept (-> Escalate,
  /// creates a booking) or Decline it.
  Future<Consultation> recommendOnsite(String id, {required String summary, double? price}) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.consultationOnsite}/$id/recommend-onsite',
        data: {'summary': summary, if (price != null) 'price': price},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Consultation.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer: declines the technician's post-call recommendation — no
  /// booking is created.
  Future<void> declineRecommendation(String id) async {
    try {
      await _httpClient.post('${ApiConfig.consultationRecommendDecline}/$id/recommend-onsite/decline');
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Customer: turns a finished consultation into a real booking (optionally
  /// with a scheduled date/time slot) for the same technician — this is the
  /// "on-site visit" / "book a slot" step after a video call.
  Future<void> escalate(
    String id, {
    required String addressId,
    String? problemDescription,
    String? notes,
    DateTime? scheduledAt,
  }) async {
    try {
      await _httpClient.post(
        '${ApiConfig.consultationEscalate}/$id/escalate',
        data: {
          'address_id': addressId,
          if (problemDescription != null) 'problem_description': problemDescription,
          if (notes != null) 'notes': notes,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

    /// Technician: confirms holding a scheduled slot (status scheduled -> confirmed).
  Future<Consultation> confirmScheduled(String id) async {
    try {
      final response = await _httpClient.post('${ApiConfig.consultationConfirmScheduled}/$id/confirm-scheduled');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Consultation.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician: declines a scheduled slot ahead of time. [reason] is optional
  /// free text explaining why — shown to the customer instead of a bare
  /// "declined" status.
  Future<void> declineScheduled(String id, {String? reason}) async {
    try {
      await _httpClient.post(
        '${ApiConfig.consultationDeclineScheduled}/$id/decline-scheduled',
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// Technician: their upcoming (scheduled/confirmed) consultations.
  Future<List<Consultation>> getUpcoming() async {
    try {
      final response = await _httpClient.get(ApiConfig.consultationUpcoming);
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Consultation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}