import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:pulsepath/features/today/services/health_connect_service.dart';

class MockHealthConnectClient implements HealthConnectClient {
  MockHealthConnectClient({
    this.isAvailableValue = true,
    this.sdkStatus = HealthConnectSdkStatus.sdkAvailable,
    this.hasPermissionsValue = true,
    this.rawStepsValue = 5000,
    this.healthDataPoints = const [],
  });

  final bool isAvailableValue;
  final HealthConnectSdkStatus sdkStatus;
  final bool hasPermissionsValue;
  final int? rawStepsValue;
  final List<HealthDataPoint> healthDataPoints;

  @override
  Future<bool> isHealthConnectAvailable() async => isAvailableValue;

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async => sdkStatus;

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => true;

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => hasPermissionsValue;

  @override
  Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime) async =>
      rawStepsValue;

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required DateTime startTime,
    required DateTime endTime,
    required List<HealthDataType> types,
  }) async => healthDataPoints;
}

HealthDataPoint _point(
  HealthDataType type,
  num value,
  DateTime from,
  DateTime to, {
  String sourceId = 'com.google.android.apps.fitness',
}) {
  return HealthDataPoint(
    uuid: '${type.name}-${from.microsecondsSinceEpoch}',
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: HealthDataUnit.COUNT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'dev-1',
    sourceId: sourceId,
    sourceName: 'Google Fit',
    recordingMethod: RecordingMethod.active,
  );
}

void main() {
  group('Phase 22.5 — Real Health Data Integrity Gate Tests', () {
    test('1. DISTANCE: Converts meters to km correctly and never estimates from steps', () async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(minutes: 30));
      final client = MockHealthConnectClient(
        rawStepsValue: 4000,
        healthDataPoints: [
          _point(HealthDataType.DISTANCE_DELTA, 3200.0, start, now), // 3200 meters = 3.2 km
        ],
      );

      final service = AndroidHealthConnectService.withClient(client);
      final result = await service.fetchDailyData();

      expect(result.steps, 4000.0);
      expect(result.distance, 3.2); // Exact 3200 / 1000 = 3.2 km
      expect(result.calories, isNull); // Missing != Zero
      expect(result.activeMinutes, isNull); // Missing != Zero
      expect(result.capabilities.hasDistance, isTrue);
      expect(result.capabilities.hasActiveCalories, isFalse);
      expect(result.capabilities.hasWorkoutSessions, isFalse);
    });

    test('2. ACTIVE CALORIES & MINUTES: Absent records remain null (Missing != Zero)', () async {
      final client = MockHealthConnectClient(
        rawStepsValue: 10000,
        healthDataPoints: [], // Zero secondary data points
      );

      final service = AndroidHealthConnectService.withClient(client);
      final result = await service.fetchDailyData();

      expect(result.steps, 10000.0);
      expect(result.distance, isNull); // NO STEP ESTIMATION
      expect(result.calories, isNull); // NO STEP ESTIMATION
      expect(result.activeMinutes, isNull); // NO STEP ESTIMATION
      expect(result.capabilities.hasSteps, isTrue);
      expect(result.capabilities.hasDistance, isFalse);
      expect(result.capabilities.hasActiveCalories, isFalse);
      expect(result.capabilities.hasWorkoutSessions, isFalse);
    });

    test('3. STEP TIMELINE: Timestamped step intervals preserve exact device timestamps', () async {
      final now = DateTime.now();
      final start1 = now.subtract(const Duration(hours: 2));
      final end1 = start1.add(const Duration(minutes: 15));
      final start2 = now.subtract(const Duration(hours: 1));
      final end2 = start2.add(const Duration(minutes: 10));

      final client = MockHealthConnectClient(
        rawStepsValue: 835,
        healthDataPoints: [
          _point(HealthDataType.STEPS, 324, start1, end1, sourceId: 'com.sec.android.app.shealth'),
          _point(HealthDataType.STEPS, 511, start2, end2, sourceId: 'com.sec.android.app.shealth'),
        ],
      );

      final service = AndroidHealthConnectService.withClient(client);
      final result = await service.fetchDailyData();

      expect(result.granularity, TimelineGranularity.timestampedIntervals);
      expect(result.capabilities.hasTimestampedStepIntervals, isTrue);
      expect(result.timelineSamples.length, 2);
      expect(result.timelineSamples[0].steps, 324);
      expect(result.timelineSamples[0].startTime, start1);
      expect(result.timelineSamples[0].endTime, end1);
      expect(result.timelineSamples[0].sourceOrigin, 'com.sec.android.app.shealth');
      expect(result.timelineSamples[1].steps, 511);
      expect(result.timelineSamples[1].startTime, start2);
      expect(result.timelineSamples[1].endTime, end2);
    });

    test('4. COARSE AGGREGATE GRANULARITY: Daily aggregate classifies timeline cleanly', () async {
      final client = MockHealthConnectClient(
        rawStepsValue: 2500,
        healthDataPoints: [], // No interval step points
      );

      final service = AndroidHealthConnectService.withClient(client);
      final result = await service.fetchDailyData();

      expect(result.granularity, TimelineGranularity.coarseDailyAggregate);
      expect(result.capabilities.hasTimestampedStepIntervals, isFalse);
      expect(result.timelineSamples.length, 1);
      expect(result.timelineSamples[0].sourceOrigin, 'health_connect_aggregate');
      expect(result.timelineSamples[0].steps, 2500);
    });

    test('5. WORKOUT SESSIONS: Active minutes derived strictly from recorded workouts', () async {
      final now = DateTime.now();
      final workoutStart = now.subtract(const Duration(minutes: 45));

      final client = MockHealthConnectClient(
        rawStepsValue: 3000,
        healthDataPoints: [
          _point(HealthDataType.WORKOUT, 1, workoutStart, now), // 45 minutes workout session
        ],
      );

      final service = AndroidHealthConnectService.withClient(client);
      final result = await service.fetchDailyData();

      expect(result.activeMinutes, 45.0); // Exact 45 minutes workout session
      expect(result.capabilities.hasWorkoutSessions, isTrue);
    });
  });
}
