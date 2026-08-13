import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/activity/activity_metric.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/goals/data/goals_repository.dart';
import 'package:pulsepath/features/goals/models/backend_goal.dart';

void main() {
  const goalJson = <String, dynamic>{
    'id': '11111111-1111-1111-1111-111111111111',
    'type': 'active_minutes',
    'target_value': 60.0,
    'current_value': 46.0,
    'progress': 0.7666666667,
    'is_completed': false,
  };

  test('BackendGoal parses every snake_case response field', () {
    final goal = BackendGoal.fromJson(goalJson);

    expect(goal.id, '11111111-1111-1111-1111-111111111111');
    expect(goal.type, ActivityMetricType.activeMinutes);
    expect(goal.targetValue, 60);
    expect(goal.currentValue, 46);
    expect(goal.progress, closeTo(0.7666666667, 0.0000000001));
    expect(goal.isCompleted, isFalse);
  });

  test('GoalsRepository performs GET /goals and returns typed goals', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/goals');
      return http.Response(
        '[{"id":"11111111-1111-1111-1111-111111111111",'
        '"type":"active_minutes","target_value":60.0,'
        '"current_value":46.0,"progress":0.7666666667,'
        '"is_completed":false}]',
        200,
      );
    });
    final repository = GoalsRepository(
      ApiClient(baseUrl: 'http://example.test', client: client),
    );

    final goals = await repository.fetchGoals();

    expect(goals, hasLength(1));
    expect(goals.single.id, goalJson['id']);
    expect(goals.single.progress, goalJson['progress']);
    expect(goals.single.isCompleted, goalJson['is_completed']);
  });

  test(
    'GoalsRepository PATCH sends only target_value and parses result',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/goals/goal-1');
        expect(jsonDecode(request.body), {'target_value': 8000.0});
        return http.Response(
          '{"id":"goal-1","type":"steps","target_value":8000.0,'
          '"current_value":7842.0,"progress":0.98025,'
          '"is_completed":false}',
          200,
        );
      });
      final repository = GoalsRepository(
        ApiClient(baseUrl: 'http://example.test', client: client),
      );

      final goal = await repository.updateGoalTarget(
        goalId: 'goal-1',
        targetValue: 8000,
      );

      expect(goal.id, 'goal-1');
      expect(goal.targetValue, 8000);
      expect(goal.progress, 0.98025);
      expect(goal.isCompleted, isFalse);
    },
  );

  test('GoalsRepository POST maps activeMinutes and parses result', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/goals');
      expect(jsonDecode(request.body), {
        'type': 'active_minutes',
        'target_value': 75.0,
      });
      return http.Response(
        '{"id":"goal-2","type":"active_minutes",'
        '"target_value":75.0,"current_value":46.0,'
        '"progress":0.5,"is_completed":false}',
        201,
      );
    });
    final repository = GoalsRepository(
      ApiClient(baseUrl: 'http://example.test', client: client),
    );

    final goal = await repository.createGoal(
      type: ActivityMetricType.activeMinutes,
      targetValue: 75,
    );

    expect(goal.id, 'goal-2');
    expect(goal.type, ActivityMetricType.activeMinutes);
    expect(goal.progress, 0.5);
  });

  test(
    'GoalsRepository DELETE uses the backend goal id and accepts 204',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/goals/backend-id');
        return http.Response('', 204);
      });
      final repository = GoalsRepository(
        ApiClient(baseUrl: 'http://example.test', client: client),
      );

      await expectLater(repository.deleteGoal('backend-id'), completes);
    },
  );
}
