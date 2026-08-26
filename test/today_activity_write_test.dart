import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/core/theme/pulse_path_theme.dart';
import 'package:pulsepath/features/journey/models/activity_history_entry.dart';
import 'package:pulsepath/features/journey/providers/activity_history_provider.dart';
import 'package:pulsepath/features/today/data/today_activity_repository.dart';
import 'package:pulsepath/features/today/presentation/today_screen.dart';
import 'package:pulsepath/features/today/providers/health_sync_provider.dart';
import 'package:pulsepath/features/today/services/health_connect_service.dart';

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
          'source': 'manual',
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

      expect(body, {'distance': 6.2, 'source': 'manual'});
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
    testWidgets(
      'empty-state actions wrap without overflow on a narrow screen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 806);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final client = MockClient((request) async {
          if (request.url.path == '/profile') {
            return http.Response(
              '{"id":"profile-id","display_name":"Mira",'
              '"subtitle":"","dark_theme":true,"reduce_motion":false,'
              '"haptic_feedback":true,"use_metric_units":true}',
              200,
            );
          }
          if (request.url.path == '/activity/today') {
            return http.Response(
              _activityJson(
                steps: 0,
                activeMinutes: 0,
                calories: 0,
                distance: 0,
                score: 0,
                recordingStatus: 'unrecorded',
              ),
              200,
            );
          }
          if (request.url.path == '/activity/history' ||
              request.url.path == '/goals') {
            return http.Response('[]', 200);
          }
          if (request.url.path == '/activity/streak') {
            return http.Response(
              '{"current_streak":0,"today_pending":true}',
              200,
            );
          }
          if (request.url.path == '/activity/engagement') {
            return http.Response(
              '{"current_streak":0,"best_streak":0,"today_pending":true,'
              '"achievements":[]}',
              200,
            );
          }
          return http.Response('not found', 404);
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(
                ApiClient(baseUrl: 'http://example.test', client: client),
              ),
              healthConnectServiceProvider.overrideWithValue(
                _PermissionDeniedHealthService(),
              ),
              activityHistoryProvider(7).overrideWith(
                (ref) => Completer<List<ActivityHistoryEntry>>().future,
              ),
            ],
            child: MaterialApp(
              theme: PulsePathTheme.dark,
              home: const Scaffold(body: TodayScreen()),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await tester.tap(find.byKey(const Key('sync_health_button')));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text('Quick log'), findsOneWidget);
        expect(find.text('Setup Health Connect'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'recorded header keeps its title readable with Health Connect setup',
      (tester) async {
        tester.view.physicalSize = const Size(360, 806);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(
              ApiClient(
                baseUrl: 'http://example.test',
                client: MockClient((request) {
                  if (request.url.path == '/activity/today') {
                    return Future.value(
                      http.Response(
                        _activityJson(source: 'health_connect'),
                        200,
                      ),
                    );
                  }
                  return _standardHandler(request);
                }),
              ),
            ),
            healthConnectServiceProvider.overrideWithValue(
              _PermissionDeniedHealthService(),
            ),
            activityHistoryProvider(7).overrideWith(
              (ref) => Completer<List<ActivityHistoryEntry>>().future,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: PulsePathTheme.dark,
              home: const Scaffold(body: TodayScreen()),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await container.read(healthSyncControllerProvider.notifier).sync();
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text("Today's activity"), findsOneWidget);
        expect(
          tester.getSize(find.text("Today's activity")).width,
          greaterThan(100),
        );
        expect(find.text('Setup Health Connect'), findsOneWidget);
        expect(find.text('Health Connect'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('unrecorded day offers Quick log and confirms a real zero', (
      tester,
    ) async {
      var recorded = false;
      Map<String, dynamic>? patchBody;
      final client = MockClient((request) async {
        if (request.url.path == '/activity/today' &&
            request.method == 'PATCH') {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          recorded = true;
          return http.Response(
            _activityJson(
              steps: 0,
              activeMinutes: 0,
              calories: 0,
              distance: 0,
              score: 0,
              recordingStatus: 'recorded',
            ),
            200,
          );
        }
        if (request.url.path == '/activity/today') {
          return http.Response(
            _activityJson(
              steps: 0,
              activeMinutes: 0,
              calories: 0,
              distance: 0,
              score: 0,
              recordingStatus: recorded ? 'recorded' : 'unrecorded',
            ),
            200,
          );
        }
        if (request.url.path == '/activity/history' ||
            request.url.path == '/goals') {
          return http.Response('[]', 200);
        }
        if (request.url.path == '/activity/streak') {
          return http.Response(
            jsonEncode({
              'current_streak': recorded ? 3 : 2,
              'today_pending': !recorded,
            }),
            200,
          );
        }
        if (request.url.path == '/activity/engagement') {
          return http.Response(
            jsonEncode({
              'current_streak': recorded ? 3 : 2,
              'best_streak': 5,
              'today_pending': !recorded,
              'achievements': const [],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      await _pumpToday(tester, client);

      expect(
        find.byKey(const Key('unrecorded_activity_state')),
        findsOneWidget,
      );
      expect(find.text('No activity recorded yet'), findsOneWidget);
      expect(find.text('Current · today pending'), findsOneWidget);
      expect(find.text('Personal best'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick_log_activity_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_activity_button')));
      await tester.pumpAndSettle();

      expect(patchBody, {'steps': 0.0, 'source': 'manual'});
      expect(find.byKey(const Key('unrecorded_activity_state')), findsNothing);
      expect(find.text('0'), findsWidgets);
      expect(find.text('3 day streak'), findsOneWidget);
    });

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

      expect(patchBody, {'steps': 9000.0, 'source': 'manual'});
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

class _PermissionDeniedHealthService implements HealthConnectService {
  @override
  Future<HealthSyncResult> fetchDailyData() async {
    throw const HealthConnectPermissionException();
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => false;
}

Future<http.Response> _standardHandler(http.Request request) async {
  if (request.url.path == '/activity/history') {
    return http.Response('[]', 200);
  }
  if (request.url.path == '/activity/today') {
    return http.Response(_activityJson(), 200);
  }
  if (request.url.path == '/goals') return http.Response('[]', 200);
  if (request.url.path == '/activity/streak') {
    return http.Response(
      jsonEncode({'current_streak': 1, 'today_pending': false}),
      200,
    );
  }
  if (request.url.path == '/activity/engagement') {
    return http.Response(
      jsonEncode({
        'current_streak': 1,
        'best_streak': 4,
        'today_pending': false,
        'achievements': const [],
      }),
      200,
    );
  }
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
        healthConnectServiceProvider.overrideWithValue(
          _PermissionDeniedHealthService(),
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
  final stepsField = find.byKey(const Key('activity_steps_field'));
  if (stepsField.evaluate().isEmpty) {
    final editButton = find.byKey(const Key('edit_activity_button'));
    final quickLogButton = find.byKey(const Key('quick_log_activity_button'));
    if (editButton.evaluate().isNotEmpty) {
      if (tester.any(find.byType(CustomScrollView))) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(editButton);
    } else if (quickLogButton.evaluate().isNotEmpty) {
      if (tester.any(find.byType(CustomScrollView))) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(quickLogButton);
    }
    await tester.pumpAndSettle();
  }
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
  String recordingStatus = 'recorded',
  String source = 'manual',
}) {
  return jsonEncode({
    'date': '2026-08-09',
    'steps': steps,
    'active_minutes': activeMinutes,
    'distance': distance,
    'calories': calories,
    'daily_score': score,
    'score_version': 'v2',
    'source': source,
    'recording_status': recordingStatus,
  });
}
