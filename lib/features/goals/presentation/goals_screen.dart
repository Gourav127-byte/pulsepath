import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/activity/activity_metric.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../models/backend_goal.dart';
import '../providers/backend_goals_provider.dart';
import '../widgets/delete_goal_dialog.dart';
import '../widgets/goal_form_sheet.dart';
import '../widgets/goal_progress_card.dart';

const _allGoalTypesAdded = 'All available goal types are already added.';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(backendGoalsProvider);
    final loadedGoals = switch (goals) {
      AsyncData(value: final value) => value,
      _ => null,
    };
    final availableTypes = loadedGoals == null
        ? const <ActivityMetricType>[]
        : _missingTypes(loadedGoals);
    final canAdd = loadedGoals != null && availableTypes.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            sliver: SliverList.list(
              children: [
                _GoalsHeader(
                  onAdd: canAdd
                      ? () => _createGoal(context, ref, availableTypes)
                      : null,
                  addTooltip: loadedGoals == null
                      ? 'Goals are loading.'
                      : canAdd
                      ? 'Add goal'
                      : _allGoalTypesAdded,
                ),
                const SizedBox(height: 22),
                goals.when(
                  data: (value) => _GoalsContent(
                    goals: value,
                    onEdit: (goal) => _editGoal(context, ref, goal),
                    onDelete: (goal) => _deleteGoal(context, ref, goal),
                    onAdd: () =>
                        _createGoal(context, ref, _missingTypes(value)),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => _GoalsError(
                    onRetry: () => ref.invalidate(backendGoalsProvider),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<ActivityMetricType> _missingTypes(List<BackendGoal> goals) {
    final existingTypes = goals.map((goal) => goal.type).toSet();
    return [
      for (final type in ActivityMetricType.values)
        if (!existingTypes.contains(type)) type,
    ];
  }

  Future<void> _createGoal(
    BuildContext context,
    WidgetRef ref,
    List<ActivityMetricType> availableTypes,
  ) async {
    if (availableTypes.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulsePathColors.background,
      useSafeArea: true,
      builder: (context) => GoalFormSheet.create(
        availableTypes: availableTypes,
        onSave: (type, targetValue) async {
          await ref
              .read(goalsRepositoryProvider)
              .createGoal(type: type, targetValue: targetValue);
          ref.invalidate(backendGoalsProvider);
          await ref.read(backendGoalsProvider.future);
        },
      ),
    );
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    BackendGoal goal,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulsePathColors.background,
      useSafeArea: true,
      builder: (context) => GoalFormSheet.edit(
        goal: goal,
        onSave: (targetValue) async {
          await ref
              .read(goalsRepositoryProvider)
              .updateGoalTarget(goalId: goal.id, targetValue: targetValue);
          ref.invalidate(backendGoalsProvider);
          await ref.read(backendGoalsProvider.future);
        },
      ),
    );
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    BackendGoal goal,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => DeleteGoalDialog(
        goal: goal,
        onDelete: () async {
          await ref.read(goalsRepositoryProvider).deleteGoal(goal.id);
          ref.invalidate(backendGoalsProvider);
          await ref.read(backendGoalsProvider.future);
        },
      ),
    );
  }
}

class _GoalsContent extends StatelessWidget {
  const _GoalsContent({
    required this.goals,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final List<BackendGoal> goals;
  final ValueChanged<BackendGoal> onEdit;
  final ValueChanged<BackendGoal> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return _EmptyGoals(onAdd: onAdd);

    final completedCount = goals.where((goal) => goal.isCompleted).length;
    return Column(
      children: [
        _GoalSummary(completedCount: completedCount, totalCount: goals.length),
        const SizedBox(height: 18),
        for (var index = 0; index < goals.length; index++) ...[
          GoalProgressCard(
            goal: goals[index],
            onEdit: () => onEdit(goals[index]),
            onDelete: () => onDelete(goals[index]),
          ),
          if (index != goals.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _GoalsHeader extends StatelessWidget {
  const _GoalsHeader({required this.onAdd, required this.addTooltip});

  final VoidCallback? onAdd;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY FOCUS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: PulsePathColors.cyan,
                  letterSpacing: 1.25,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Your goals',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Small targets build lasting momentum.',
                style: TextStyle(color: PulsePathColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton.filled(
          key: const Key('add_goal_button'),
          tooltip: addTooltip,
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _GoalSummary extends StatelessWidget {
  const _GoalSummary({required this.completedCount, required this.totalCount});

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Daily goals',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '$completedCount of $totalCount completed',
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: PulsePathColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('goals_empty_state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.flag_outlined,
            size: 38,
            color: PulsePathColors.violet,
          ),
          const SizedBox(height: 14),
          Text(
            'Set your first goal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          const Text(
            'Choose one daily target to start building momentum.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PulsePathColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('create_first_goal_button'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a goal'),
          ),
        ],
      ),
    );
  }
}

class _GoalsError extends StatelessWidget {
  const _GoalsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        children: [
          const Text('Could not load goals.'),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
