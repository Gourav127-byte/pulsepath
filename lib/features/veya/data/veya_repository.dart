import '../../../core/network/api_client.dart';
import '../models/veya_foundation.dart';

class VeyaRepository {
  final ApiClient _apiClient;

  VeyaRepository(this._apiClient);

  Future<VeyaFoundationResponse> fetchFoundation({int days = 7}) async {
    final response = await _apiClient.getJson('/veya/foundation?days=$days');
    return VeyaFoundationResponse.fromJson(response);
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    int rangeDays = 7,
  }) async {
    final response = await _apiClient.postJson(
      '/veya/chat',
      {
        'message': message,
        'range_days': rangeDays,
      },
    );
    return response;
  }
}
