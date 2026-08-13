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
import 'package:pulsepath/features/goals/models/backend_goal.dart';
import 'package:pulsepath/features/goals/providers/backend_goals_provider.dart';
import 'package:pulsepath/features/profile/models/backend_profile.dart';
import 'package:pulsepath/features/profile/presentation/profile_screen.dart';
import 'package:pulsepath/features/profile/providers/backend_profile_provider.dart';

void main() {
  testWidgets('renders backend profile values and preference states', (
    tester,
  ) async {
    await _pumpProfile(tester);

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Building better daily habits'), findsOneWidget);
    expect(_switch(tester, 'dark_theme_toggle').value, isTrue);
    expect(_switch(tester, 'reduce_motion_toggle').value, isFalse);
    expect(_switch(tester, 'haptic_feedback_toggle').value, isTrue);
    expect(_switch(tester, 'metric_units_toggle').value, isTrue);
  });

  testWidgets('edit profile button is enabled', (tester) async {
    await _pumpProfile(tester);

    final editButton = tester.widget<IconButton>(
      find.byKey(const Key('edit_profile_button')),
    );
    expect(editButton.onPressed, isNotNull);
    expect(editButton.tooltip, 'Edit profile');
  });

  testWidgets('three preferences are enabled while Dark Theme stays disabled', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      profileBody: _profileJson(
        darkTheme: false,
        reduceMotion: true,
        hapticFeedback: false,
        useMetricUnits: false,
      ),
    );

    expect(_switch(tester, 'dark_theme_toggle').value, isFalse);
    expect(_switch(tester, 'reduce_motion_toggle').value, isTrue);
    expect(_switch(tester, 'haptic_feedback_toggle').value, isFalse);
    expect(_switch(tester, 'metric_units_toggle').value, isFalse);
    expect(_switch(tester, 'dark_theme_toggle').onChanged, isNull);
    expect(_switch(tester, 'reduce_motion_toggle').onChanged, isNotNull);
    expect(_switch(tester, 'haptic_feedback_toggle').onChanged, isNotNull);
    expect(_switch(tester, 'metric_units_toggle').onChanged, isNotNull);
    expect(find.text('Light theme coming soon'), findsOneWidget);
  });

  testWidgets('valid profile edit PATCHes and refetches backend profile', (
    tester,
  ) async {
    var displayName = 'Alex';
    Map<String, dynamic>? patchBody;
    final client = MockClient((request) async {
      if (request.url.path == '/goals') return http.Response('[]', 200);
      if (request.method == 'PATCH') {
        patchBody = jsonDecode(request.body) as Map<String, dynamic>;
        displayName = patchBody!['display_name'] as String;
      }
      return http.Response(_profileJson(displayName: displayName), 200);
    });
    await _pumpProfileWithClient(tester, client);

    await tester.tap(find.byKey(const Key('edit_profile_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile_name_field')),
      '  Alex Test  ',
    );
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pumpAndSettle();

    expect(patchBody, {'display_name': 'Alex Test'});
    expect(find.text('Alex Test'), findsOneWidget);
  });

  testWidgets('profile edit validation remains active', (tester) async {
    await _pumpProfile(tester);
    await tester.tap(find.byKey(const Key('edit_profile_button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profile_name_field')), '   ');
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pump();
    expect(find.text('Display name is required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile_name_field')),
      List.filled(41, 'A').join(),
    );
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pump();
    expect(
      find.text('Display name must be 40 characters or less'),
      findsOneWidget,
    );
  });

  for (final preference in [
    ('reduce_motion', 'reduce_motion_toggle', false),
    ('haptic_feedback', 'haptic_feedback_toggle', true),
    ('use_metric_units', 'metric_units_toggle', true),
  ]) {
    testWidgets('${preference.$1} writes only its field and refetches', (
      tester,
    ) async {
      final values = <String, bool>{
        'dark_theme': true,
        'reduce_motion': false,
        'haptic_feedback': true,
        'use_metric_units': true,
      };
      Map<String, dynamic>? patchBody;
      final client = MockClient((request) async {
        if (request.url.path == '/goals') return http.Response('[]', 200);
        if (request.method == 'PATCH') {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          values[preference.$1] = patchBody![preference.$1] as bool;
        }
        return http.Response(_profileJsonFromValues(values), 200);
      });
      await _pumpProfileWithClient(tester, client);
      await tester.ensureVisible(find.byKey(Key(preference.$2)));

      await tester.tap(find.byKey(Key(preference.$2)));
      await tester.pumpAndSettle();

      expect(patchBody, {preference.$1: !preference.$3});
      expect(_switch(tester, preference.$2).value, !preference.$3);
    });
  }

  testWidgets('failed preference PATCH retains old backend value', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/goals') return http.Response('[]', 200);
      if (request.method == 'PATCH') return http.Response('error', 500);
      return http.Response(_profileJson(), 200);
    });
    await _pumpProfileWithClient(tester, client);
    await tester.ensureVisible(find.byKey(const Key('haptic_feedback_toggle')));

    await tester.tap(find.byKey(const Key('haptic_feedback_toggle')));
    await tester.pumpAndSettle();

    expect(_switch(tester, 'haptic_feedback_toggle').value, isTrue);
    expect(find.byKey(const Key('preference_save_error')), findsOneWidget);
  });

  testWidgets('shows loading state in the existing Profile content area', (
    tester,
  ) async {
    final pendingProfile = Completer<BackendProfile>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendProfileProvider.overrideWith((ref) => pendingProfile.future),
          backendGoalsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: PulsePathTheme.dark,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('failure shows Retry and retry performs a refetch', (
    tester,
  ) async {
    var profileRequestCount = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/goals') return http.Response('[]', 200);
      if (request.url.path == '/profile') {
        profileRequestCount++;
        if (profileRequestCount == 1) {
          return http.Response('Server error', 500);
        }
        return http.Response(_profileJson(), 200);
      }
      return http.Response('Not found', 404);
    });

    await _pumpProfileWithClient(tester, client);

    expect(find.text('Could not load profile.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(profileRequestCount, 2);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('goal summary consumes backendGoalsProvider values', (
    tester,
  ) async {
    const goals = [
      BackendGoal(
        id: '1',
        type: ActivityMetricType.steps,
        targetValue: 10000,
        currentValue: 100,
        progress: 0.2,
        isCompleted: true,
      ),
      BackendGoal(
        id: '2',
        type: ActivityMetricType.calories,
        targetValue: 450,
        currentValue: 10,
        progress: 0.8,
        isCompleted: false,
      ),
    ];
    await _pumpProfile(tester, goals: goals);

    final summary = find.byKey(const Key('profile_goal_summary'));
    expect(
      find.descendant(of: summary, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('50%')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('profile_goal_progress')),
          )
          .value,
      0.5,
    );
  });

  testWidgets('Profile screen does not overflow on a small Android viewport', (
    tester,
  ) async {
    await _pumpProfile(tester, size: const Size(320, 640));

    expect(find.text('Alex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Switch _switch(WidgetTester tester, String key) {
  return tester.widget<Switch>(find.byKey(Key(key)));
}

String _profileJson({
  String displayName = 'Alex',
  String subtitle = 'Building better daily habits',
  bool darkTheme = true,
  bool reduceMotion = false,
  bool hapticFeedback = true,
  bool useMetricUnits = true,
}) {
  return '{"id":"11111111-1111-1111-1111-111111111111",'
      '"display_name":"$displayName",'
      '"subtitle":"$subtitle",'
      '"dark_theme":$darkTheme,"reduce_motion":$reduceMotion,'
      '"haptic_feedback":$hapticFeedback,'
      '"use_metric_units":$useMetricUnits}';
}

String _profileJsonFromValues(Map<String, bool> values) {
  return _profileJson(
    darkTheme: values['dark_theme']!,
    reduceMotion: values['reduce_motion']!,
    hapticFeedback: values['haptic_feedback']!,
    useMetricUnits: values['use_metric_units']!,
  );
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  String? profileBody,
  List<BackendGoal> goals = const [],
  Size size = const Size(400, 900),
}) async {
  final client = MockClient((request) async {
    if (request.url.path == '/profile') {
      return http.Response(profileBody ?? _profileJson(), 200);
    }
    if (request.url.path == '/goals') return http.Response('[]', 200);
    return http.Response('Not found', 404);
  });

  await _pumpProfileWithClient(tester, client, goals: goals, size: size);
}

Future<void> _pumpProfileWithClient(
  WidgetTester tester,
  http.Client client, {
  List<BackendGoal>? goals,
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
        if (goals != null)
          backendGoalsProvider.overrideWith((ref) async => goals),
      ],
      child: MaterialApp(
        theme: PulsePathTheme.dark,
        home: const Scaffold(body: ProfileScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
