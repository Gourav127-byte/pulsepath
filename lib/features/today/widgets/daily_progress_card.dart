import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../../journey/models/activity_history_entry.dart';

class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({required this.history, super.key});

  final List<ActivityHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final byDate = {
      for (final entry in history) DateUtils.dateOnly(entry.date): entry,
    };
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    final recorded = days.where(byDate.containsKey).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This week', style: Theme.of(context).textTheme.titleMedium),
              Text(
                recorded == 0
                    ? 'No activity recorded'
                    : '$recorded recorded days',
                style: const TextStyle(
                  color: PulsePathColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days)
                  Expanded(
                    child: _DayBar(
                      day: day,
                      entry: byDate[day],
                      isToday: day == today,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.entry,
    required this.isToday,
  });

  final DateTime day;
  final ActivityHistoryEntry? entry;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final score = entry?.dailyScore?.clamp(0, 100).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: score == null
                ? Container(width: 8, height: 2, color: PulsePathColors.divider)
                : FractionallySizedBox(
                    heightFactor: score == 0 ? 0.04 : score / 100,
                    child: Container(
                      key: Key(
                        'weekly_score_${day.toIso8601String().substring(0, 10)}',
                      ),
                      width: 8,
                      decoration: BoxDecoration(
                        color: isToday
                            ? PulsePathColors.cyan
                            : PulsePathColors.violet.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1],
          style: TextStyle(
            color: isToday
                ? PulsePathColors.textPrimary
                : PulsePathColors.textSecondary,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
