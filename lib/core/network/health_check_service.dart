import 'api_client.dart';

class HealthCheckService {
  const HealthCheckService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> checkHealth() async {
    final response = await _apiClient.getJson('/health');
    if (response['status'] != 'ok') {
      throw const NetworkException('Backend reported an unhealthy status.');
    }
  }
}
