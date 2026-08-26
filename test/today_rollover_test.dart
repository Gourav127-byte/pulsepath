import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/features/goals/providers/backend_goals_provider.dart';
import 'package:pulsepath/features/journey/models/activity_insights.dart';
import 'package:pulsepath/features/journey/providers/activity_history_provider.dart';
import 'package:pulsepath/features/profile/models/backend_profile.dart';
import 'package:pulsepath/features/profile/providers/backend_profile_provider.dart';
import 'package:pulsepath/features/today/models/activity_engagement.dart';
import 'package:pulsepath/features/today/models/today_activity.dart';
import 'package:pulsepath/features/today/presentation/pulse_path_shell.dart';
import 'package:pulsepath/features/today/providers/today_activity_provider.dart';

import 'package:pulsepath/features/veya/models/veya_foundation.dart';
import 'package:pulsepath/features/veya/providers/veya_providers.dart';

void main() {
  testWidgets('resume after local date change refreshes Today exactly once', (
    tester,
  ) async {
    var now = DateTime(2026, 8, 14, 12);
    var fetches = 0;
    await tester.pumpWidget(_app(now: () => now, onFetch: () => fetches++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fetches, 1);

    now = DateTime(2026, 8, 15, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fetches, 2);
    expect(find.text('SATURDAY, AUG 15'), findsOneWidget);
  });

  testWidgets('one-shot midnight callback refreshes a foreground app', (
    tester,
  ) async {
    var now = DateTime(2026, 8, 14, 23, 59);
    var fetches = 0;
    void Function()? midnightCallback;
    await tester.pumpWidget(
      _app(
        now: () => now,
        onFetch: () => fetches++,
        timerFactory: (duration, callback) {
          midnightCallback = callback;
          return Timer(const Duration(days: 1), () {});
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fetches, 1);

    now = DateTime(2026, 8, 15);
    midnightCallback!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fetches, 2);
  });
}

Widget _app({
  required DateTime Function() now,
  required VoidCallback onFetch,
  Timer Function(Duration, void Function())? timerFactory,
}) {
  return ProviderScope(
    overrides: [
      currentDateProvider.overrideWithValue(now),
      if (timerFactory != null)
        midnightTimerFactoryProvider.overrideWithValue(timerFactory),
      todayActivityProvider.overrideWith((ref) async {
        onFetch();
        final day = now();
        return TodayActivity(
          date: DateTime(day.year, day.month, day.day),
          steps: 0,
          activeMinutes: 0,
          distance: 0,
          calories: 0,
          dailyScore: 0,
          scoreVersion: 'v2',
          source: 'manual',
          recordingStatus: ActivityRecordingStatus.recorded,
        );
      }),
      backendGoalsProvider.overrideWith((ref) async => const []),
      backendProfileProvider.overrideWith(
        (ref) async => const BackendProfile(
          id: 'profile',
          displayName: 'Tester',
          subtitle: '',
          darkTheme: true,
          reduceMotion: false,
          hapticFeedback: true,
          useMetricUnits: true,
        ),
      ),
      activityHistoryProvider.overrideWith((ref, days) async => const []),
      activityInsightsProvider.overrideWith(
        (ref, days) async => ActivityInsights(
          days: days,
          currentRecordedDays: 0,
          previousRecordedDays: 0,
          stepsChangePercent: null,
          averageScoreChange: null,
          strongestDay: null,
        ),
      ),
      activityEngagementProvider.overrideWith(
        (ref) async => const ActivityEngagement(
          currentStreak: 0,
          bestStreak: 0,
          todayPending: true,
          achievements: [],
        ),
      ),
      veyaFoundationProvider.overrideWith(
        (ref, days) async => const VeyaFoundationResponse(
          evidence: VeyaEvidencePacket(
            schemaVersion: '1.0',
            rangeDays: 7,
            activities: [],
            integrity: VeyaIntegrityLens(
              level: 'sparse',
              confirmedDays: 0,
              legacyDays: 0,
              missingDays: 7,
              confirmedCoverage: 0,
              rationale: '',
            ),
          ),
          response: VeyaStructuredResponse(
            status: 'provider_unavailable',
            summary: 'VEYA insights unavailable.',
            observations: [],
            limitations: [],
            medicalOrCausalClaims: false,
          ),
        ),
      ),
    ],
    child: const MaterialApp(home: PulsePathShell()),
  );
}
