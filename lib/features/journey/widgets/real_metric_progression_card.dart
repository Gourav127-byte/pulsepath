import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../models/activity_history_entry.dart';

enum RealProgressionMetric {
  steps('Steps', 'steps', PulsePathColors.violet),
  distance('Distance', 'km', PulsePathColors.cyan),
  activeCalories('Calories', 'kcal', Colors.orangeAccent);

  const RealProgressionMetric(this.label, this.unit, this.color);
  final String label;
  final String unit;
  final Color color;

  double? valueOf(ActivityHistoryEntry entry) => switch (this) {
        steps => entry.steps,
        distance => entry.distance,
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
  RealProgressionMetric _selectedMetric = RealProgressionMetric.steps;

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
              Flexible(
                child: Text(
                  'Real Metric Progression',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columnCount = recordedEntries.length;
                      final columnWidth = columnCount > 0
                          ? constraints.maxWidth / columnCount
                          : constraints.maxWidth;
                      final isCompact = columnWidth < 20;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final entry in recordedEntries.reversed)
                            Expanded(
                              child: _BarColumn(
                                entry: entry,
                                metric: _selectedMetric,
                                maxValue: maxValue,
                                columnWidth: columnWidth,
                                isCompact: isCompact,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Showing last ${widget.days} days',
                  style: const TextStyle(
                    fontSize: 11,
                    color: PulsePathColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Recorded days: ${nonNullValues.length}/${recordedEntries.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PulsePathColors.cyan,
                  ),
                  overflow: TextOverflow.ellipsis,
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
    required this.columnWidth,
    required this.isCompact,
  });

  final ActivityHistoryEntry entry;
  final RealProgressionMetric metric;
  final double maxValue;
  final double columnWidth;
  final bool isCompact;

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

    // Dynamic bar width: leave 2dp gap per side, minimum 2dp bar
    final barWidth = (columnWidth - 4).clamp(2.0, 14.0);

    return Tooltip(
      message: '${entry.date.day}/${entry.date.month}: '
          '${hasValue ? "$formattedValue ${metric.unit}" : "Not recorded"}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Hide value text in compact mode (30-day) to prevent overflow
          if (!isCompact)
            Text(
              formattedValue,
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: hasValue ? metric.color : PulsePathColors.textSecondary,
                fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.clip,
              maxLines: 1,
            ),
          if (!isCompact) const SizedBox(height: 4),
          Expanded(
            child: Container(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: barWidth,
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
          const SizedBox(height: 6),
          // Hide date text in compact mode to prevent overflow
          if (!isCompact)
            Text(
              '${entry.date.day}/${entry.date.month}',
              style: const TextStyle(
                fontSize: 9,
                color: PulsePathColors.textSecondary,
              ),
              overflow: TextOverflow.clip,
              maxLines: 1,
            ),
        ],
      ),
    );
  }
}
