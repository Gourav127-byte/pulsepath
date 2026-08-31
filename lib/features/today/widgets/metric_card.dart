import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.goal,
    this.goalDetail,
    required this.icon,
    required this.accent,
    this.unit,
    this.provenance,
    super.key,
  });

  final String label;
  final String value;
  final String goal;
  final String? goalDetail;
  final IconData icon;
  final Color accent;
  final String? unit;
  final String? provenance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.compactCardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: PulsePathColors.textSecondary),
                      ),
                    ),
                    if (provenance == 'health_connect' ||
                        provenance == 'health_connect_recorded' ||
                        provenance == 'pulsepath_gps_recorded' ||
                        provenance == 'manual' ||
                        provenance == 'step_estimated' ||
                        provenance == 'blended') ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: (provenance == 'health_connect' ||
                                  provenance == 'health_connect_recorded')
                              ? Colors.teal
                              : (provenance == 'pulsepath_gps_recorded' ||
                                      provenance == 'manual'
                                  ? PulsePathColors.cyan
                                  : (provenance == 'step_estimated'
                                      ? Colors.orangeAccent
                                      : PulsePathColors.violet)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    unit!,
                    style: const TextStyle(
                      color: PulsePathColors.textSecondary,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            goal,
            style: const TextStyle(
              color: PulsePathColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (goalDetail != null) ...[
            const SizedBox(height: 2),
            Text(goalDetail!, style: TextStyle(color: accent, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
