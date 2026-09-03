import '../core/http_client.dart';
import '../models/dispute_model.dart';

/// Customer/technician-facing dispute calls — raise, list mine, detail, add
/// evidence. Resolution is admin-only (hidden /admin panel), not exposed here.
class DisputeService {
  final HttpClient _httpClient;

  DisputeService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// POST /disputes. Exactly one of bookingId/consultationId must be set —
  /// matches raiseDisputeBody on the backend.
  Future<Dispute> raise({
    String? bookingId,
    String? consultationId,
    required String reason,
  }) async {
    try {
      final response = await _httpClient.post(
        '/disputes',
        data: {
          if (bookingId != null) 'booking_id': bookingId,
          if (consultationId != null) 'consultation_id': consultationId,
          'reason': reason,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return Dispute.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// GET /disputes/me — every dispute the logged-in user has raised.
  Future<List<Dispute>> listMine() async {
    try {
      final response = await _httpClient.get('/disputes/me');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => Dispute.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// GET /disputes/:id — dispute + its evidence list.
  Future<DisputeDetail> getDetail(String disputeId) async {
    try {
      final response = await _httpClient.get('/disputes/$disputeId');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return DisputeDetail.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// POST /disputes/:id/evidence. Upload the file separately via
  /// UploadService.uploadFile first, then pass the returned URL here.
  Future<DisputeEvidence> addEvidence({
    required String disputeId,
    required String fileUrl,
    String? note,
  }) async {
    try {
      final response = await _httpClient.post(
        '/disputes/$disputeId/evidence',
        data: {
          'file_url': fileUrl,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return DisputeEvidence.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}