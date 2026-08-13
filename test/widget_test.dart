import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepath/main.dart';
import 'package:pulsepath/core/activity/activity_metric.dart';
import 'package:pulsepath/features/goals/models/backend_goal.dart';
import 'package:pulsepath/features/today/models/today_activity.dart';
import 'package:pulsepath/features/today/presentation/today_screen.dart';
import 'package:pulsepath/features/today/providers/today_activity_provider.dart';
import 'package:pulsepath/features/goals/providers/backend_goals_provider.dart';
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
    expect(find.text('of 10,000 steps'), findsOneWidget);
    expect(find.text('8 day streak'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);
  });
}
