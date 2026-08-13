import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../today/providers/today_activity_provider.dart';
import '../data/goals_repository.dart';
import '../models/backend_goal.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(
    ref.watch(apiClientProvider),
    ref.watch(temporaryDemoCacheProvider),
  );
});

final backendGoalsProvider = FutureProvider.autoDispose<List<BackendGoal>>((
  ref,
) {
  return ref.watch(goalsRepositoryProvider).fetchGoals();
});
