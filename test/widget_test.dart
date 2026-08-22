import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepath/main.dart';
import 'package:pulsepath/core/activity/activity_metric.dart';
import 'package:pulsepath/core/theme/pulse_path_theme.dart';
import 'package:pulsepath/features/goals/models/backend_goal.dart';
import 'package:pulsepath/features/today/models/today_activity.dart';
import 'package:pulsepath/features/today/models/activity_streak.dart';
import 'package:pulsepath/features/today/models/activity_engagement.dart';
import 'package:pulsepath/features/today/models/daily_score_explanation.dart';
import 'package:pulsepath/features/today/presentation/today_screen.dart';
import 'package:pulsepath/features/today/widgets/activity_engagement_card.dart';
import 'package:pulsepath/features/today/providers/today_activity_provider.dart';
import 'package:pulsepath/features/goals/providers/backend_goals_provider.dart';
import 'package:pulsepath/features/journey/models/activity_history_entry.dart';
import 'package:pulsepath/features/journey/models/activity_insights.dart';
import 'package:pulsepath/features/journey/providers/activity_history_provider.dart';
import 'package:pulsepath/features/profile/models/backend_profile.dart';
import 'package:pulsepath/features/profile/providers/backend_profile_provider.dart';
import 'package:pulsepath/features/auth/models/auth_user.dart';
import 'package:pulsepath/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('Today screen shows daily activity data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController.forTesting(
              const AuthState(
                AuthStatus.authenticated,
                user: AuthUser(id: '1', email: 'alex@example.com'),
              ),
            ),
          ),
          todayActivityProvider.overrideWith(
            (ref) async => TodayActivity(
              date: DateTime(2026, 8, 8),
              steps: 12450,
              activeMinutes: 46,
              distance: 5.6,
              calories: 324,
              dailyScore: 77,
              scoreVersion: 'v1',
              source: 'manual',
            ),
          ),
          activityStreakProvider.overrideWith(
            (ref) async =>
                const ActivityStreak(currentStreak: 4, todayPending: false),
          ),
          activityEngagementProvider.overrideWith(
            (ref) async => ActivityEngagement(
              currentStreak: 4,
              bestStreak: 7,
              todayPending: false,
              achievements: const [
                ActivityAchievement(
                  id: 'first_confirmed_activity',
                  title: 'First confirmed activity',
                  description: 'First day recorded.',
                  unlocked: true,
                  progress: 1,
                ),
                ActivityAchievement(
                  id: 'streak_14',
                  title: '14-day streak',
                  description: 'Reach fourteen days.',
                  unlocked: false,
                  progress: 0.5,
                ),
              ],
            ),
          ),
          dailyScoreExplanationProvider.overrideWith(
            (ref) async => const DailyScoreExplanation(
              score: 77,
              scoreVersion: 'v1',
              available: true,
              message: null,
              components: [
                DailyScoreComponent(
                  metric: 'steps',
                  value: 7842,
                  target: 10000,
                  progress: 0.7842,
                  weight: 0.5,
                  points: 39.21,
                ),
                DailyScoreComponent(
                  metric: 'active_minutes',
                  value: 46,
                  target: 60,
                  progress: 0.7666666667,
                  weight: 0.3,
                  points: 23,
                ),
                DailyScoreComponent(
                  metric: 'calories',
                  value: 324,
                  target: 450,
                  progress: 0.72,
                  weight: 0.2,
                  points: 14.4,
                ),
              ],
            ),
          ),
          backendGoalsProvider.overrideWith(
            (ref) async => const [
              BackendGoal(
                id: 'steps-goal',
                type: ActivityMetricType.steps,
                targetValue: 10000,
                currentValue: 12450,
                progress: 1,
                isCompleted: true,
              ),
            ],
          ),
          backendProfileProvider.overrideWith(
            (ref) async => const BackendProfile(
              id: '1',
              displayName: 'Mira',
              subtitle: 'Building better daily habits',
              darkTheme: true,
              reduceMotion: false,
              hapticFeedback: true,
              useMetricUnits: true,
            ),
          ),
          activityHistoryProvider.overrideWith(
            (ref, days) async => [
              ActivityHistoryEntry(
                date: DateTime.now(),
                steps: 12450,
                activeMinutes: 46,
                distance: 5.6,
                activeCalories: 324,
                dailyScore: 77,
                scoreVersion: 'v1',
                source: 'manual',
              ),
            ],
          ),
          activityInsightsProvider.overrideWith(
            (ref, days) async => ActivityInsights(
              days: days,
              currentRecordedDays: 1,
              previousRecordedDays: 0,
              stepsChangePercent: null,
              averageScoreChange: null,
              strongestDay: null,
            ),
          ),
        ],
        child: const PulsePathApp(showStartup: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Mira'), findsOneWidget);
    expect(find.textContaining('Alex'), findsNothing);
    expect(find.text(formatTodayHeaderDate(DateTime.now())), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
    expect(find.text('12,450'), findsOneWidget);
    expect(find.text('Goal completed'), findsOneWidget);
    expect(find.text('2,450 steps above goal'), findsOneWidget);
    expect(find.text('4 day streak'), findsOneWidget);
    expect(find.text('Personal best'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(
      find.byKey(const Key('achievement_first_confirmed_activity')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('achievement_streak_14')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);

    await tester.tap(find.byKey(const Key('explain_daily_score_button')));
    await tester.pumpAndSettle();
    expect(find.text('Why this score?'), findsNWidgets(2));
    expect(find.byKey(const Key('score_component_steps')), findsOneWidget);
    expect(find.text('7,842 / 10,000 steps · 78.4%'), findsOneWidget);
    expect(find.byKey(const Key('explained_daily_score')), findsOneWidget);
  });

  testWidgets('engagement card remains compact on a Redmi-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PulsePathTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityEngagementCard(
              engagement: ActivityEngagement(
                currentStreak: 2,
                bestStreak: 7,
                todayPending: true,
                achievements: [
                  for (final target in [1, 3, 7, 14, 30, 31])
                    ActivityAchievement(
                      id: 'milestone_$target',
                      title: '$target-day milestone',
                      description: 'Recorded milestone.',
                      unlocked: target <= 7,
                      progress: target <= 7 ? 1 : 0.25,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current · today pending'), findsOneWidget);
    expect(find.text('Personal best'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
