import 'package:flutter/material.dart';

import '../../../core/activity/activity_metric.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../models/backend_goal.dart';

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final BackendGoal goal;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final type = goal.type;
    final progressPercent = (goal.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: type.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(type.icon, color: type.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.displayLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$progressPercent% of daily target',
                      style: const TextStyle(
                        color: PulsePathColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('edit_goal_${type.name}'),
                tooltip: onEdit == null
                    ? 'Goal editing will be available after backend write support is added.'
                    : 'Edit ${goal.displayLabel} goal',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                key: ValueKey('delete_goal_${type.name}'),
                tooltip: onDelete == null
                    ? 'Goal editing will be available after backend write support is added.'
                    : 'Delete ${goal.displayLabel} goal',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              key: ValueKey('goal_progress_${type.name}'),
              value: goal.progress,
              minHeight: 8,
              color: type.accent,
              backgroundColor: PulsePathColors.surfaceBright,
              semanticsLabel: '${goal.displayLabel} goal progress',
              semanticsValue: '$progressPercent',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_format(goal.currentValue)} ${goal.unit} today',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                'Target ${_format(goal.targetValue)} ${goal.unit}',
                style: const TextStyle(
                  color: PulsePathColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (goal.isCompleted) ...[
            const SizedBox(height: 13),
            Semantics(
              label: '${goal.displayLabel} goal completed',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: type.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: type.accent,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(double value) {
    if (value == value.roundToDouble()) {
      final digits = value.toInt().toString();
      final buffer = StringBuffer();
      for (var index = 0; index < digits.length; index++) {
        if (index > 0 && (digits.length - index) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(digits[index]);
      }
      return buffer.toString();
    }
    return value.toStringAsFixed(1);
  }
}
