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

  /// GET /disputes/:id/messages — the live-chat thread with support.
  /// Poll this while the chat screen is open.
  Future<List<DisputeMessage>> listMessages(String disputeId) async {
    try {
      final response = await _httpClient.get('/disputes/$disputeId/messages');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => DisputeMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// POST /disputes/:id/messages. To send a photo/video, upload the file
  /// first via UploadService.uploadFile, then pass the returned URL here as
  /// [attachmentUrl] with [attachmentType] "image" or "video". [message] can
  /// be left empty for an attachment-only message.
  Future<DisputeMessage> sendMessage({
    required String disputeId,
    String message = '',
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      final response = await _httpClient.post(
        '/disputes/$disputeId/messages',
        data: {
          'message': message,
          if (attachmentUrl != null) 'attachment_url': attachmentUrl,
          if (attachmentType != null) 'attachment_type': attachmentType,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return DisputeMessage.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}