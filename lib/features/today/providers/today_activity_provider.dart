import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/today_activity_repository.dart';
import '../models/today_activity.dart';

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
  );
});

final todayActivityProvider = FutureProvider.autoDispose<TodayActivity>((ref) {
  return ref.watch(todayActivityRepositoryProvider).fetchTodayActivity();
});
