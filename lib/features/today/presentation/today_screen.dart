import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/activity/activity_metric.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../../goals/models/backend_goal.dart';
import '../../goals/providers/backend_goals_provider.dart';
import '../../journey/models/activity_history_entry.dart';
import '../../journey/providers/activity_history_provider.dart';
import '../../profile/models/backend_profile.dart';
import '../../profile/providers/backend_profile_provider.dart';
import '../models/today_activity.dart';
import '../models/activity_engagement.dart';
import '../providers/today_activity_provider.dart';
import '../providers/health_sync_provider.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/activity_engagement_card.dart';
import '../widgets/daily_score_card.dart';
import '../widgets/daily_score_explanation_sheet.dart';
import '../widgets/metric_card.dart';
import '../widgets/manual_activity_edit_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(todayActivityProvider);
    final profile = ref.watch(backendProfileProvider);
    final goals = ref.watch(backendGoalsProvider);
    final history = ref.watch(activityHistoryProvider(7));
    final engagement = ref.watch(activityEngagementProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            sliver: SliverList.list(
              children: [
                _TodayHeader(
                  profile: profile,
                  date: ref.watch(currentDateProvider)(),
                ),
                const SizedBox(height: 24),
                activity.when(
                  data: (value) => value.isRecorded
                      ? _ActivityContent(
                          activity: value,
                          goals: goals,
                          history: history,
                          engagement: engagement,
                          onEngagementRetry: () =>
                              ref.invalidate(activityEngagementProvider),
                          onEdit: () => _editActivity(context, ref, value),
                        )
                      : _UnrecordedActivityContent(
                          history: history,
                          engagement: engagement,
                          onEngagementRetry: () =>
                              ref.invalidate(activityEngagementProvider),
                          onQuickLog: () => _editActivity(
                            context,
                            ref,
                            value,
                            confirmUnchanged: true,
                          ),
                        ),
                  loading: () => const DailyScoreCard.loading(),
                  error: (_, _) => DailyScoreCard.error(
                    onRetry: () => ref.invalidate(todayActivityProvider),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editActivity(
    BuildContext context,
    WidgetRef ref,
    TodayActivity activity, {
    bool confirmUnchanged = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PulsePathColors.background,
      builder: (context) => ManualActivityEditSheet(
        activity: activity,
        confirmUnchanged: confirmUnchanged,
        onSave: ({steps, activeMinutes, calories, distance}) async {
          await ref
              .read(todayActivityRepositoryProvider)
              .updateTodayActivity(
                steps: steps,
                activeMinutes: activeMinutes,
                calories: calories,
                distance: distance,
              );
          ref.invalidate(todayActivityProvider);
          ref.invalidate(activityStreakProvider);
          ref.invalidate(activityEngagementProvider);
          ref.invalidate(backendGoalsProvider);
          ref.invalidate(activityHistoryProvider(7));
          ref.invalidate(activityHistoryProvider(30));
          await Future.wait([
            ref.read(todayActivityProvider.future),
            ref.read(backendGoalsProvider.future),
          ]);
        },
      ),
    );
  }
}

class _UnrecordedActivityContent extends StatelessWidget {
  const _UnrecordedActivityContent({
    required this.history,
    required this.engagement,
    required this.onEngagementRetry,
    required this.onQuickLog,
  });

  final AsyncValue<List<ActivityHistoryEntry>> history;
  final AsyncValue<ActivityEngagement> engagement;
  final VoidCallback onEngagementRetry;
  final VoidCallback onQuickLog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('unrecorded_activity_state'),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: PulsePathColors.surface,
            borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
            border: Border.all(color: PulsePathColors.divider),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.edit_calendar_outlined,
                color: PulsePathColors.cyan,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'No activity recorded yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              const Text(
                'Log today’s activity or sync available Health Connect data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PulsePathColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('quick_log_activity_button'),
                    onPressed: onQuickLog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Quick log'),
                  ),
                  const _HealthSyncIndicator(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _EngagementState(engagement: engagement, onRetry: onEngagementRetry),
        const SizedBox(height: 26),
        const _SectionTitle(title: 'Daily progress'),
        const SizedBox(height: 12),
        history.when(
          data: (entries) => DailyProgressCard(history: entries),
          loading: () => const _HistoryStatusCard.loading(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

String formatTodayHeaderDate(DateTime date) {
  const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

class _ActivityContent extends ConsumerWidget {
  const _ActivityContent({
    required this.activity,
    required this.goals,
    required this.history,
    required this.engagement,
    required this.onEngagementRetry,
    required this.onEdit,
  });

  final TodayActivity activity;
  final AsyncValue<List<BackendGoal>> goals;
  final AsyncValue<List<ActivityHistoryEntry>> history;
  final AsyncValue<ActivityEngagement> engagement;
  final VoidCallback onEngagementRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DailyScoreCard(
          score: activity.dailyScore.round(),
          streakDays: engagement.asData?.value.currentStreak,
          onExplain: () => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            backgroundColor: PulsePathColors.background,
            builder: (_) => const DailyScoreExplanationSheet(),
          ),
        ),
        const SizedBox(height: 14),
        _EngagementState(engagement: engagement, onRetry: onEngagementRetry),
        const SizedBox(height: 26),
        _SectionTitle(
          title: "Today's activity",
          action: activity.source == 'health_connect'
              ? 'Health Connect'
              : 'Live',
          onEdit: onEdit,
          trailing: const _HealthSyncIndicator(),
        ),
        const SizedBox(height: 12),
        _MetricsGrid(activity: activity, goals: goals),
        const SizedBox(height: 26),
        const _SectionTitle(title: 'Daily progress'),
        const SizedBox(height: 12),
        history.when(
          data: (entries) => DailyProgressCard(history: entries),
          loading: () => const _HistoryStatusCard.loading(),
          error: (_, _) => _HistoryStatusCard.error(
            onRetry: () => ref.invalidate(activityHistoryProvider(7)),
          ),
        ),
      ],
    );
  }
}

class _EngagementState extends StatelessWidget {
  const _EngagementState({required this.engagement, required this.onRetry});

  final AsyncValue<ActivityEngagement> engagement;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return engagement.when(
      data: (value) => ActivityEngagementCard(engagement: value),
      loading: () => const ActivityEngagementCard.loading(),
      error: (_, _) => ActivityEngagementCard.error(onRetry: onRetry),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.profile, required this.date});

  final AsyncValue<BackendProfile> profile;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatTodayHeaderDate(date),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: PulsePathColors.cyan,
                  letterSpacing: 1.25,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                profile.when(
                  data: (value) => 'Good morning, ${value.displayName}',
                  loading: () => 'Good morning',
                  error: (_, _) => 'Good morning',
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Keep your momentum moving.',
                style: TextStyle(color: PulsePathColors.textSecondary),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [PulsePathColors.violet, PulsePathColors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.action,
    this.onEdit,
    this.trailing,
  });

  final String title;
  final String? action;
  final VoidCallback? onEdit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleRow = Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onEdit != null)
          IconButton(
            key: const Key('edit_activity_button'),
            tooltip: "Edit today's activity",
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
      ],
    );

    if (trailing == null && action == null) return titleRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleRow,
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            ?trailing,
            if (action != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: action == 'Health Connect'
                          ? Colors.teal
                          : PulsePathColors.cyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    action!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: PulsePathColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.activity, required this.goals});

  final TodayActivity activity;
  final AsyncValue<List<BackendGoal>> goals;

  @override
  Widget build(BuildContext context) {
    final stepsGoal = _goalStatus(ActivityMetricType.steps, activity.steps);
    final distanceGoal = _goalStatus(
      ActivityMetricType.distance,
      activity.distance,
    );
    final activeGoal = _goalStatus(
      ActivityMetricType.activeMinutes,
      activity.activeMinutes,
    );
    final caloriesGoal = _goalStatus(
      ActivityMetricType.calories,
      activity.calories,
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: ActivityMetricType.steps.shortLabel,
                value: _wholeNumber(activity.steps),
                goal: stepsGoal.label,
                goalDetail: stepsGoal.detail,
                icon: ActivityMetricType.steps.icon,
                accent: ActivityMetricType.steps.accent,
                provenance: activity.stepsProvenance,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: ActivityMetricType.distance.shortLabel,
                value: activity.distance.toStringAsFixed(1),
                unit: ActivityMetricType.distance.unit,
                goal: distanceGoal.label,
                goalDetail: distanceGoal.detail,
                icon: ActivityMetricType.distance.icon,
                accent: ActivityMetricType.distance.accent,
                provenance: activity.distanceProvenance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: ActivityMetricType.activeMinutes.shortLabel,
                value: activity.activeMinutes.round().toString(),
                unit: ActivityMetricType.activeMinutes.unit,
                goal: activeGoal.label,
                goalDetail: activeGoal.detail,
                icon: ActivityMetricType.activeMinutes.icon,
                accent: ActivityMetricType.activeMinutes.accent,
                provenance: activity.activeMinutesProvenance,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: ActivityMetricType.calories.shortLabel,
                value: activity.calories.round().toString(),
                unit: ActivityMetricType.calories.unit,
                goal: caloriesGoal.label,
                goalDetail: caloriesGoal.detail,
                icon: ActivityMetricType.calories.icon,
                accent: ActivityMetricType.calories.accent,
                provenance: activity.caloriesProvenance,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _wholeNumber(double value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  _GoalStatus _goalStatus(ActivityMetricType type, double currentValue) {
    return goals.when(
      data: (values) {
        BackendGoal? matchingGoal;
        for (final goal in values) {
          if (goal.type == type) {
            matchingGoal = goal;
            break;
          }
        }
        if (matchingGoal == null) return const _GoalStatus('No goal set');
        if (matchingGoal.targetValue <= 0) {
          return const _GoalStatus('Goal unavailable');
        }
        if (currentValue >= matchingGoal.targetValue) {
          final above = currentValue - matchingGoal.targetValue;
          final aboveValue = type == ActivityMetricType.distance
              ? above.toStringAsFixed(1)
              : _wholeNumber(above);
          return _GoalStatus(
            'Goal completed',
            '$aboveValue ${type.unit} above goal'.trim(),
          );
        }
        final remaining = matchingGoal.targetValue - currentValue;
        final remainingValue = type == ActivityMetricType.distance
            ? remaining.toStringAsFixed(1)
            : _wholeNumber(remaining);
        return _GoalStatus('$remainingValue ${type.unit} remaining'.trim());
      },
      loading: () => const _GoalStatus('Loading goal…'),
      error: (_, _) => const _GoalStatus('Goal unavailable'),
    );
  }
}

class _GoalStatus {
  const _GoalStatus(this.label, [this.detail]);

  final String label;
  final String? detail;
}

class _HistoryStatusCard extends StatelessWidget {
  const _HistoryStatusCard.loading() : onRetry = null;
  const _HistoryStatusCard.error({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 146,
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Center(
        child: onRetry == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Weekly activity unavailable.'),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
      ),
    );
  }
}

class _HealthSyncIndicator extends ConsumerWidget {
  const _HealthSyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    final syncState = ref.watch(healthSyncControllerProvider);
    final notifier = ref.read(healthSyncControllerProvider.notifier);
    if (syncState.status == HealthSyncStatus.error &&
        (syncState.message?.contains('not available') ?? false)) {
      return const SizedBox.shrink();
    }

    String label;
    IconData icon;
    Color color;

    switch (syncState.status) {
      case HealthSyncStatus.syncing:
        label = 'Syncing...';
        icon = Icons.sync_rounded;
        color = PulsePathColors.textSecondary;
        break;
      case HealthSyncStatus.unauthorized:
        label = 'Setup Health Connect';
        icon = Icons.health_and_safety_outlined;
        color = Colors.orangeAccent;
        break;
      case HealthSyncStatus.error:
        label = 'Sync failed';
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
      case HealthSyncStatus.success:
        if (syncState.message != null &&
            syncState.message!.contains('No Health')) {
          label = 'No new data';
        } else {
          label = 'Synced just now';
        }
        icon = Icons.check_circle_outline;
        color = PulsePathColors.cyan;
        break;
      case HealthSyncStatus.idle:
        if (syncState.lastSync != null) {
          final time = _formatTime(syncState.lastSync!);
          label = 'Synced $time';
          icon = Icons.cloud_done_outlined;
          color = PulsePathColors.textSecondary;
        } else {
          label = 'Sync Health';
          icon = Icons.sync_rounded;
          color = PulsePathColors.textSecondary;
        }
        break;
    }

    return Tooltip(
      message: syncState.message ?? 'Sync Health Connect',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('sync_health_button'),
          borderRadius: BorderRadius.circular(16),
          onTap: syncState.status == HealthSyncStatus.syncing
              ? null
              : () async {
                  if (syncState.status == HealthSyncStatus.unauthorized) {
                    final granted = await notifier.requestPermissions();
                    if (granted) await notifier.sync();
                  } else {
                    await notifier.sync();
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: syncState.status == HealthSyncStatus.unauthorized
                    ? Colors.orangeAccent.withValues(alpha: 0.5)
                    : PulsePathColors.divider,
              ),
              borderRadius: BorderRadius.circular(16),
              color: syncState.status == HealthSyncStatus.syncing
                  ? PulsePathColors.divider.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (syncState.status == HealthSyncStatus.syncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final min = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'pm' : 'am';
    return '$hour:$min$ampm';
  }
}
