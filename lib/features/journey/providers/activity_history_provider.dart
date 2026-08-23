import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../today/providers/today_activity_provider.dart';
import '../data/activity_history_repository.dart';
import '../models/activity_history_entry.dart';
import '../models/activity_insights.dart';

final activityHistoryRepositoryProvider = Provider<ActivityHistoryRepository>((
  ref,
) {
  return ActivityHistoryRepository(
    ref.watch(apiClientProvider),
    ref.watch(temporaryDemoCacheProvider),
  );
});

final activityHistoryProvider = FutureProvider.autoDispose
    .family<List<ActivityHistoryEntry>, int>((ref, days) {
      return ref
          .watch(activityHistoryRepositoryProvider)
          .fetchHistory(days: days);
    });

final activityInsightsProvider = FutureProvider.autoDispose
    .family<ActivityInsights, int>((ref, days) {
      return ref
          .watch(activityHistoryRepositoryProvider)
          .fetchInsights(days: days);
    });
