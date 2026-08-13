import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../models/today_activity.dart';

class TodayActivityRepository {
  const TodayActivityRepository(this._apiClient, [this._cache]);

  final ApiClient _apiClient;
  final TemporaryDemoCache? _cache;

  Future<TodayActivity> fetchTodayActivity() async {
    try {
      final response = await _apiClient.getJson('/activity/today');
      final activity = TodayActivity.fromJson(response);
      await _cache?.saveToday(response);
      return activity;
    } on NetworkException {
      final cached = await _cache?.loadToday();
      if (cached != null) return TodayActivity.fromJson(cached);
      rethrow;
    }
  }

  Future<TodayActivity> updateTodayActivity({
    double? steps,
    double? activeMinutes,
    double? calories,
    double? distance,
  }) async {
    final body = <String, Object?>{};
    if (steps != null) {
      body['steps'] = steps;
    }
    if (activeMinutes != null) {
      body['active_minutes'] = activeMinutes;
    }
    if (calories != null) {
      body['calories'] = calories;
    }
    if (distance != null) {
      body['distance'] = distance;
    }
    final response = await _apiClient.patchJson('/activity/today', body);
    return TodayActivity.fromJson(response);
  }
}
