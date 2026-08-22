import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/features/today/data/health_sync_repository.dart';
import 'package:pulsepath/features/today/providers/health_sync_provider.dart';
import 'package:pulsepath/features/today/providers/today_activity_provider.dart';
import 'package:pulsepath/features/journey/providers/activity_history_provider.dart';
import 'package:pulsepath/features/journey/data/activity_history_repository.dart';
import 'package:pulsepath/features/journey/models/activity_history_entry.dart';
import 'package:pulsepath/features/journey/models/activity_insights.dart';
import 'package:pulsepath/features/today/data/today_activity_repository.dart';
import 'package:pulsepath/features/today/models/today_activity.dart';
import 'package:pulsepath/features/today/services/health_connect_service.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/today/models/daily_score_explanation.dart';
import 'package:pulsepath/features/today/models/activity_streak.dart';
import 'package:pulsepath/features/today/models/activity_engagement.dart';

class MockHealthConnectService implements HealthConnectService {
  bool available = true;
  bool throwPermissionError = false;
  bool permissionsGranted = true;
  HealthSyncResult? fakeResult;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<HealthSyncResult> fetchDailyData() async {
    if (throwPermissionError) {
      throw const HealthConnectPermissionException();
    }
    return fakeResult ?? const HealthSyncResult();
  }
}

class MockFailingSyncRepository implements HealthSyncRepository {
  bool throwNetworkError = false;
  HealthSyncOutcome fakeOutcome = HealthSyncOutcome.updated;

  @override
  Future<HealthSyncOutcome> sync() async {
    if (throwNetworkError) {
      throw const NetworkException('Offline');
    }
    return fakeOutcome;
  }
}

class MockTodayRepo implements TodayActivityRepository {
  @override
  Future<TodayActivity> fetchTodayActivity() async {
    return TodayActivity(
      date: DateTime.now(),
      steps: 0,
      activeMinutes: 0,
      distance: 0,
      calories: 0,
      dailyScore: 0,
      scoreVersion: 'v2',
      source: 'system',
      recordingStatus: ActivityRecordingStatus.unrecorded,
    );
  }

  @override
  Future<TodayActivity> updateTodayActivity({
    double? steps,
    double? activeMinutes,
    double? calories,
    double? distance,
    String source = 'manual',
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DailyScoreExplanation> fetchScoreExplanation() async {
    throw UnimplementedError();
  }

  @override
  Future<ActivityStreak> fetchStreak() async {
    throw UnimplementedError();
  }

  @override
  Future<ActivityEngagement> fetchEngagement() async {
    throw UnimplementedError();
  }
}

class MockHistoryRepo implements ActivityHistoryRepository {
  @override
  Future<List<ActivityHistoryEntry>> fetchHistory({required int days}) async {
    return [];
  }

  @override
  Future<ActivityInsights> fetchInsights({required int days}) async {
    throw UnimplementedError();
  }
}

void main() {
  group('HealthSyncController Resilience', () {
    test('handles unavailable device state', () async {
      final mockService = MockHealthConnectService()..available = false;
      final mockRepo = MockFailingSyncRepository();
      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(mockService),
          healthSyncRepositoryProvider.overrideWithValue(mockRepo),
          todayActivityRepositoryProvider.overrideWithValue(MockTodayRepo()),
          activityHistoryRepositoryProvider.overrideWithValue(
            MockHistoryRepo(),
          ),
        ],
      );
      final controller = container.read(healthSyncControllerProvider.notifier);

      await controller.sync();
      final state = container.read(healthSyncControllerProvider);

      expect(state.status, HealthSyncStatus.error);
      expect(state.message, contains('not available'));
    });

    test('handles permission denial during fetch', () async {
      final mockService = MockHealthConnectService()
        ..throwPermissionError = true;
      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(mockService),
          todayActivityRepositoryProvider.overrideWithValue(MockTodayRepo()),
          activityHistoryRepositoryProvider.overrideWithValue(
            MockHistoryRepo(),
          ),
        ],
      );
      final controller = container.read(healthSyncControllerProvider.notifier);

      await controller.sync();
      final state = container.read(healthSyncControllerProvider);

      expect(state.status, HealthSyncStatus.unauthorized);
      expect(state.message, contains('permissions were not granted'));
    });

    test('handles backend network failure gracefully', () async {
      final mockService = MockHealthConnectService();
      final mockRepo = MockFailingSyncRepository()..throwNetworkError = true;
      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(mockService),
          healthSyncRepositoryProvider.overrideWithValue(mockRepo),
          todayActivityRepositoryProvider.overrideWithValue(MockTodayRepo()),
          activityHistoryRepositoryProvider.overrideWithValue(
            MockHistoryRepo(),
          ),
        ],
      );
      final controller = container.read(healthSyncControllerProvider.notifier);

      await controller.sync();
      final state = container.read(healthSyncControllerProvider);

      expect(state.status, HealthSyncStatus.error);
      expect(state.message, contains('Failed to sync'));
    });

    test('no-data result sets success with informational message', () async {
      final mockService = MockHealthConnectService();
      final mockRepo = MockFailingSyncRepository()
        ..fakeOutcome = HealthSyncOutcome.noData;
      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(mockService),
          healthSyncRepositoryProvider.overrideWithValue(mockRepo),
          todayActivityRepositoryProvider.overrideWithValue(MockTodayRepo()),
          activityHistoryRepositoryProvider.overrideWithValue(
            MockHistoryRepo(),
          ),
        ],
      );
      final controller = container.read(healthSyncControllerProvider.notifier);

      await controller.sync();
      final state = container.read(healthSyncControllerProvider);

      expect(state.status, HealthSyncStatus.success);
      expect(state.message, contains('No Health Connect records found'));
    });
  });
}
