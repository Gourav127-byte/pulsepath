import 'dart:async';
import 'package:health/health.dart';

class StepSampleRecord {
  const StepSampleRecord({
    required this.startTime,
    required this.endTime,
    required this.steps,
    required this.sourceOrigin,
    this.sampleId,
  });

  final DateTime startTime;
  final DateTime endTime;
  final int steps;
  final String sourceOrigin;
  final String? sampleId;

  Map<String, Object?> toJson() => {
        if (sampleId != null) 'sample_id': sampleId,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'steps': steps,
        'source_origin': sourceOrigin,
      };
}

class HealthSyncResult {
  const HealthSyncResult({
    this.steps,
    this.distance,
    this.calories,
    this.activeMinutes,
    this.timelineSamples = const [],
  });

  final double? steps;
  final double? distance;
  final double? calories;
  final double? activeMinutes;
  final List<StepSampleRecord> timelineSamples;

  bool get isEmpty =>
      steps == null &&
      distance == null &&
      calories == null &&
      activeMinutes == null &&
      timelineSamples.isEmpty;
}

/// PulsePath Active Minutes are the summed duration of recorded Health
/// Connect workout/exercise sessions. Passive movement, steps, cadence, and
/// calorie estimates must never be converted into Active Minutes.
///
/// Valid manual Active Minutes enter through the activity PATCH flow and are
/// reconciled with this value by the backend to avoid double counting.

class HealthConnectPermissionException implements Exception {
  const HealthConnectPermissionException();
}

abstract interface class HealthConnectService {
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<HealthSyncResult> fetchDailyData();
}

/// Small adapter around the plugin so availability and permission behavior can
/// be tested without invoking Android platform channels.
abstract interface class HealthConnectClient {
  Future<bool> isHealthConnectAvailable();
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus();
  Future<void> installHealthConnect();
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  });
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  });
  Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime);
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required DateTime startTime,
    required DateTime endTime,
    required List<HealthDataType> types,
  });
}

class _PluginHealthConnectClient implements HealthConnectClient {
  const _PluginHealthConnectClient(this._health);

  final Health _health;

  @override
  Future<bool> isHealthConnectAvailable() => _health.isHealthConnectAvailable();

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() =>
      _health.getHealthConnectSdkStatus();

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) => _health.requestAuthorization(types, permissions: permissions);

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) => _health.hasPermissions(types, permissions: permissions);

  @override
  Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime) =>
      _health.getTotalStepsInInterval(startTime, endTime);

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required DateTime startTime,
    required DateTime endTime,
    required List<HealthDataType> types,
  }) => _health.getHealthDataFromTypes(
    startTime: startTime,
    endTime: endTime,
    types: types,
  );
}

class AndroidHealthConnectService implements HealthConnectService {
  AndroidHealthConnectService([Health? health])
    : _health = _PluginHealthConnectClient(health ?? Health());

  AndroidHealthConnectService.withClient(HealthConnectClient client)
    : _health = client;

