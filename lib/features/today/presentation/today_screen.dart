import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/activity/activity_metric.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../../goals/models/backend_goal.dart';
import '../../goals/providers/backend_goals_provider.dart';
import '../../profile/models/backend_profile.dart';
import '../../profile/providers/backend_profile_provider.dart';
import '../models/today_activity.dart';
import '../providers/today_activity_provider.dart';
import '../providers/health_sync_provider.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/daily_score_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/manual_activity_edit_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(todayActivityProvider);
    final profile = ref.watch(backendProfileProvider);
    final goals = ref.watch(backendGoalsProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            sliver: SliverList.list(
              children: [
                _TodayHeader(profile: profile),
                const SizedBox(height: 24),
                activity.when(
                  data: (value) => _ActivityContent(
                    activity: value,
                    goals: goals,
                    onEdit: () => _editActivity(context, ref, value),
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
    TodayActivity activity,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PulsePathColors.background,
      builder: (context) => ManualActivityEditSheet(
        activity: activity,
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
          ref.invalidate(backendGoalsProvider);
          await Future.wait([
            ref.read(todayActivityProvider.future),
            ref.read(backendGoalsProvider.future),
          ]);
        },
      ),
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

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({
    required this.activity,
    required this.goals,
    required this.onEdit,
  });

  final TodayActivity activity;
  final AsyncValue<List<BackendGoal>> goals;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DailyScoreCard(score: activity.dailyScore.round(), streakDays: 8),
        const SizedBox(height: 26),
        _SectionTitle(
          title: "Today's activity",
          action: 'Live',
          onEdit: onEdit,
          trailing: const _HealthSyncIndicator(),
        ),
        const SizedBox(height: 12),
        _MetricsGrid(activity: activity, goals: goals),
        const SizedBox(height: 26),
        const _SectionTitle(title: 'Daily progress'),
        const SizedBox(height: 12),
        const DailyProgressCard(),
      ],
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.profile});

  final AsyncValue<BackendProfile> profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatTodayHeaderDate(DateTime.now()),
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
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
        if (onEdit != null)
          IconButton(
            key: const Key('edit_activity_button'),
            tooltip: "Edit today's activity",
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        if (action != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: PulsePathColors.cyan,
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: ActivityMetricType.steps.shortLabel,
                value: _wholeNumber(activity.steps),
                goal: _goalLabel(ActivityMetricType.steps),
                icon: ActivityMetricType.steps.icon,
                accent: ActivityMetricType.steps.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: ActivityMetricType.distance.shortLabel,
                value: activity.distance.toStringAsFixed(1),
                unit: ActivityMetricType.distance.unit,
                goal: _goalLabel(ActivityMetricType.distance),
                icon: ActivityMetricType.distance.icon,
                accent: ActivityMetricType.distance.accent,
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
                goal: _goalLabel(ActivityMetricType.activeMinutes),
                icon: ActivityMetricType.activeMinutes.icon,
                accent: ActivityMetricType.activeMinutes.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: ActivityMetricType.calories.shortLabel,
                value: activity.calories.round().toString(),
                unit: ActivityMetricType.calories.unit,
                goal: _goalLabel(ActivityMetricType.calories),
                icon: ActivityMetricType.calories.icon,
                accent: ActivityMetricType.calories.accent,
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

  String _goalLabel(ActivityMetricType type) {
    return goals.when(
      data: (values) {
        BackendGoal? matchingGoal;
        for (final goal in values) {
          if (goal.type == type) {
            matchingGoal = goal;
            break;
          }
        }
        if (matchingGoal == null) return 'No goal set';
        final target = type == ActivityMetricType.distance
            ? matchingGoal.targetValue.toStringAsFixed(1)
            : _wholeNumber(matchingGoal.targetValue);
        final unit = type.unit;
        return unit.isEmpty ? 'of $target' : 'of $target $unit';
      },
      loading: () => 'Loading goal…',
      error: (_, _) => 'Goal unavailable',
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (syncState.status == HealthSyncStatus.syncing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PulsePathColors.cyan,
              ),
            ),
          )
        else
          IconButton(
            key: const Key('sync_health_button'),
            icon: Icon(
              Icons.sync_rounded,
              size: 20,
              color: syncState.status == HealthSyncStatus.error
                  ? Colors.redAccent
                  : PulsePathColors.textSecondary,
            ),
            tooltip: 'Sync Health Connect',
            onPressed: () async {
              final granted = await notifier.requestPermissions();
              if (granted) {
                await notifier.sync();
              }
            },
          ),
      ],
    );
  }
}
