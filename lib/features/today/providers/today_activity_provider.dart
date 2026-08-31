import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../distance/models/distance_recording_state.dart';
import '../../distance/providers/distance_recorder_provider.dart';
import '../data/today_activity_repository.dart';
import '../models/today_activity.dart';
import '../models/daily_score_explanation.dart';
import '../models/activity_streak.dart';
import '../models/activity_engagement.dart';

final currentDateProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final temporaryDemoCacheProvider = Provider<TemporaryDemoCache>((ref) {
  final auth = ref.watch(authControllerProvider);
  return TemporaryDemoCache(userId: auth.user?.id);
});

final todayActivityRepositoryProvider = Provider<TodayActivityRepository>((
  ref,
) {
  return TodayActivityRepository(
    ref.watch(apiClientProvider),
    ref.watch(temporaryDemoCacheProvider),
    ref.watch(currentDateProvider),
  );
});

TodayActivity resolveEffectiveTodayActivity({
  required TodayActivity baseActivity,
  required NativeRecorderStatus recorderStatus,
}) {
  // If baseActivity already contains non-null distance (HC, system, manual), preserve it.
  if (baseActivity.distance != null) {
    return baseActivity;
  }

  // If PulsePath GPS-recorded distance exists and HC/system distance is missing (null), show PulsePath GPS distance.
  final gpsDistanceKm = recorderStatus.distanceKm;
  final hasGpsDistance =
      gpsDistanceKm != null && !recorderStatus.isDistanceMissing;

  if (hasGpsDistance) {
    final updatedStatus =
        baseActivity.recordingStatus == ActivityRecordingStatus.unrecorded
            ? ActivityRecordingStatus.recorded
            : baseActivity.recordingStatus;

    return baseActivity.copyWith(
      distance: gpsDistanceKm,
      distanceProvenance: 'pulsepath_gps_recorded',
      recordingStatus: updatedStatus,
    );
  }

  // Automatic Step-to-Distance Conversion: Only when distance is missing (null) but steps exist (> 0),
  // automatically estimate distance (0.75m stride) with explicit step_estimated provenance.
  final steps = baseActivity.steps;
  if (steps != null && steps > 0) {
    final estimatedDistanceKm = (steps * 0.00075);
    final updatedStatus =
        baseActivity.recordingStatus == ActivityRecordingStatus.unrecorded
            ? ActivityRecordingStatus.recorded
            : baseActivity.recordingStatus;

    return baseActivity.copyWith(
      distance: estimatedDistanceKm,
      distanceProvenance: 'step_estimated',
      recordingStatus: updatedStatus,
    );
  }

  return baseActivity;
}

final todayActivityProvider = FutureProvider.autoDispose<TodayActivity>((
  ref,
) async {
  final baseActivity = await ref
      .watch(todayActivityRepositoryProvider)
      .fetchTodayActivity();
  final recorderStatus = ref.watch(distanceRecorderControllerProvider);

  return resolveEffectiveTodayActivity(
    baseActivity: baseActivity,
    recorderStatus: recorderStatus,
  );
});

final dailyScoreExplanationProvider =
    FutureProvider.autoDispose<DailyScoreExplanation>((ref) {
      return ref.watch(todayActivityRepositoryProvider).fetchScoreExplanation();
    });

final activityStreakProvider = FutureProvider.autoDispose<ActivityStreak>((
  ref,
) {
  return ref.watch(todayActivityRepositoryProvider).fetchStreak();
});

final activityEngagementProvider =
    FutureProvider.autoDispose<ActivityEngagement>((ref) {
      return ref.watch(todayActivityRepositoryProvider).fetchEngagement();
    });
