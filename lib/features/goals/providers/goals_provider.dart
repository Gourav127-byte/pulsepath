import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/activity/activity_metric.dart';
import '../../../core/activity/mock_activity_data.dart';
import '../models/activity_goal.dart';

final goalsProvider = StateNotifierProvider<GoalsNotifier, List<ActivityGoal>>(
  (ref) => GoalsNotifier(),
);

class GoalsNotifier extends StateNotifier<List<ActivityGoal>> {
  GoalsNotifier({List<ActivityGoal>? initialGoals})
    : super(initialGoals ?? _defaultGoals);

  static final _defaultGoals = [
    _goal(ActivityMetricType.steps, 10000),
    _goal(ActivityMetricType.activeMinutes, 60),
    _goal(ActivityMetricType.calories, 450),
  ];

  bool createGoal(ActivityMetricType type, double targetValue) {
    if (targetValue <= 0 || state.any((goal) => goal.type == type)) {
      return false;
    }

    state = [...state, _goal(type, targetValue)];
    return true;
  }

  bool editTarget(ActivityMetricType type, double targetValue) {
    if (targetValue <= 0 || !state.any((goal) => goal.type == type)) {
      return false;
    }

    state = [
      for (final goal in state)
        if (goal.type == type) goal.copyWithTarget(targetValue) else goal,
    ];
    return true;
  }

  void deleteGoal(ActivityMetricType type) {
    state = state.where((goal) => goal.type != type).toList(growable: false);
  }

  static ActivityGoal _goal(ActivityMetricType type, double targetValue) {
    return ActivityGoal(
      type: type,
      targetValue: targetValue,
      currentValue: MockActivityData.currentValueFor(type),
    );
  }
}
