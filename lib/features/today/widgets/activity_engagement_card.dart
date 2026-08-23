import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../models/activity_engagement.dart';

class ActivityEngagementCard extends StatelessWidget {
  const ActivityEngagementCard({required this.engagement, super.key})
    : isLoading = false,
      onRetry = null;

  const ActivityEngagementCard.loading({super.key})
    : engagement = null,
      isLoading = true,
      onRetry = null;

  const ActivityEngagementCard.error({required this.onRetry, super.key})
    : engagement = null,
      isLoading = false;

  final ActivityEngagement? engagement;
  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('activity_engagement_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (onRetry != null) {
      return Row(
        children: [
          const Expanded(child: Text('Momentum unavailable.')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }

    final value = engagement!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Momentum', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StreakStat(
                label: value.todayPending
                    ? 'Current · today pending'
                    : 'Current',
                value: value.currentStreak,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StreakStat(
                label: 'Personal best',
                value: value.bestStreak,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Milestones', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final achievement in value.achievements)
              _AchievementChip(achievement: achievement),
          ],
        ),
      ],
    );
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulsePathColors.surfaceBright,
        borderRadius: BorderRadius.circular(PulsePathSizes.compactCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PulsePathColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement});

  final ActivityAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Tooltip(
      message: achievement.description,
      child: Container(
        key: Key('achievement_${achievement.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: unlocked
              ? PulsePathColors.violet.withValues(alpha: 0.14)
              : PulsePathColors.surfaceBright,
          borderRadius: BorderRadius.circular(PulsePathSizes.controlRadius),
          border: Border.all(
            color: unlocked
                ? PulsePathColors.violet.withValues(alpha: 0.55)
                : PulsePathColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
              size: 15,
              color: unlocked
                  ? PulsePathColors.cyan
                  : PulsePathColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              achievement.title,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
