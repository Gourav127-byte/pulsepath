import 'package:health/health.dart';

class HealthSyncResult {
  const HealthSyncResult({
    this.steps,
    this.distance,
    this.calories,
    this.activeMinutes,
  });

  final double? steps;
  final double? distance;
  final double? calories;
  final double? activeMinutes;

  bool get isEmpty =>
      steps == null &&
      distance == null &&
      calories == null &&
      activeMinutes == null;
}

class HealthConnectPermissionException implements Exception {
  const HealthConnectPermissionException();
}

abstract interface class HealthConnectService {
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<HealthSyncResult> fetchDailyData();
}

class AndroidHealthConnectService implements HealthConnectService {
  AndroidHealthConnectService([Health? health]) : _health = health ?? Health();

  final Health _health;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  @override
  Future<bool> isAvailable() async {
    final available = await _health.isHealthConnectAvailable();
    return available;
  }

  @override
  Future<bool> requestPermissions() async {
    // Request only read permissions for the types we need
    final permissions = _types.map((_) => HealthDataAccess.READ).toList();
    return await _health.requestAuthorization(_types, permissions: permissions);
  }

  @override
  Future<HealthSyncResult> fetchDailyData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final permissions = _types.map((_) => HealthDataAccess.READ).toList();
    final hasPermissions = await _health.hasPermissions(
      _types,
      permissions: permissions,
    );
    if (hasPermissions != true) {
      throw const HealthConnectPermissionException();
    }

    final steps = await _health.getTotalStepsInInterval(startOfDay, now);

    // health removes exact duplicate records. Cross-source overlapping records
    // cannot be safely reconciled without source precedence rules.
    final data = await _health.getHealthDataFromTypes(
      startTime: startOfDay,
      endTime: now,
      types: _types,
    );

    double? distance;
    double? calories;

    for (final point in data) {
      final value = point.value;
      if (value is! NumericHealthValue) continue;
      if (point.type == HealthDataType.DISTANCE_DELTA) {
        distance = (distance ?? 0) + value.numericValue.toDouble();
      } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
        calories = (calories ?? 0) + value.numericValue.toDouble();
      }
    }

    return HealthSyncResult(
      steps: steps?.toDouble(),
      // Convert distance from meters to km. Calories are active energy only.
      distance: distance != null ? distance / 1000 : null,
      calories: calories,
    );
  }
}
