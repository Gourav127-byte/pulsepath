import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/core/theme/pulse_path_theme.dart';
import 'package:pulsepath/features/today/models/today_activity.dart';
import 'package:pulsepath/features/today/presentation/today_screen.dart';
import 'package:pulsepath/features/today/providers/today_activity_provider.dart';

void main() {
  testWidgets('shows a simple loading indicator in the Today card', (
    tester,
  ) async {
    final pendingActivity = Completer<TodayActivity>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayActivityProvider.overrideWith((ref) => pendingActivity.future),
        ],
        child: MaterialApp(
          theme: PulsePathTheme.dark,
          home: const TodayScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Note: greeting is now dynamic based on backendProfileProvider
  });

  testWidgets('retry refetches activity and renders backend values', (
    tester,
  ) async {
    var activityRequestCount = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/profile':
          return http.Response(
            '{"id":"profile-id","display_name":"Mira",'
            '"subtitle":"Building better daily habits","dark_theme":true,'
            '"reduce_motion":false,"haptic_feedback":true,'
            '"use_metric_units":true}',
            200,
          );
        case '/goals':
          return http.Response('[]', 200);
        case '/activity/history':
          return http.Response('[]', 200);
        case '/activity/today':
          activityRequestCount++;
          if (activityRequestCount == 1) {
            return http.Response('Server error', 500);
          }
          return http.Response(
            '{"date":"2026-08-08","steps":7842,"active_minutes":46,'
            '"distance":5.6,"calories":324,"daily_score":77,'
            '"score_version":"v1","source":"manual"}',
            200,
          );
        default:
          return http.Response('Not found', 404);
      }
    });

    await tester.pumpWidget(_testApp(client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Could not load today's activity."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(activityRequestCount, 2);
    expect(find.text('77'), findsOneWidget);
    expect(find.text('7,842'), findsOneWidget);
    expect(find.text('Streak unavailable'), findsOneWidget);
  });
}

Widget _testApp(http.Client client) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(
        ApiClient(baseUrl: 'http://example.test', client: client),
      ),
    ],
    child: MaterialApp(theme: PulsePathTheme.dark, home: const TodayScreen()),
  );
}
