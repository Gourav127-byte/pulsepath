import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
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

final todayActivityProvider = FutureProvider.autoDispose<TodayActivity>((ref) {
  return ref.watch(todayActivityRepositoryProvider).fetchTodayActivity();
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
