import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/core/theme/pulse_path_theme.dart';
import 'package:pulsepath/features/today/data/today_activity_repository.dart';
import 'package:pulsepath/features/today/presentation/today_screen.dart';

void main() {
  group('TodayActivityRepository update', () {
    test(
      'PATCHes supplied fields with snake_case and parses response',
      () async {
        late http.Request request;
        final client = MockClient((incoming) async {
          request = incoming;
          return http.Response(_activityJson(steps: 9000, score: 82), 200);
        });
        final repository = TodayActivityRepository(
          ApiClient(baseUrl: 'http://example.test', client: client),
        );

        final activity = await repository.updateTodayActivity(
          steps: 9000,
          activeMinutes: 50,
        );

        expect(request.method, 'PATCH');
        expect(request.url.path, '/activity/today');
        expect(jsonDecode(request.body), {
          'steps': 9000.0,
          'active_minutes': 50.0,
        });
        expect(activity.steps, 9000);
        expect(activity.dailyScore, 82);
        expect(activity.scoreVersion, 'v2');
      },
    );

    test('sends only supplied fields', () async {
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_activityJson(distance: 6.2), 200);
      });
      final repository = TodayActivityRepository(
        ApiClient(baseUrl: 'http://example.test', client: client),
      );

      await repository.updateTodayActivity(distance: 6.2);

      expect(body, {'distance': 6.2});
    });

    test('propagates networking failure cleanly', () async {
      final repository = TodayActivityRepository(
        ApiClient(
          baseUrl: 'http://example.test',
          client: MockClient((_) async => http.Response('error', 500)),
        ),
      );

      expect(
        () => repository.updateTodayActivity(steps: 9000),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('manual activity edit UI', () {
    testWidgets('opens with authoritative backend values prefilled', (
      tester,
    ) async {
      await _pumpToday(tester, MockClient(_standardHandler));

      expect(find.byKey(const Key('edit_activity_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit_activity_button')));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 'activity_steps_field'), '7842');
      expect(_fieldText(tester, 'activity_active_minutes_field'), '46');
      expect(_fieldText(tester, 'activity_calories_field'), '324');
      expect(_fieldText(tester, 'activity_distance_field'), '5.6');
    });

    testWidgets('sends only changed field and refetches Today and Goals', (
      tester,
    ) async {
      var activityGets = 0;
      var goalGets = 0;
      Map<String, dynamic>? patchBody;
      final client = MockClient((request) async {
        if (request.url.path == '/activity/today' && request.method == 'GET') {
          activityGets++;
          return http.Response(
            _activityJson(
              steps: patchBody == null ? 7842 : 9000,
              score: patchBody == null ? 77 : 82,
            ),
            200,
          );
        }
        if (request.url.path == '/activity/today' &&
            request.method == 'PATCH') {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(_activityJson(steps: 9000, score: 82), 200);
        }
        if (request.url.path == '/goals') {
          goalGets++;
          return http.Response('[]', 200);
        }
        return http.Response('not found', 404);
      });
      await _pumpToday(tester, client);

      await _openSheetAndEnterSteps(tester, '9000');
      await tester.tap(find.byKey(const Key('save_activity_button')));
      await tester.pumpAndSettle();

      expect(patchBody, {'steps': 9000.0});
      expect(activityGets, 2);
      expect(goalGets, 2);
      expect(find.text('9,000'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('46'), findsOneWidget);
      expect(find.text('324'), findsOneWidget);
      expect(find.text('5.6'), findsOneWidget);
    });

    testWidgets('no-change save closes without PATCH', (tester) async {
      var patchCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'PATCH') patchCount++;
        return _standardHandler(request);
      });
      await _pumpToday(tester, client);
      await tester.tap(find.byKey(const Key('edit_activity_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_activity_button')));
      await tester.pumpAndSettle();

      expect(patchCount, 0);
      expect(find.text("Edit today's activity"), findsNothing);
    });

    testWidgets('rejects a negative metric without sending PATCH', (
      tester,
    ) async {
      var patchCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'PATCH') patchCount++;
        return _standardHandler(request);
      });
      await _pumpToday(tester, client);
      await _openSheetAndEnterSteps(tester, '-1');

      await tester.tap(find.byKey(const Key('save_activity_button')));
      await tester.pump();

      expect(patchCount, 0);
      expect(find.text('Steps cannot be negative'), findsOneWidget);
    });

    testWidgets('prevents duplicate save taps while PATCH is pending', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      var patchCount = 0;
      var updated = false;
      final client = MockClient((request) async {
        if (request.method == 'PATCH') {
          patchCount++;
          final result = await response.future;
          updated = true;
          return result;
        }
        if (request.url.path == '/goals') return http.Response('[]', 200);
        return http.Response(
          _activityJson(steps: updated ? 9000 : 7842, score: updated ? 82 : 77),
          200,
        );
      });
      await _pumpToday(tester, client);
      await _openSheetAndEnterSteps(tester, '9000');

      await tester.tap(find.byKey(const Key('save_activity_button')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save_activity_button')))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const Key('save_activity_button')),
        warnIfMissed: false,
      );
      expect(patchCount, 1);

      response.complete(
        http.Response(_activityJson(steps: 9000, score: 82), 200),
      );
      await tester.pumpAndSettle();
      expect(patchCount, 1);
    });

    testWidgets('failure keeps sheet open with original values and retry', (
      tester,
    ) async {
      var patchCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'PATCH') {
          patchCount++;
          return http.Response('error', 500);
        }
        return _standardHandler(request);
      });
      await _pumpToday(tester, client);
      await _openSheetAndEnterSteps(tester, '9000');

      await tester.tap(find.byKey(const Key('save_activity_button')));
      await tester.pumpAndSettle();

      expect(patchCount, 1);
      expect(find.text("Edit today's activity"), findsOneWidget);
      expect(find.byKey(const Key('activity_save_error')), findsOneWidget);
      expect(_fieldText(tester, 'activity_steps_field'), '9000');
      expect(find.text('7,842'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save_activity_button')))
            .onPressed,
        isNotNull,
      );
    });
  });
}

Future<http.Response> _standardHandler(http.Request request) async {
  if (request.url.path == '/activity/today') {
    return http.Response(_activityJson(), 200);
  }
  if (request.url.path == '/goals') return http.Response('[]', 200);
  return http.Response('not found', 404);
}

Future<void> _pumpToday(WidgetTester tester, http.Client client) async {
  tester.view.physicalSize = const Size(600, 900);
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
      child: MaterialApp(
        theme: PulsePathTheme.dark,
        home: const Scaffold(body: TodayScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheetAndEnterSteps(WidgetTester tester, String steps) async {
  await tester.tap(find.byKey(const Key('edit_activity_button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('activity_steps_field')), steps);
}

String _fieldText(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
}

String _activityJson({
  num steps = 7842,
  num activeMinutes = 46,
  num calories = 324,
  num distance = 5.6,
  num score = 77,
}) {
  return jsonEncode({
    'date': '2026-08-09',
    'steps': steps,
    'active_minutes': activeMinutes,
    'distance': distance,
    'calories': calories,
    'daily_score': score,
    'score_version': 'v2',
    'source': 'manual',
  });
}
