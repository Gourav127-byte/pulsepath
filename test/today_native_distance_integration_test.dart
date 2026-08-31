import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/features/distance/models/distance_recording_state.dart';
import 'package:pulsepath/features/today/models/today_activity.dart';
import 'package:pulsepath/features/today/providers/today_activity_provider.dart';

void main() {
  group('Today Native Distance Integration & Provenance', () {
    final baseActivity = TodayActivity(
      date: DateTime.parse('2026-08-28T00:00:00Z'),
      steps: 3500.0,
      activeMinutes: 25.0,
      distance: null,
      calories: 180.0,
      dailyScore: 82.0,
      scoreVersion: 'v2',
      source: 'live',
      recordingStatus: ActivityRecordingStatus.recorded,
      stepsProvenance: 'health_connect',
      distanceProvenance: 'system',
      caloriesProvenance: 'health_connect',
      activeMinutesProvenance: 'health_connect',
    );

    test(
      'HC distance missing + PulsePath GPS distance present -> Today shows PulsePath distance',
      () {
        const recorderStatus = NativeRecorderStatus(
          state: DistanceRecordingLifecycle.finalized,
          sessionId: 'session-gps-1',
          distanceMeters: 62.56,
          isDistanceMissing: false,
        );

        final effective = resolveEffectiveTodayActivity(
          baseActivity: baseActivity,
          recorderStatus: recorderStatus,
        );

        expect(effective.distance, 0.06256);
        expect(effective.distanceProvenance, 'pulsepath_gps_recorded');
        // Active minutes and calories must remain completely unchanged
        expect(effective.activeMinutes, 25.0);
        expect(effective.calories, 180.0);
        expect(effective.steps, 3500.0);
      },
    );

    test('62.56 m GPS session converts to 0.06256 km', () {
      const recorderStatus = NativeRecorderStatus(
        state: DistanceRecordingLifecycle.finalized,
        sessionId: 'session-gps-1',
        distanceMeters: 62.56,
        isDistanceMissing: false,
      );

      final effective = resolveEffectiveTodayActivity(
        baseActivity: baseActivity,
        recorderStatus: recorderStatus,
      );

      expect(effective.distance, closeTo(0.06256, 0.00001));
      // Formatted with 2 decimal places for fractional km:
      final formatted = effective.distance!.toStringAsFixed(2);
      expect(formatted, '0.06');
    });

    test(
      'Both HC and PulsePath distance missing -> automatically converts steps to km with step_estimated provenance',
      () {
        final stepsOnlyActivity = baseActivity.copyWith(
          steps: 2272.0,
          distance: null,
          distanceProvenance: 'system',
        );

        const recorderStatus = NativeRecorderStatus(
          state: DistanceRecordingLifecycle.idle,
          distanceMeters: null,
          isDistanceMissing: true,
        );

        final effective = resolveEffectiveTodayActivity(
          baseActivity: stepsOnlyActivity,
          recorderStatus: recorderStatus,
        );

        // 2272 steps * 0.00075 km/step = 1.704 km
        expect(effective.distance, closeTo(1.704, 0.001));
        expect(effective.distanceProvenance, 'step_estimated');
        expect(effective.steps, 2272.0);
      },
    );

    test(
      'Authoritative HC distance takes precedence and is NOT blindly summed with native GPS',
      () {
        final hcActivity = baseActivity.copyWith(
          distance: 2.50, // 2.50 km from Health Connect
          distanceProvenance: 'health_connect_recorded',
        );

        const recorderStatus = NativeRecorderStatus(
          state: DistanceRecordingLifecycle.finalized,
          sessionId: 'session-gps-1',
          distanceMeters: 1200.0, // 1.20 km from native GPS
          isDistanceMissing: false,
        );

        final effective = resolveEffectiveTodayActivity(
          baseActivity: hcActivity,
          recorderStatus: recorderStatus,
        );

        // Must preserve HC evidence and NOT sum 2.5 + 1.2 = 3.7
        expect(effective.distance, 2.50);
        expect(effective.distanceProvenance, 'health_connect_recorded');
      },
    );

    test('User manual distance entry takes precedence over GPS recorder and step estimation', () {
      final manualActivity = baseActivity.copyWith(
        distance: 4.2,
        distanceProvenance: 'manual',
      );

      const recorderStatus = NativeRecorderStatus(
        state: DistanceRecordingLifecycle.finalized,
        distanceMeters: 1500.0,
        isDistanceMissing: false,
      );

      final effective = resolveEffectiveTodayActivity(
        baseActivity: manualActivity,
        recorderStatus: recorderStatus,
      );

      expect(effective.distance, 4.2);
      expect(effective.distanceProvenance, 'manual');
    });

    test(
      'Unrecorded day transitions to recorded when finalized native GPS distance is available',
      () {
        final unrecordedActivity = TodayActivity(
          date: DateTime.parse('2026-08-28T00:00:00Z'),
          scoreVersion: 'v2',
          source: 'live',
          recordingStatus: ActivityRecordingStatus.unrecorded,
        );

        const recorderStatus = NativeRecorderStatus(
          state: DistanceRecordingLifecycle.finalized,
          distanceMeters: 300.0,
          isDistanceMissing: false,
        );

        final effective = resolveEffectiveTodayActivity(
          baseActivity: unrecordedActivity,
          recorderStatus: recorderStatus,
        );

        expect(effective.isRecorded, isTrue);
        expect(effective.distance, 0.3);
        expect(effective.distanceProvenance, 'pulsepath_gps_recorded');
      },
    );
  });
}
