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
    if (data.isEmpty) return HealthSyncOutcome.noData;

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
