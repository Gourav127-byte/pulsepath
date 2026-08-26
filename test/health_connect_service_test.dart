import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:pulsepath/features/today/services/health_connect_service.dart';

void main() {
  group('AndroidHealthConnectService', () {
    test('requests the four aligned read permissions', () async {
      final client = _FakeHealthConnectClient();
      final service = AndroidHealthConnectService.withClient(client);

      expect(await service.requestPermissions(), isTrue);
      expect(client.requestedTypes, {
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.WORKOUT,
      });
      expect(client.requestedPermissions, everyElement(HealthDataAccess.READ));
      expect(client.installCalls, 0);
    });

    test(
      'opens setup when permission request needs a provider update',
      () async {
        final client = _FakeHealthConnectClient(
          status: HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired,
        );
        final service = AndroidHealthConnectService.withClient(client);

        expect(await service.requestPermissions(), isFalse);
        expect(client.installCalls, 1);
      },
    );

    test(
      'background availability check has no navigation side effect',
      () async {
        final client = _FakeHealthConnectClient(
          status: HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired,
        );
        final service = AndroidHealthConnectService.withClient(client);

        expect(await service.isAvailable(), isFalse);
        expect(client.installCalls, 0);
      },
    );

    test(
      'native permission denial does not redirect an available provider',
      () async {
        final client = _FakeHealthConnectClient()..authorizationGranted = false;
        final service = AndroidHealthConnectService.withClient(client);

        expect(await service.requestPermissions(), isFalse);
        expect(client.installCalls, 0);
      },
    );

    test(
      'aggregates today metrics and converts distance to kilometres',
      () async {
        final now = DateTime.now();
        final client = _FakeHealthConnectClient()
          ..totalSteps = 7842
          ..points = [
            _point(HealthDataType.STEPS, 7842, now, now),
            _point(HealthDataType.DISTANCE_DELTA, 5600, now, now),
            _point(HealthDataType.ACTIVE_ENERGY_BURNED, 324, now, now),
            _point(
              HealthDataType.WORKOUT,
              1,
              now.subtract(const Duration(minutes: 46)),
              now,
            ),
          ];
        final service = AndroidHealthConnectService.withClient(client);

        final result = await service.fetchDailyData();

        expect(result.steps, 7842);
        expect(result.distance, 5.6);
        expect(result.calories, 324);
        expect(result.activeMinutes, 46);
        expect(client.readStart, DateTime(now.year, now.month, now.day));
        expect(client.readEnd, isNotNull);
      },
    );

    test('no step records remains no-data instead of becoming zero', () async {
      final client = _FakeHealthConnectClient()..totalSteps = 0;
      final service = AndroidHealthConnectService.withClient(client);

      final result = await service.fetchDailyData();

      expect(result.steps, isNull);
      expect(result.isEmpty, isTrue);
    });

    test(
      'steps without workout records never fall back to heuristic active minutes',
      () async {
        final now = DateTime.now();
        final client = _FakeHealthConnectClient()
          ..totalSteps = 10000
          ..points = [_point(HealthDataType.STEPS, 10000, now, now)];
        final service = AndroidHealthConnectService.withClient(client);

        final result = await service.fetchDailyData();

        expect(result.steps, 10000);
        expect(result.activeMinutes, isNull);
      },
    );

    test('active minutes sum recorded workout session durations only', () async {
      final now = DateTime.now();
      final client = _FakeHealthConnectClient()
        ..points = [
          _point(
            HealthDataType.WORKOUT,
            1,
            now.subtract(const Duration(minutes: 20)),
            now,
          ),
          _point(
            HealthDataType.WORKOUT,
            1,
            now.subtract(const Duration(minutes: 55)),
            now.subtract(const Duration(minutes: 30)),
          ),
        ];
      final service = AndroidHealthConnectService.withClient(client);

      final result = await service.fetchDailyData();

      expect(result.activeMinutes, 45);
      expect(result.steps, isNull);
    });
  });
}

HealthDataPoint _point(
  HealthDataType type,
  num value,
  DateTime from,
  DateTime to,
) {
  return HealthDataPoint(
    uuid: '${type.name}-${from.microsecondsSinceEpoch}',
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: HealthDataUnit.COUNT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'test-device',
    sourceId: 'test-source',
    sourceName: 'test-source',
  );
}

class _FakeHealthConnectClient implements HealthConnectClient {
  _FakeHealthConnectClient({this.status = HealthConnectSdkStatus.sdkAvailable});

  HealthConnectSdkStatus? status;
  bool authorizationGranted = true;
  bool permissionsGranted = true;
  int? totalSteps;
  List<HealthDataPoint> points = [];
  int installCalls = 0;
  Set<HealthDataType> requestedTypes = {};
  List<HealthDataAccess> requestedPermissions = [];
  DateTime? readStart;
  DateTime? readEnd;

  @override
  Future<bool> isHealthConnectAvailable() async =>
      status == HealthConnectSdkStatus.sdkAvailable;

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async => status;

  @override
  Future<void> installHealthConnect() async {
    installCalls++;
  }

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    requestedTypes = types.toSet();
    requestedPermissions = permissions ?? [];
    return authorizationGranted;
  }

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => permissionsGranted;

  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime,
  ) async => totalSteps;

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required DateTime startTime,
    required DateTime endTime,
    required List<HealthDataType> types,
  }) async {
    readStart = startTime;
    readEnd = endTime;
    return points;
  }
}
