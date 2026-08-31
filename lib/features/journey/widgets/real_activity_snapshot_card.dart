import 'package:flutter/material.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../models/activity_history_entry.dart';

class RealActivitySnapshotCard extends StatelessWidget {
  const RealActivitySnapshotCard({
    super.key,
    required this.entry,
  });

  final ActivityHistoryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final stepsStr = entry?.steps != null
        ? '${entry!.steps!.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} steps'
        : '-- / Not recorded';

    final distStr = entry?.distance != null
        ? '${entry!.distance!.toStringAsFixed(2)} km'
        : '-- / Not recorded';

    final timeStr = entry?.activeMinutes != null
        ? '${entry!.activeMinutes!.round()} mins'
        : '-- / Not recorded';

    final calStr = entry?.activeCalories != null
        ? '${entry!.activeCalories!.round()} kcal'
        : '-- / Not recorded';

    final sourceStr = entry?.source ?? 'system';
    final isRecorded = entry?.isConfirmedRecorded ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Flexible(
                child: Text(
                  'Real Activity Snapshot',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRecorded
                      ? PulsePathColors.cyan.withValues(alpha: 0.12)
                      : PulsePathColors.textSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRecorded
                        ? PulsePathColors.cyan.withValues(alpha: 0.3)
                        : PulsePathColors.divider,
                  ),
                ),
                child: Text(
                  isRecorded ? 'Recorded Evidence' : 'Legacy / Unconfirmed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isRecorded
                        ? PulsePathColors.cyan
                        : PulsePathColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Steps',
                  value: stepsStr,
                  icon: Icons.directions_walk,
                  color: PulsePathColors.violet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Distance',
                  value: distStr,
                  icon: Icons.place_outlined,
                  color: PulsePathColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Active Time',
                  value: timeStr,
                  icon: Icons.timer_outlined,
                  color: PulsePathColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Active Calories',
                  value: calStr,
                  icon: Icons.local_fire_department_outlined,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Source Provenance: $sourceStr · No mathematical estimation',
            style: const TextStyle(
              fontSize: 11,
              color: PulsePathColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PulsePathColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PulsePathColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
