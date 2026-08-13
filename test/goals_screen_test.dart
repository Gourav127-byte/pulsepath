import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/activity/activity_metric.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/core/theme/pulse_path_theme.dart';
import 'package:pulsepath/features/goals/presentation/goals_screen.dart';
import 'package:pulsepath/features/goals/models/backend_goal.dart';
import 'package:pulsepath/features/goals/providers/backend_goals_provider.dart';

void main() {
  testWidgets('renders backend goals in stable activity metric order', (
    tester,
  ) async {
    await _pumpGoals(
      tester,
      responseBody:
          '[${_goal('calories', 450, 324)},'
          '${_goal('active_minutes', 60, 46)},'
          '${_goal('distance', 8, 5.6)},'
          '${_goal('steps', 10000, 7842)}]',
    );

    final labels = ['Steps', 'Distance', 'Active minutes', 'Calories'];
    final verticalPositions = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];

    expect(verticalPositions, orderedEquals([...verticalPositions]..sort()));
    expect(find.text('7,842 steps today'), findsOneWidget);
    expect(find.text('5.6 km today'), findsOneWidget);
    expect(find.text('46 min today'), findsOneWidget);
    expect(find.text('324 kcal today'), findsOneWidget);
  });

  testWidgets('enables Add, Edit, and Delete when a type is missing', (
    tester,
  ) async {
    await _pumpGoals(tester, responseBody: '[${_goal('steps', 10000, 7842)}]');

    final addButton = tester.widget<IconButton>(
      find.byKey(const Key('add_goal_button')),
    );
    final editButton = tester.widget<IconButton>(
      find.byKey(const Key('edit_goal_steps')),
    );
    final deleteButton = tester.widget<IconButton>(
      find.byKey(const Key('delete_goal_steps')),
    );

    expect(addButton.onPressed, isNotNull);
    expect(editButton.onPressed, isNotNull);
    expect(deleteButton.onPressed, isNotNull);
    expect(find.byKey(const Key('add_goal_button')), findsOneWidget);
    expect(find.byKey(const Key('edit_goal_steps')), findsOneWidget);
    expect(find.byKey(const Key('delete_goal_steps')), findsOneWidget);
  });

  testWidgets('create mode offers only backend-missing goal types', (
    tester,
  ) async {
    await _pumpGoals(tester, responseBody: _threeGoalResponse());

    await tester.tap(find.byKey(const Key('add_goal_button')));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<ActivityMetricType>>(
      find.descendant(
        of: find.byKey(const Key('goal_type_dropdown')),
        matching: find.byType(DropdownButton<ActivityMetricType>),
      ),
    );
    expect(dropdown.items!.map((item) => item.value), [
      ActivityMetricType.distance,
    ]);
    expect(find.byKey(const Key('locked_goal_type')), findsNothing);
  });

  testWidgets('create validation rejects invalid target values', (
    tester,
  ) async {
    await _pumpGoals(tester, responseBody: _threeGoalResponse());
    await tester.tap(find.byKey(const Key('add_goal_button')));
    await tester.pumpAndSettle();

    for (final entry in {
      '0': 'Target must be greater than zero',
      '-1': 'Target must be greater than zero',
      'nope': 'Enter a valid number',
    }.entries) {
      await tester.enterText(
        find.byKey(const Key('target_value_field')),
        entry.key,
      );
      await tester.tap(find.byKey(const Key('save_goal_button')));
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('successful create POSTs then renders authoritative refetch', (
    tester,
  ) async {
    var created = false;
    var getCount = 0;
    Map<String, dynamic>? postBody;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        postBody = jsonDecode(request.body) as Map<String, dynamic>;
        created = true;
        return http.Response(
          _goal('distance', 8, 5.6, progress: 0.7, id: 'distance-id'),
          201,
        );
      }
      getCount++;
      return http.Response(
        created
            ? '${_threeGoalResponse().substring(0, _threeGoalResponse().length - 1)},${_goal('distance', 8, 5.6, progress: 0.7, id: 'distance-id')}]'
            : _threeGoalResponse(),
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);

    await tester.tap(find.byKey(const Key('add_goal_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal_type_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distance').last);
    await tester.pumpAndSettle();
    final targetFinder = find.byKey(const Key('target_value_field'));
    final targetField = tester.widget<TextFormField>(targetFinder);
    expect(targetFinder, findsOneWidget);
    expect(targetField.enabled, isTrue);
    expect(targetField.controller!.text, isEmpty);
    final editableText = tester.widget<EditableText>(
      find.descendant(of: targetFinder, matching: find.byType(EditableText)),
    );
    final inputDecorator = tester.widget<InputDecorator>(
      find.descendant(of: targetFinder, matching: find.byType(InputDecorator)),
    );
    expect(
      editableText.keyboardType,
      const TextInputType.numberWithOptions(decimal: true, signed: true),
    );
    expect(inputDecorator.decoration.labelText, 'Target');
    expect(inputDecorator.decoration.suffixText, 'km');

    await tester.enterText(targetFinder, '8');
    await tester.tap(find.byKey(const Key('save_goal_button')));
    await tester.pumpAndSettle();

    expect(postBody, {'type': 'distance', 'target_value': 8.0});
    expect(getCount, 2);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('5.6 km today'), findsOneWidget);
    expect(find.text('Target 8 km'), findsOneWidget);
    expect(find.text('70% of daily target'), findsOneWidget);
    expect(find.text('Target 5.6 km'), findsNothing);
    expect(find.text('100% of daily target'), findsNothing);
  });

  testWidgets('duplicate create taps are prevented while POST is pending', (
    tester,
  ) async {
    final postResponse = Completer<http.Response>();
    var postCount = 0;
    var created = false;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        postCount++;
        final response = await postResponse.future;
        created = true;
        return response;
      }
      return http.Response(
        created ? '[${_goal('distance', 8, 5.6, id: 'distance-id')}]' : '[]',
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);
    await tester.tap(find.byKey(const Key('add_goal_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_value_field')), '8');

    await tester.tap(find.byKey(const Key('save_goal_button')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save_goal_button')))
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('save_goal_button')),
      warnIfMissed: false,
    );
    expect(postCount, 1);

    postResponse.complete(
      http.Response(_goal('distance', 8, 5.6, id: 'distance-id'), 201),
    );
    await tester.pumpAndSettle();
    expect(postCount, 1);
  });

  testWidgets('failed create keeps sheet open without a fake goal', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'POST') return http.Response('conflict', 409);
      return http.Response(_threeGoalResponse(), 200);
    });
    await _pumpGoalsWithClient(tester, client);
    await tester.tap(find.byKey(const Key('add_goal_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_value_field')), '8');

    await tester.tap(find.byKey(const Key('save_goal_button')));
    await tester.pumpAndSettle();

    expect(find.text('Create daily goal'), findsOneWidget);
    expect(find.byKey(const Key('goal_save_error')), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('5.6 km today'), findsNothing);
  });

  testWidgets('all four goal types disable Add with explanatory tooltip', (
    tester,
  ) async {
    await _pumpGoals(
      tester,
      responseBody:
          '${_threeGoalResponse().substring(0, _threeGoalResponse().length - 1)},${_goal('distance', 8, 5.6)}]',
    );

    final addButton = tester.widget<IconButton>(
      find.byKey(const Key('add_goal_button')),
    );
    expect(addButton.onPressed, isNull);
    expect(addButton.tooltip, 'All available goal types are already added.');
  });

  testWidgets('delete requires confirmation and Cancel sends no request', (
    tester,
  ) async {
    var deleteCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') deleteCount++;
      return http.Response(
        '[${_goal('distance', 8, 5.6, id: 'distance-id')}]',
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);

    await tester.tap(find.byKey(const Key('delete_goal_distance')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Distance goal?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel_delete_goal_button')));
    await tester.pumpAndSettle();

    expect(deleteCount, 0);
    expect(find.text('Distance'), findsOneWidget);
  });

  testWidgets('confirmed delete uses backend id and authoritative refetch', (
    tester,
  ) async {
    var deleted = false;
    var deletePath = '';
    var getCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deletePath = request.url.path;
        deleted = true;
        return http.Response('', 204);
      }
      getCount++;
      return http.Response(
        deleted ? '[]' : '[${_goal('distance', 8, 5.6, id: 'distance-id')}]',
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);
    await tester.tap(find.byKey(const Key('delete_goal_distance')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_delete_goal_button')));
    await tester.pumpAndSettle();

    expect(deletePath, '/goals/distance-id');
    expect(getCount, 2);
    expect(find.text('Distance'), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('add_goal_button')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('add_goal_button')));
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<ActivityMetricType>>(
      find.descendant(
        of: find.byKey(const Key('goal_type_dropdown')),
        matching: find.byType(DropdownButton<ActivityMetricType>),
      ),
    );
    expect(
      dropdown.items!.map((item) => item.value),
      contains(ActivityMetricType.distance),
    );
  });

  testWidgets('duplicate delete taps are prevented while DELETE is pending', (
    tester,
  ) async {
    final deleteResponse = Completer<http.Response>();
    var deleteCount = 0;
    var deleted = false;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleteCount++;
        final response = await deleteResponse.future;
        deleted = true;
        return response;
      }
      return http.Response(
        deleted ? '[]' : '[${_goal('distance', 8, 5.6, id: 'distance-id')}]',
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);
    await tester.tap(find.byKey(const Key('delete_goal_distance')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_delete_goal_button')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm_delete_goal_button')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('confirm_delete_goal_button')),
      warnIfMissed: false,
    );
    expect(deleteCount, 1);

    deleteResponse.complete(http.Response('', 204));
    await tester.pumpAndSettle();
    expect(deleteCount, 1);
  });

  testWidgets('failed DELETE retains goal and allows retry or cancel', (
    tester,
  ) async {
    var deleteCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleteCount++;
        return http.Response('not found', 404);
      }
      return http.Response(
        '[${_goal('distance', 8, 5.6, id: 'distance-id')}]',
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);
    await tester.tap(find.byKey(const Key('delete_goal_distance')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_delete_goal_button')));
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
    expect(find.byKey(const Key('goal_delete_error')), findsOneWidget);
    expect(find.text('Distance'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm_delete_goal_button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('successful edit PATCHes then refetches authoritative goal', (
    tester,
  ) async {
    var updated = false;
    var patchCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        patchCount++;
        expect(request.url.path, '/goals/00000000-0000-0000-0000-000000000001');
        expect(jsonDecode(request.body), {'target_value': 8000.0});
        updated = true;
        return http.Response(
          _goal('steps', 8000, 7842, progress: 0.98025),
          200,
        );
      }
      return http.Response(
        '[${_goal('steps', updated ? 8000 : 10000, 7842, progress: updated ? 0.98025 : 0.7842)}]',
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);

    await tester.tap(find.byKey(const Key('edit_goal_steps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locked_goal_type')), findsOneWidget);
    expect(find.byKey(const Key('goal_type_dropdown')), findsNothing);

    await tester.enterText(find.byKey(const Key('target_value_field')), '8000');
    await tester.tap(find.byKey(const Key('save_goal_button')));
    await tester.pumpAndSettle();

    expect(patchCount, 1);
    expect(find.text('Target 8,000 steps'), findsOneWidget);
    expect(find.text('98% of daily target'), findsOneWidget);
  });

  testWidgets('goal save prevents duplicate submissions while pending', (
    tester,
  ) async {
    final patchResponse = Completer<http.Response>();
    var patchCount = 0;
    var updated = false;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        patchCount++;
        final response = await patchResponse.future;
        updated = true;
        return response;
      }
      return http.Response(
        '[${_goal('steps', updated ? 8000 : 10000, 7842)}]',
        200,
      );
    });
    await _pumpGoalsWithClient(tester, client);
    await tester.tap(find.byKey(const Key('edit_goal_steps')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_value_field')), '8000');

    await tester.tap(find.byKey(const Key('save_goal_button')));
    await tester.pump();
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save_goal_button')),
    );
    expect(saveButton.onPressed, isNull);
    await tester.tap(
      find.byKey(const Key('save_goal_button')),
      warnIfMissed: false,
    );
    expect(patchCount, 1);

    patchResponse.complete(
      http.Response(_goal('steps', 8000, 7842, progress: 0.98025), 200),
    );
    await tester.pumpAndSettle();
    expect(patchCount, 1);
  });

  testWidgets('failed goal PATCH keeps sheet open and shows save error', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'PATCH') return http.Response('error', 500);
      return http.Response('[${_goal('steps', 10000, 7842)}]', 200);
    });
    await _pumpGoalsWithClient(tester, client);
    await tester.tap(find.byKey(const Key('edit_goal_steps')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_value_field')), '8000');

    await tester.tap(find.byKey(const Key('save_goal_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goal_save_error')), findsOneWidget);
    expect(find.text('Edit daily goal'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save_goal_button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('uses backend progress and completion without recalculating', (
    tester,
  ) async {
    await _pumpGoals(
      tester,
      responseBody:
          '[${_goal('steps', 100, 100, progress: 0.25, isCompleted: false)}]',
    );

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('goal_progress_steps')),
    );
    expect(progress.value, 0.25);
    expect(find.text('25% of daily target'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
    expect(find.text('0 of 1 completed'), findsOneWidget);
  });

  testWidgets('shows loading state in the existing Goals content area', (
    tester,
  ) async {
    final pendingGoals = Completer<List<BackendGoal>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendGoalsProvider.overrideWith((ref) => pendingGoals.future),
        ],
        child: MaterialApp(
          theme: PulsePathTheme.dark,
          home: const GoalsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Your goals'), findsOneWidget);
  });

  testWidgets('failure shows Retry and retry performs a refetch', (
    tester,
  ) async {
    var requestCount = 0;
    final client = MockClient((_) async {
      requestCount++;
      if (requestCount == 1) return http.Response('Server error', 500);
      return http.Response('[${_goal('steps', 10000, 7842)}]', 200);
    });

    await _pumpGoalsWithClient(tester, client);

    expect(find.text('Could not load goals.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('7,842 steps today'), findsOneWidget);
  });

  testWidgets('omits goal types absent from the backend response', (
    tester,
  ) async {
    await _pumpGoals(tester, responseBody: '[${_goal('calories', 450, 324)}]');

    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('Steps'), findsNothing);
    expect(find.text('Distance'), findsNothing);
    expect(find.text('Active minutes'), findsNothing);
  });

  testWidgets('empty backend list enables the existing create control', (
    tester,
  ) async {
    await _pumpGoals(tester, responseBody: '[]');

    expect(find.byKey(const Key('goals_empty_state')), findsOneWidget);
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create a goal'),
    );
    expect(createButton.onPressed, isNotNull);
  });

  testWidgets('Goals screen does not overflow on a small Android viewport', (
    tester,
  ) async {
    await _pumpGoals(
      tester,
      responseBody: '[${_goal('steps', 10000, 7842)}]',
      size: const Size(320, 640),
    );

    expect(find.text('Your goals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _goal(
  String type,
  num target,
  num current, {
  num? progress,
  bool? isCompleted,
  String id = '00000000-0000-0000-0000-000000000001',
}) {
  final backendProgress = progress ?? (current / target).clamp(0, 1);
  final backendCompleted = isCompleted ?? current >= target;
  return '{"id":"$id",'
      '"type":"$type","target_value":$target,"current_value":$current,'
      '"progress":$backendProgress,"is_completed":$backendCompleted}';
}

String _threeGoalResponse() {
  return '[${_goal('steps', 10000, 7842, id: 'steps-id')},'
      '${_goal('active_minutes', 60, 46, id: 'active-id')},'
      '${_goal('calories', 450, 324, id: 'calories-id')}]';
}

Future<void> _pumpGoals(
  WidgetTester tester, {
  required String responseBody,
  Size size = const Size(400, 900),
}) async {
  final client = MockClient((request) async {
    expect(request.url.path, '/goals');
    return http.Response(responseBody, 200);
  });

  await _pumpGoalsWithClient(tester, client, size: size);
}

Future<void> _pumpGoalsWithClient(
  WidgetTester tester,
  http.Client client, {
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(baseUrl: 'http://example.test', client: client),
        ),
      ],
      child: MaterialApp(theme: PulsePathTheme.dark, home: const GoalsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}
