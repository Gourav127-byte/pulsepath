import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../models/activity_history_entry.dart';
import '../models/activity_insights.dart';

class ActivityHistoryRepository {
  const ActivityHistoryRepository(this._apiClient, [this._cache]);

  final ApiClient _apiClient;
  final TemporaryDemoCache? _cache;

  Future<List<ActivityHistoryEntry>> fetchHistory({required int days}) async {
    if (days != 7 && days != 30) {
      throw ArgumentError.value(
        days,
        'days',
        'Only 7 or 30 days are supported',
      );
    }
    try {
      final response = await _apiClient.getJsonList(
        '/activity/history?days=$days',
      );
      await _cache?.saveHistory(days, response);
      return response.map(ActivityHistoryEntry.fromJson).toList();
    } on NetworkException {
      final cached = await _cache?.loadHistory(days);
      if (cached != null) {
        return cached.map(ActivityHistoryEntry.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<ActivityInsights> fetchInsights({required int days}) async {
    if (days != 7 && days != 30) {
      throw ArgumentError.value(
        days,
        'days',
        'Only 7 or 30 days are supported',
      );
    }
    final response = await _apiClient.getJson('/activity/insights?days=$days');
    return ActivityInsights.fromJson(response);
  }
}
