import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/core/activity/activity_metric.dart';
import 'package:pulsepath/core/activity/mock_activity_data.dart';
import 'package:pulsepath/features/goals/models/activity_goal.dart';
import 'package:pulsepath/features/goals/providers/goals_provider.dart';

void main() {
  group('GoalsNotifier', () {
    test('default goals use the shared Today activity values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final goals = container.read(goalsProvider);

      expect(
        goals
            .firstWhere((goal) => goal.type == ActivityMetricType.steps)
            .currentValue,
        MockActivityData.steps,
      );
      expect(
        goals
            .firstWhere((goal) => goal.type == ActivityMetricType.activeMinutes)
            .currentValue,
        MockActivityData.activeMinutes,
      );
      expect(
        goals
            .firstWhere((goal) => goal.type == ActivityMetricType.calories)
            .currentValue,
        MockActivityData.calories,
      );
    });

    test('creates one goal per metric and prevents duplicates', () {
      final notifier = GoalsNotifier(initialGoals: const []);

      expect(notifier.createGoal(ActivityMetricType.distance, 8), isTrue);
      expect(notifier.createGoal(ActivityMetricType.distance, 10), isFalse);
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.currentValue, MockActivityData.distance);
    });

    test('editing changes only the target and keeps goal type locked', () {
      final notifier = GoalsNotifier(
        initialGoals: const [
          ActivityGoal(
            type: ActivityMetricType.steps,
            targetValue: 10000,
            currentValue: MockActivityData.steps,
          ),
        ],
      );

      expect(notifier.editTarget(ActivityMetricType.steps, 12000), isTrue);
      expect(notifier.state.single.type, ActivityMetricType.steps);
      expect(notifier.state.single.targetValue, 12000);
      expect(notifier.state.single.currentValue, MockActivityData.steps);
    });

    test('rejects zero, negative, and missing-goal edits', () {
      final notifier = GoalsNotifier(initialGoals: const []);

      expect(notifier.createGoal(ActivityMetricType.steps, 0), isFalse);
      expect(notifier.createGoal(ActivityMetricType.steps, -1), isFalse);
      expect(notifier.editTarget(ActivityMetricType.steps, 10000), isFalse);
      expect(notifier.state, isEmpty);
    });

    test('deletes a goal completely', () {
      final notifier = GoalsNotifier(
        initialGoals: const [
          ActivityGoal(
            type: ActivityMetricType.calories,
            targetValue: 450,
            currentValue: MockActivityData.calories,
          ),
        ],
      );

      notifier.deleteGoal(ActivityMetricType.calories);

      expect(notifier.state, isEmpty);
    });
  });

  group('ActivityGoal progress', () {
    test('completion uses current greater than or equal to target', () {
      const equalGoal = ActivityGoal(
        type: ActivityMetricType.steps,
        targetValue: 5000,
        currentValue: 5000,
      );
      const overGoal = ActivityGoal(
        type: ActivityMetricType.steps,
        targetValue: 5000,
        currentValue: 7842,
      );

      expect(equalGoal.isCompleted, isTrue);
      expect(overGoal.isCompleted, isTrue);
    });

    test('visual progress is capped at 100 percent', () {
      const goal = ActivityGoal(
        type: ActivityMetricType.steps,
        targetValue: 5000,
        currentValue: 7842,
      );

      expect(goal.progress, 1);
      expect(goal.currentValue, 7842);
    });
  });
}
