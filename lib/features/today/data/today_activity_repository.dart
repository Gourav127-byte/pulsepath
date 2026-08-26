import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../services/health_connect_service.dart';
import '../models/today_activity.dart';
import '../models/daily_score_explanation.dart';
import '../models/activity_streak.dart';
import '../models/activity_engagement.dart';

class TodayActivityRepository {
  const TodayActivityRepository(
    this._apiClient, [
    this._cache,
    this._now = DateTime.now,
  ]);

  final ApiClient _apiClient;
  final TemporaryDemoCache? _cache;
  final DateTime Function() _now;

  Future<TodayActivity> fetchTodayActivity() async {
    try {
      final response = await _apiClient.getJson('/activity/today');
      final activity = TodayActivity.fromJson(response);
      await _cache?.saveToday(response);
      return activity;
    } on NetworkException {
      final cached = await _cache?.loadToday();
      if (cached != null) {
        final activity = TodayActivity.fromJson(cached);
        final today = _now();
        if (activity.date.year == today.year &&
            activity.date.month == today.month &&
            activity.date.day == today.day) {
          return activity;
        }
      }
      rethrow;
    }
  }

  Future<TodayActivity> updateTodayActivity({
    double? steps,
    double? activeMinutes,
    double? calories,
    double? distance,
    String source = 'manual',
    bool resetStepsToAuto = false,
    bool resetDistanceToAuto = false,
    bool resetCaloriesToAuto = false,
  }) async {
    final body = <String, Object?>{'source': source};
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

    if (resetStepsToAuto) body['reset_steps_to_auto'] = true;
    if (resetDistanceToAuto) body['reset_distance_to_auto'] = true;
    if (resetCaloriesToAuto) body['reset_calories_to_auto'] = true;

    print(
      '[VALIDATION_GATE][CHECKPOINT_5] TodayActivityRepository payload sent to FastAPI: $body',
    );

    final response = await _apiClient.patchJson('/activity/today', body);
    return TodayActivity.fromJson(response);
  }

  Future<void> syncTimelineSamples({
    required DateTime date,
    required List<StepSampleRecord> samples,
  }) async {
    if (samples.isEmpty) return;
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final payload = {
      'date': dateStr,
      'samples': samples.map((s) => s.toJson()).toList(),
    };
    await _apiClient.postJson('/activity/timeline/sync', payload);
  }

  Future<DailyScoreExplanation> fetchScoreExplanation() async {
    final response = await _apiClient.getJson(
      '/activity/today/score-explanation',
    );
    return DailyScoreExplanation.fromJson(response);
  }

  Future<ActivityStreak> fetchStreak() async {
    final response = await _apiClient.getJson('/activity/streak');
    return ActivityStreak.fromJson(response);
  }

  Future<ActivityEngagement> fetchEngagement() async {
    final response = await _apiClient.getJson('/activity/engagement');
    return ActivityEngagement.fromJson(response);
  }
}
