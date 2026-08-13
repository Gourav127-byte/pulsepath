import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';

class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({super.key});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _progress = [0.55, 0.72, 0.46, 0.88, 0.64, 0.82, 0.0];

  @override
  Widget build(BuildContext context) {
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
              const Text(
                '5 of 7 active days',
                style: TextStyle(
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
              children: List.generate(_days.length, (index) {
                final isToday = index == 5;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: _progress[index] == 0
                                ? 0.06
                                : _progress[index],
                            child: Container(
                              width: 8,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? PulsePathColors.cyan
                                    : PulsePathColors.violet.withValues(
                                        alpha: _progress[index] == 0
                                            ? 0.2
                                            : 0.65,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _days[index],
                        style: TextStyle(
                          color: isToday
                              ? PulsePathColors.textPrimary
                              : PulsePathColors.textSecondary,
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
