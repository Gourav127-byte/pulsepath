import 'package:flutter/foundation.dart';

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
    if (kDebugMode) {
      debugPrint(
        '[HEALTH_SYNC] stage=read_complete hasData=${!data.isEmpty} '
        'granularity=${data.granularity.name} '
        'steps=${data.capabilities.hasSteps} '
        'intervals=${data.capabilities.hasTimestampedStepIntervals} '
        'distance=${data.capabilities.hasDistance} '
        'calories=${data.capabilities.hasActiveCalories} '
        'workouts=${data.capabilities.hasWorkoutSessions}',
      );
    }
    if (data.isEmpty) return HealthSyncOutcome.noData;

    if (data.timelineSamples.isNotEmpty) {
      try {
        await _activityRepository.syncTimelineSamples(
          date: DateTime.now(),
          samples: data.timelineSamples,
        );
      } on Object catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[HEALTH_SYNC] stage=timeline_upload_failed '
            'type=${error.runtimeType}',
          );
        }
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