  final HealthConnectClient _health;
  Completer<bool>? _inFlightRequest;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  @override
  Future<bool> isAvailable() async {
    try {
      // Keep background availability probes side-effect free. Setup is opened
      // only from the user-initiated permission request below.
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (_inFlightRequest != null) {
      return _inFlightRequest!.future;
    }
    final completer = Completer<bool>();
    _inFlightRequest = completer;
    HealthConnectSdkStatus? status;

    try {
      status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        await _openHealthConnectSetup();
        completer.complete(false);
        return false;
      }

      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      // Do not add a timeout here. Android 14+ owns this native permission UI
      // and the Future must remain alive while the user makes a decision.
      final granted = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );
      completer.complete(granted);
      return granted;
    } catch (_) {
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        await _openHealthConnectSetup();
      }
      completer.complete(false);
      return false;
    } finally {
      _inFlightRequest = null;
    }
  }

  Future<void> _openHealthConnectSetup() async {
    try {
      await _health.installHealthConnect();
    } catch (_) {
      // The caller still receives a safe unavailable/unauthorized state when
      // no compatible store or system settings activity can handle the intent.
    }
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

    final rawSteps = await _health.getTotalStepsInInterval(startOfDay, now);

    // health removes exact duplicate records. Cross-source overlapping records
    // cannot be safely reconciled without source precedence rules.
    final data = await _health.getHealthDataFromTypes(
      startTime: startOfDay,
      endTime: now,
      types: _types,
    );

    double? distance;
    double? calories;
    double? activeMinutes;
    bool hasStepRecords = false;
    final List<StepSampleRecord> timelineSamples = [];

    for (final point in data) {
      if (point.type == HealthDataType.STEPS) {
        hasStepRecords = true;
        final value = point.value;
        if (value is NumericHealthValue) {
          final count = value.numericValue.round();
          if (count > 0) {
            timelineSamples.add(
              StepSampleRecord(
                startTime: point.dateFrom,
                endTime: point.dateTo,
                steps: count,
                sourceOrigin: point.sourceId.isNotEmpty ? point.sourceId : 'health_connect',
                sampleId: point.uuid.isNotEmpty ? point.uuid : null,
              ),
            );
          }
        }
      }
      if (point.type == HealthDataType.WORKOUT) {
        final duration = point.dateTo
            .difference(point.dateFrom)
            .inMinutes
            .toDouble();
        activeMinutes = (activeMinutes ?? 0) + duration;
      }
      final value = point.value;
      if (value is! NumericHealthValue) continue;
      if (point.type == HealthDataType.DISTANCE_DELTA) {
        distance = (distance ?? 0) + value.numericValue.toDouble();
      } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
        calories = (calories ?? 0) + value.numericValue.toDouble();
      }
    }

    if (timelineSamples.isEmpty && rawSteps != null && rawSteps > 0) {
      print('[TIMELINE_DEBUG] rawSteps=$rawSteps > 0. Attempting 15-min duration aggregation...');
      try {
        var current = startOfDay;
        while (current.isBefore(now)) {
          final next = current.add(const Duration(minutes: 15));
          final windowEnd = next.isBefore(now) ? next : now;
          final windowSteps = await _health.getTotalStepsInInterval(current, windowEnd);
          if (windowSteps != null && windowSteps > 0) {
            final sampleId = 'hc_agg_${current.millisecondsSinceEpoch}_${windowEnd.millisecondsSinceEpoch}';
            timelineSamples.add(
              StepSampleRecord(
                startTime: current,
                endTime: windowEnd,
                steps: windowSteps,
                sourceOrigin: 'health_connect_aggregate',
                sampleId: sampleId,
              ),
            );
          }
          current = next;
        }
      } catch (e) {
        print('[TIMELINE_DEBUG] 15-min bucket query error: $e');
      }

      if (timelineSamples.isEmpty) {
        print('[TIMELINE_DEBUG] 15-min buckets empty. Adding active duration window bucket...');
        final sampleId = 'hc_agg_${startOfDay.millisecondsSinceEpoch}_${now.millisecondsSinceEpoch}';
        timelineSamples.add(
          StepSampleRecord(
            startTime: startOfDay,
            endTime: now,
            steps: rawSteps,
            sourceOrigin: 'health_connect_aggregate',
            sampleId: sampleId,
          ),
        );
      }
      print('[TIMELINE_DEBUG] Total timelineSamples generated: ${timelineSamples.length}');
    }

    final result = HealthSyncResult(
      steps: (hasStepRecords || timelineSamples.isNotEmpty) ? (rawSteps?.toDouble() ?? 0.0) : null,
      // Convert distance from meters to km. Calories are active energy only.
      distance: distance != null ? distance / 1000 : null,
      calories: calories,
      activeMinutes: activeMinutes,
      timelineSamples: timelineSamples,
    );
    return result;
  }
}
