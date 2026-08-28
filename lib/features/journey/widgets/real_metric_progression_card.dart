import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../models/activity_history_entry.dart';

enum RealProgressionMetric {
  distance('Distance', 'km', PulsePathColors.cyan),
  activeMinutes('Active Time', 'mins', PulsePathColors.blue),
  activeCalories('Calories', 'kcal', Colors.orangeAccent);

  const RealProgressionMetric(this.label, this.unit, this.color);
  final String label;
  final String unit;
  final Color color;

  double? valueOf(ActivityHistoryEntry entry) => switch (this) {
        distance => entry.distance,
        activeMinutes => entry.activeMinutes,
        activeCalories => entry.activeCalories,
      };
}

class RealMetricProgressionCard extends StatefulWidget {
  const RealMetricProgressionCard({
    super.key,
    required this.entries,
    required this.days,
  });

  final List<ActivityHistoryEntry> entries;
  final int days;

  @override
  State<RealMetricProgressionCard> createState() => _RealMetricProgressionCardState();
}

class _RealMetricProgressionCardState extends State<RealMetricProgressionCard> {
  RealProgressionMetric _selectedMetric = RealProgressionMetric.distance;

  @override
  Widget build(BuildContext context) {
    final recordedEntries = widget.entries.take(widget.days).toList();
    final nonNullValues = recordedEntries
        .map(_selectedMetric.valueOf)
        .whereType<double>()
        .toList();

    final maxValue = nonNullValues.isEmpty
        ? 1.0
        : math.max(nonNullValues.reduce(math.max), 1.0);

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
              Text(
                'Real Metric Progression',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Text(
                'Missing != Zero',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PulsePathColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'REAL means recorded evidence, not mathematically realistic estimates.',
            style: TextStyle(
              fontSize: 11,
              color: PulsePathColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          // Metric Selector Tabs
          SegmentedButton<RealProgressionMetric>(
            segments: [
              for (final metric in RealProgressionMetric.values)
                ButtonSegment(
                  value: metric,
                  label: Text(metric.label, style: const TextStyle(fontSize: 12)),
                ),
            ],
            selected: {_selectedMetric},
            onSelectionChanged: (selection) => setState(() {
              _selectedMetric = selection.single;
            }),
          ),
          const SizedBox(height: 18),
          // Interactive Bar Chart
          SizedBox(
            height: 160,
            child: recordedEntries.isEmpty
                ? const Center(
                    child: Text(
                      'No recorded activity data.',
                      style: TextStyle(color: PulsePathColors.textSecondary),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in recordedEntries.reversed)
                        Expanded(
                          child: _BarColumn(
                            entry: entry,
                            metric: _selectedMetric,
                            maxValue: maxValue,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing last ${widget.days} days',
                style: const TextStyle(
                  fontSize: 11,
                  color: PulsePathColors.textSecondary,
                ),
              ),
              Text(
                'Recorded days: ${nonNullValues.length}/${recordedEntries.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PulsePathColors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.entry,
    required this.metric,
    required this.maxValue,
  });

  final ActivityHistoryEntry entry;
  final RealProgressionMetric metric;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final value = metric.valueOf(entry);
    final hasValue = value != null;
    final heightFactor = hasValue ? (value / maxValue).clamp(0.05, 1.0) : 0.0;
    final formattedValue = hasValue
        ? (metric == RealProgressionMetric.distance
            ? value.toStringAsFixed(1)
            : value.round().toString())
        : '--';

    return Tooltip(
      message: '${entry.date.day}/${entry.date.month}: '
          '${hasValue ? "$formattedValue ${metric.unit}" : "Not recorded"}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            formattedValue,
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: hasValue ? metric.color : PulsePathColors.textSecondary,
              fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              alignment: Alignment.bottomCenter,
              child: FractionalTranslation(
                translation: Offset.zero,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 14,
                  height: 120 * heightFactor,
                  decoration: BoxDecoration(
                    color: hasValue
                        ? metric.color.withValues(alpha: 0.85)
                        : PulsePathColors.divider.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${entry.date.day}/${entry.date.month}',
            style: const TextStyle(
              fontSize: 9,
              color: PulsePathColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
