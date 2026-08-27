import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/models/backend_goal.dart';
import '../../goals/providers/backend_goals_provider.dart';
import '../models/backend_profile.dart';
import '../providers/backend_profile_provider.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/preference_tile.dart';

final _preferenceWritesProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => {},
);
final _preferenceErrorProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(backendProfileProvider);
    final goals = ref.watch(backendGoalsProvider);
    final preferenceWrites = ref.watch(_preferenceWritesProvider);
    final preferenceError = ref.watch(_preferenceErrorProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            sliver: SliverList.list(
              children: [
                switch (profile) {
                  AsyncData(value: final profileData) => _ProfileContent(
                    profile: profileData,
                    goals: goals.asData?.value ?? const [],
                    preferenceWrites: preferenceWrites,
                    preferenceError: preferenceError,
                    onEditProfile: () => _editProfile(context, ref, profileData),
                    onPreferenceChanged: (field, value) =>
                        _updatePreference(ref, field, value),
                    onLogout: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                  ),
                  AsyncError() => _ProfileError(
                    onRetry: () {
                      ref.invalidate(backendProfileProvider);
                      ref.invalidate(backendGoalsProvider);
                    },
                    onLogout: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    BackendProfile profile,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PulsePathColors.background,
      builder: (context) => EditProfileSheet(
        profile: profile,
        onSave: (fields) async {
          await ref.read(profileRepositoryProvider).updateProfile(fields);
          ref.invalidate(backendProfileProvider);
          await ref.read(backendProfileProvider.future);
        },
      ),
    );
  }

  Future<void> _updatePreference(
    WidgetRef ref,
    String field,
    bool value,
  ) async {
    final writes = ref.read(_preferenceWritesProvider);
    if (writes.contains(field)) return;

    ref.read(_preferenceWritesProvider.notifier).state = {...writes, field};
    ref.read(_preferenceErrorProvider.notifier).state = null;
    try {
      await ref.read(profileRepositoryProvider).updateProfile({field: value});
      ref.invalidate(backendProfileProvider);
      await ref.read(backendProfileProvider.future);
    } catch (_) {
      ref.read(_preferenceErrorProvider.notifier).state =
          'Could not save this preference. Please try again.';
    } finally {
      final currentWrites = ref.read(_preferenceWritesProvider);
      ref.read(_preferenceWritesProvider.notifier).state = {
        for (final pendingField in currentWrites)
          if (pendingField != field) pendingField,
      };
    }
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.goals,
    required this.preferenceWrites,
    required this.preferenceError,
    required this.onEditProfile,
    required this.onPreferenceChanged,
    required this.onLogout,
  });

  final BackendProfile profile;
  final List<BackendGoal> goals;
  final Set<String> preferenceWrites;
  final String? preferenceError;
  final VoidCallback onEditProfile;
  final void Function(String field, bool value) onPreferenceChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final completedGoals = goals.where((goal) => goal.isCompleted).length;
    final overallProgress = goals.isEmpty
        ? 0.0
        : goals.fold<double>(0, (sum, goal) => sum + goal.progress) /
              goals.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHeader(profile: profile, onEdit: onEditProfile),
        const SizedBox(height: 26),
        const _SectionTitle('Daily overview'),
        const SizedBox(height: 12),
        _GoalSummaryCard(
          totalGoals: goals.length,
          completedGoals: completedGoals,
          overallProgress: overallProgress.clamp(0, 1),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Preferences'),
        const SizedBox(height: 12),
        _PreferencesCard(
          profile: profile,
          pendingFields: preferenceWrites,
          errorMessage: preferenceError,
          onChanged: onPreferenceChanged,
        ),
        const SizedBox(height: 26),
        const _SectionTitle('About'),
        const SizedBox(height: 12),
        _AboutCard(onLogout: onLogout),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});

  final BackendProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayName.isEmpty
        ? '?'
        : profile.displayName.characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.heroCardRadius),
        border: Border.all(color: PulsePathColors.divider),
        boxShadow: [
          BoxShadow(
            color: PulsePathColors.violet.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [PulsePathColors.violet, PulsePathColors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (profile.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    profile.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PulsePathColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('edit_profile_button'),
            tooltip: 'Edit profile',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({
    required this.totalGoals,
    required this.completedGoals,
    required this.overallProgress,
  });

  final int totalGoals;
  final int completedGoals;
  final double overallProgress;

  @override
  Widget build(BuildContext context) {
    final percentage = (overallProgress * 100).round();

    return Container(
      key: const Key('profile_goal_summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  value: '$totalGoals',
                  label: 'Active goals',
                ),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryValue(
                  value: '$completedGoals',
                  label: 'Completed',
                ),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryValue(
                  value: '$percentage%',
                  label: 'Avg. progress',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              key: const Key('profile_goal_progress'),
              value: overallProgress,
              minHeight: 8,
              color: PulsePathColors.cyan,
              backgroundColor: PulsePathColors.surfaceBright,
              semanticsLabel: 'Overall daily goal progress',
              semanticsValue: '$percentage',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PulsePathColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 38, color: PulsePathColors.divider);
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.profile,
    required this.pendingFields,
    required this.errorMessage,
    required this.onChanged,
  });

  final BackendProfile profile;
  final Set<String> pendingFields;
  final String? errorMessage;
  final void Function(String field, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final preferenceWritePending = pendingFields.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        children: [
          PreferenceTile(
            title: 'Reduce motion',
            description: 'Prefer calmer transitions and effects',
            value: profile.reduceMotion,
            onChanged: preferenceWritePending
                ? null
                : (value) => onChanged('reduce_motion', value),
            controlKey: const Key('reduce_motion_toggle'),
            disabledCaption: pendingFields.contains('reduce_motion')
                ? 'Saving…'
                : null,
          ),
          const Divider(),
          PreferenceTile(
            title: 'Haptic feedback',
            description: 'Allow tactile response for interactions',
            value: profile.hapticFeedback,
            onChanged: preferenceWritePending
                ? null
                : (value) => onChanged('haptic_feedback', value),
            controlKey: const Key('haptic_feedback_toggle'),
            disabledCaption: pendingFields.contains('haptic_feedback')
                ? 'Saving…'
                : null,
          ),
          const Divider(),
          PreferenceTile(
            title: 'Use metric units',
            description: 'Display distance in kilometres',
            value: profile.useMetricUnits,
            onChanged: preferenceWritePending
                ? null
                : (value) => onChanged('use_metric_units', value),
            controlKey: const Key('metric_units_toggle'),
            disabledCaption: pendingFields.contains('use_metric_units')
                ? 'Saving…'
                : null,
          ),
          const Divider(),
          PreferenceTile(
            title: 'Dark Theme',
            description: 'PulsePath currently uses its dark-first theme',
            value: profile.darkTheme,
            onChanged: null,
            controlKey: const Key('dark_theme_toggle'),
            disabledCaption: 'Light theme coming soon',
          ),
          if (errorMessage != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                errorMessage!,
                key: const Key('preference_save_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.compactCardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: PulsePathColors.violet,
            size: 28,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PulsePath',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'A focused companion for healthier daily momentum.',
                  style: TextStyle(
                    color: PulsePathColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'v1.0.0',
            style: TextStyle(
              color: PulsePathColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const Key('logout_button'),
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry, required this.onLogout});

  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        children: [
          const Text('Could not load profile.'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: onRetry, child: const Text('Retry')),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Logout'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
