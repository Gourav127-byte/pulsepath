import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../today/presentation/pulse_path_shell.dart';
import '../../today/providers/health_sync_provider.dart';
import '../../today/providers/today_activity_provider.dart';
import '../../goals/providers/backend_goals_provider.dart';
import '../../journey/providers/activity_history_provider.dart';
import '../../profile/providers/backend_profile_provider.dart';
import '../../veya/providers/veya_providers.dart';
import '../providers/auth_provider.dart';
import 'auth_screens.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final previousUser = previous?.user?.id;
      final nextUser = next.user?.id;
      final leftAuthenticatedSession =
          previous?.status == AuthStatus.authenticated &&
          next.status != AuthStatus.authenticated;
      final changedUser =
          previousUser != null && nextUser != null && previousUser != nextUser;
      if (leftAuthenticatedSession || changedUser) {
        _purgeUserScopedState(ref);
      }
    });

    ref.listen(unauthorizedProvider, (previous, next) {
      if (next) {
        ref.read(authControllerProvider.notifier).logout();
        ref.read(unauthorizedProvider.notifier).state = false;
      }
    });

    final auth = ref.watch(authControllerProvider);
    return switch (auth.status) {
      AuthStatus.checking => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AuthStatus.authenticated => const PulsePathShell(),
      _ => const AuthFlow(),
    };
  }

  void _purgeUserScopedState(WidgetRef ref) {
    ref.read(selectedTabProvider.notifier).state = 0;
    ref.invalidate(healthSyncControllerProvider);
    ref.invalidate(todayActivityProvider);
    ref.invalidate(dailyScoreExplanationProvider);
    ref.invalidate(activityStreakProvider);
    ref.invalidate(activityEngagementProvider);
    ref.invalidate(backendGoalsProvider);
    ref.invalidate(backendProfileProvider);
    ref.invalidate(activityHistoryProvider(7));
    ref.invalidate(activityHistoryProvider(30));
    ref.invalidate(activityInsightsProvider(7));
    ref.invalidate(activityInsightsProvider(30));
    ref.invalidate(veyaFoundationProvider(7));
    ref.invalidate(veyaFoundationProvider(30));
    ref.invalidate(veyaChatProvider);
  }
}
