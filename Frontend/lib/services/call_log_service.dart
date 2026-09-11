import '../config/api_config.dart';
import '../core/http_client.dart';
import '../models/call_log_model.dart';

/// Wraps GET /calls/history — the real call log (see internal/handler/call_log_handler.go).
class CallLogService {
  final HttpClient _httpClient;

  CallLogService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<List<CallLogEntry>> getHistory() async {
    try {
      final response = await _httpClient.get(ApiConfig.callHistory);
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final list = (data['calls'] as List?) ?? [];
      return list.map((e) => CallLogEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(ApiEnvelope.errorMessage(e));
    }
  }
}