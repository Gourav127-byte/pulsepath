import '../../../core/activity/activity_metric.dart';
import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../models/backend_goal.dart';

class GoalsRepository {
  const GoalsRepository(this._apiClient, [this._cache]);

  final ApiClient _apiClient;
  final TemporaryDemoCache? _cache;

  Future<List<BackendGoal>> fetchGoals() async {
    List<Map<String, dynamic>> response;
    try {
      response = await _apiClient.getJsonList('/goals');
      final goals = _parseAndSort(response);
      await _cache?.saveGoals(response);
      return goals;
    } on NetworkException {
      final cached = await _cache?.loadGoals();
      if (cached == null) rethrow;
      return _parseAndSort(cached);
    }
  }

  List<BackendGoal> _parseAndSort(List<Map<String, dynamic>> response) {
    final goals = response.map(BackendGoal.fromJson).toList();
    goals.sort(
      (left, right) => ActivityMetricType.values
          .indexOf(left.type)
          .compareTo(ActivityMetricType.values.indexOf(right.type)),
    );
    return goals;
  }

  Future<BackendGoal> updateGoalTarget({
    required String goalId,
    required double targetValue,
  }) async {
    final response = await _apiClient.patchJson('/goals/$goalId', {
      'target_value': targetValue,
    });
    return BackendGoal.fromJson(response);
  }

  Future<BackendGoal> createGoal({
    required ActivityMetricType type,
    required double targetValue,
  }) async {
    final response = await _apiClient.postJson('/goals', {
      'type': _backendType(type),
      'target_value': targetValue,
    });
    return BackendGoal.fromJson(response);
  }

  Future<void> deleteGoal(String goalId) {
    return _apiClient.delete('/goals/$goalId');
  }

  String _backendType(ActivityMetricType type) {
    return switch (type) {
      ActivityMetricType.steps => 'steps',
      ActivityMetricType.distance => 'distance',
      ActivityMetricType.activeMinutes => 'active_minutes',
      ActivityMetricType.calories => 'calories',
    };
  }
}
