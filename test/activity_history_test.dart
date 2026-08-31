import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/journey/data/activity_history_repository.dart';
import 'package:pulsepath/features/journey/models/activity_history_entry.dart';
import 'package:pulsepath/features/journey/models/activity_insights.dart';
import 'package:pulsepath/features/journey/presentation/journey_screen.dart';
import 'package:pulsepath/features/journey/providers/activity_history_provider.dart';

const _historyJson = <Map<String, dynamic>>[
  {
    'date': '2026-08-12',
    'steps': 12450.0,
    'active_minutes': 63.0,
    'distance': 8.4,
    'calories': 510.0,
    'daily_score': 100.0,
    'score_version': 'v2',
    'source': 'health_connect',
    'recording_status': 'recorded',
  },
];

void main() {
  test('history parses trustworthy backend fields', () {
    final entry = ActivityHistoryEntry.fromJson(_historyJson.single);
    expect(entry.date, DateTime(2026, 8, 12));
    expect(entry.steps, 12450);
    expect(entry.distance, 8.4);
    expect(entry.activeCalories, 510);
    expect(entry.dailyScore, 100);
    expect(entry.scoreVersion, 'v2');
    expect(entry.recordingStatus, HistoryRecordingStatus.recorded);
  });

  test('repository sends bounded authenticated history request', () async {
    late http.Request request;
    final repository = ActivityHistoryRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((value) async {
          request = value;
          return http.Response(jsonEncode(_historyJson), 200);
        }),
        authTokenProvider: () async => 'token',
      ),
    );

    final history = await repository.fetchHistory(days: 7);

    expect(request.url.path, '/activity/history');
    expect(request.url.queryParameters, {'days': '7'});
    expect(request.headers['Authorization'], 'Bearer token');
    expect(history.single.steps, 12450);
  });

  test('insights parse backend-owned comparisons and strongest day', () {
    final insights = ActivityInsights.fromJson({
      'days': 7,
      'current_recorded_days': 2,
      'previous_recorded_days': 2,
      'current_legacy_days': 0,
      'previous_legacy_days': 0,
      'total_steps': 24900.0,
      'average_steps': 12450.0,
      'total_distance': 16.8,
      'total_active_calories': 1020.0,
      'average_score': 91.0,
      'steps_change_percent': 25.0,
      'distance_change_percent': 10.0,
      'active_calories_change_percent': 8.0,
      'average_score_change': 5.0,
      'strongest_steps_day': {
        'date': '2026-08-12',
        'daily_score': 91.0,
        'steps': 12450.0,
      },
      'strongest_score_day': {
        'date': '2026-08-12',
        'daily_score': 91.0,
        'steps': 12450.0,
      },
    });

    expect(insights.stepsChangePercent, 25);
    expect(insights.averageScoreChange, 5);
    expect(insights.strongestDay?.date, DateTime(2026, 8, 12));
    expect(insights.strongestDay?.steps, 12450);
  });

  testWidgets('Journey renders real values and switches metrics', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithHistory(_entries()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_chart')), findsOneWidget);
    expect(find.text('1 confirmed of 7 days'), findsOneWidget);
    expect(find.text('No activity recorded yet.'), findsNothing);

    final chartRect = tester.getRect(find.byKey(const Key('history_chart')));
    await tester.tapAt(Offset(chartRect.right - 4, chartRect.center.dy));
    await tester.pump();
    final selection = tester.widget<Text>(
      find.byKey(const Key('history_selection')),
    );
    expect(selection.data, contains('12450 steps'));

    await tester.tap(find.byKey(const Key('history_metric_distance')));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('history_metric_distance')))
          .selected,
      isTrue,
    );
  });

  testWidgets('Journey shows loading, no-history, and network error states', (
    tester,
  ) async {
    final pending = Completer<List<ActivityHistoryEntry>>();
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          activityHistoryProvider.overrideWith((ref, days) => pending.future),
          activityInsightsProvider.overrideWith(
            (ref, days) async => _emptyInsights(days),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: JourneyScreen())),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(_appWithHistory(const []));
    await tester.pumpAndSettle();
    expect(find.text('No activity recorded yet.'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          activityHistoryProvider.overrideWith(
            (ref, days) => Future.error(const NetworkException('offline')),
          ),
          activityInsightsProvider.overrideWith(
            (ref, days) async => _emptyInsights(days),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: JourneyScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load activity history.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Journey renders deterministic recorded-day insights', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _appWithHistory(
        _entries(),
        insights: ActivityInsights(
          days: 7,
          currentRecordedDays: 2,
          previousRecordedDays: 2,
          stepsChangePercent: 25,
          averageScoreChange: -3,
          strongestStepsDay: StrongestActivityDay(
            date: DateTime(2026, 8, 12),
            dailyScore: 91,
            steps: 12450,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('progress_insights')),
      300,
    );

    expect(
      find.text('Average steps up 25.0% versus the previous 7 days.'),
      findsOneWidget,
    );
    expect(find.textContaining('Strongest confirmed day'), findsOneWidget);
    expect(
      find.textContaining('Comparisons use confirmed recorded days only.'),
      findsOneWidget,
    );
  });

  testWidgets('Journey reports insufficient comparison data honestly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _appWithHistory(
        _entries(),
        insights: ActivityInsights(
          days: 7,
          currentRecordedDays: 1,
          previousRecordedDays: 0,
          stepsChangePercent: null,
          averageScoreChange: null,
          strongestDay: StrongestActivityDay(
            date: DateTime(2026, 8, 12),
            dailyScore: 91,
            steps: 12450,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('progress_insights')),
      300,
    );

    expect(
      find.text('Not enough data yet for period comparisons.'),
      findsOneWidget,
    );
  });

  testWidgets('recorded zero is selectable while missing days stay gaps', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final entries = [
      ActivityHistoryEntry(
        date: today.subtract(const Duration(days: 1)),
        steps: 0,
        activeMinutes: 0,
        distance: 0,
        activeCalories: 0,
        dailyScore: 0,
        scoreVersion: 'v2',
        source: 'manual',
        recordingStatus: HistoryRecordingStatus.recorded,
      ),
      ActivityHistoryEntry(
        date: today,
        steps: 100,
        activeMinutes: 1,
        distance: 0.1,
        activeCalories: 5,
        dailyScore: 2,
        scoreVersion: 'v1',
        source: 'manual',
      ),
    ];
    await tester.pumpWidget(_appWithHistory(entries));
    await tester.pumpAndSettle();

    expect(
      find.text('1 confirmed of 7 days · 1 legacy record'),
      findsOneWidget,
    );
    final rect = tester.getRect(find.byKey(const Key('history_chart')));
    final slot = rect.width / 7;
    await tester.tapAt(Offset(rect.left + slot * 5.5, rect.center.dy));
    await tester.pumpAndSettle();
    final selection0 = tester.widget<Text>(
      find.byKey(const Key('history_selection')),
    );
    expect(selection0.data, contains('0 steps'));

    await tester.tapAt(Offset(rect.left + slot * 6.5, rect.center.dy));
    await tester.pumpAndSettle();
    final selection = tester.widget<Text>(
      find.byKey(const Key('history_selection')),
    );
    expect(selection.data, contains('legacy record'));
  });

  testWidgets('30-day range remains bounded and small-screen scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_appWithHistory(_entries()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30 Days'));
    await tester.pumpAndSettle();
    expect(find.text('1 confirmed of 30 days'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Progress insights'), 250);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison copy follows the selected metric', (tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _appWithHistory(
        _entries(),
        insights: ActivityInsights(
          days: 7,
          currentRecordedDays: 2,
          previousRecordedDays: 2,
          totalDistance: 12,
          distanceChangePercent: 20,
          stepsChangePercent: 10,
          averageScoreChange: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history_metric_distance')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('progress_insights')),
      300,
    );
    expect(
      find.text('Total distance up 20.0% versus the previous 7 days.'),
      findsOneWidget,
    );
  });

  testWidgets('zero previous value gets honest comparison wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithHistory(
        _entries(),
        insights: const ActivityInsights(
          days: 7,
          currentRecordedDays: 1,
          previousRecordedDays: 1,
          stepsChangePercent: null,
          averageScoreChange: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No valid comparison because the previous value is zero.'),
      300,
    );
    expect(
      find.text('No valid comparison because the previous value is zero.'),
      findsOneWidget,
    );
  });

  testWidgets('personal insights card shows trend and weekly consistency', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _appWithHistory(
        _entries(),
        insights: const ActivityInsights(
          days: 7,
          currentRecordedDays: 5,
          previousRecordedDays: 4,
          stepsChangePercent: 20,
          averageScoreChange: 10,
          trend: 'improving',
          consistencyDays: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('personal_insights')),
      300,
    );

    expect(find.text('Personal insights'), findsOneWidget);
    expect(find.text('Improving'), findsOneWidget);
    expect(
      find.text('Activity recorded on 5 of the last 7 days.'),
      findsOneWidget,
    );
    expect(find.text('Based on confirmed recorded days only.'), findsOneWidget);
  });

  testWidgets('personal insights card shows insufficient data honestly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _appWithHistory(
        const [],
        insights: const ActivityInsights(
          days: 7,
          currentRecordedDays: 0,
          previousRecordedDays: 0,
          stepsChangePercent: null,
          averageScoreChange: null,
          trend: 'insufficient_data',
          consistencyDays: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Personal insights'), 300);

    expect(find.text('Not enough data yet.'), findsAtLeast(1));
    expect(
      find.text('Activity recorded on 0 of the last 7 days.'),
      findsOneWidget,
    );
    expect(find.text('Based on confirmed recorded days only.'), findsOneWidget);
  });

  testWidgets('personal insights card counts recorded zero in consistency', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _appWithHistory(
        _entries(),
        insights: const ActivityInsights(
          days: 7,
          currentRecordedDays: 3,
          previousRecordedDays: 2,
          stepsChangePercent: null,
          averageScoreChange: -2,
          trend: 'stable',
          consistencyDays: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('personal_insights')),
      300,
    );

    expect(find.text('Stable'), findsOneWidget);
    expect(
      find.text('Activity recorded on 3 of the last 7 days.'),
      findsOneWidget,
    );
  });
}

Widget _appWithHistory(
  List<ActivityHistoryEntry> entries, {
  ActivityInsights? insights,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      activityHistoryProvider.overrideWith((ref, days) async => entries),
      activityInsightsProvider.overrideWith(
        (ref, days) async => insights ?? _emptyInsights(days),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: JourneyScreen())),
  );
}

ActivityInsights _emptyInsights(int days) {
  return ActivityInsights(
    days: days,
    currentRecordedDays: 0,
    previousRecordedDays: 0,
    stepsChangePercent: null,
    averageScoreChange: null,
    strongestDay: null,
  );
}

List<ActivityHistoryEntry> _entries() {
  return [
    ActivityHistoryEntry(
      date: DateUtils.dateOnly(DateTime.now()),
      steps: 12450,
      activeMinutes: 63,
      distance: 8.4,
      activeCalories: 510,
      dailyScore: 100,
      scoreVersion: 'v2',
      source: 'health_connect',
      recordingStatus: HistoryRecordingStatus.recorded,
    ),
  ];
}
