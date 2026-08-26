import '../services/health_connect_service.dart';
import 'today_activity_repository.dart';

class HealthSyncRepository {
  const HealthSyncRepository(this._healthService, this._activityRepository);

  final HealthConnectService _healthService;
  final TodayActivityRepository _activityRepository;

  Future<HealthSyncOutcome> sync() async {
    // Availability check should be done before calling sync,
    // but we double-check here.
    if (!await _healthService.isAvailable()) {
      return HealthSyncOutcome.unavailable;
    }

    final data = await _healthService.fetchDailyData();
    print(
      '[VALIDATION_GATE][CHECKPOINT_4] HealthSyncRepository sync fetched: '
      'steps=${data.steps}, distance=${data.distance}, calories=${data.calories}, timelineSamples=${data.timelineSamples.length}',
    );
    if (data.isEmpty) return HealthSyncOutcome.noData;

    if (data.timelineSamples.isNotEmpty) {
      try {
        await _activityRepository.syncTimelineSamples(
          date: DateTime.now(),
          samples: data.timelineSamples,
        );
      } catch (e) {
        print('[TIMELINE_ERROR] syncTimelineSamples failed: $e');
      }
    }

    await _activityRepository.updateTodayActivity(
      steps: data.steps,
      calories: data.calories,
      distance: data.distance,
      activeMinutes: data.activeMinutes,
      source: 'health_connect',
    );
    return HealthSyncOutcome.updated;
  }
}

enum HealthSyncOutcome { updated, noData, unavailable }
