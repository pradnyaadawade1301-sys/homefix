import '../core/http_client.dart';
import '../models/support_model.dart';

/// General "Contact Support" live chat — POST/GET /support/messages. Not
/// scoped to any booking/dispute, unlike DisputeService's chat methods.
class SupportService {
  final HttpClient _httpClient;

  SupportService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// GET /support/messages — the logged-in user's own thread with support.
  /// Poll this while the chat screen is open.
  Future<List<SupportMessage>> listMessages() async {
    try {
      final response = await _httpClient.get('/support/messages');
      final list = ApiEnvelope.unwrap(response) as List? ?? [];
      return list.map((e) => SupportMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }

  /// POST /support/messages. To send a photo/video, upload the file first
  /// via UploadService.uploadFile, then pass the returned URL here as
  /// [attachmentUrl] with [attachmentType] "image" or "video". [message]
  /// can be left empty for an attachment-only message.
  Future<SupportMessage> sendMessage({
    String message = '',
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      final response = await _httpClient.post(
        '/support/messages',
        data: {
          'message': message,
          if (attachmentUrl != null) 'attachment_url': attachmentUrl,
          if (attachmentType != null) 'attachment_type': attachmentType,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return SupportMessage.fromJson(data);
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}