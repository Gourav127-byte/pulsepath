import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../models/activity_history_entry.dart';
import '../models/activity_insights.dart';
import '../providers/activity_history_provider.dart';

class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  int _days = 7;
  HistoryMetric _metric = HistoryMetric.steps;
  ActivityHistoryEntry? _selected;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(activityHistoryProvider(_days));
    final insights = ref.watch(activityInsightsProvider(_days));
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Text('Journey', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          const Text(
            'Your recorded activity over time.',
            style: TextStyle(color: PulsePathColors.textSecondary),
          ),
          const SizedBox(height: 22),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 Days')),
              ButtonSegment(value: 30, label: Text('30 Days')),
            ],
            selected: {_days},
            onSelectionChanged: (value) => setState(() {
              _days = value.single;
              _selected = null;
            }),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in HistoryMetric.values)
                ChoiceChip(
                  key: Key('history_metric_${metric.name}'),
                  label: Text(metric.label),
                  selected: _metric == metric,
                  onSelected: (_) => setState(() {
                    _metric = metric;
                    _selected = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          history.when(
            loading: () => const _HistoryFrame(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => _HistoryFrame(
              child: _Message(
                text: 'Could not load activity history.',
                action: TextButton(
                  onPressed: () =>
                      ref.invalidate(activityHistoryProvider(_days)),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (entries) => entries.isEmpty
                ? const _HistoryFrame(
                    child: _Message(text: 'No activity recorded yet.'),
                  )
                : _HistoryFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selected == null
                              ? 'Tap a recorded day for details'
                              : _selectionLabel(_selected!),
                          key: const Key('history_selection'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 220,
                          child: _HistoryChart(
                            entries: entries,
                            days: _days,
                            metric: _metric,
                            onSelected: (entry) =>
                                setState(() => _selected = entry),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _HistoryStatusSummary(entries: entries, days: _days),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          Text(
            'Progress insights',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          insights.when(
            loading: () => const _InsightCard(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => _InsightCard(
              child: _Message(
                text: 'Insights unavailable.',
                action: TextButton(
                  onPressed: () =>
                      ref.invalidate(activityInsightsProvider(_days)),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (value) => _InsightsContent(insights: value, metric: _metric),
          ),
          if (_days == 7) ...[
            const SizedBox(height: 22),
            Text(
              'Personal insights',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            insights.when(
              loading: () => const _InsightCard(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (value) => _PersonalInsightsCard(insights: value),
            ),
          ],
        ],
      ),
    );
  }

  String _selectionLabel(ActivityHistoryEntry entry) {
    final value = _metric.valueOf(entry);
    final formatted = _metric == HistoryMetric.distance
        ? value.toStringAsFixed(2)
        : value.round().toString();
    final certainty = entry.isConfirmedRecorded ? '' : ' · legacy record';
    return '${entry.date.day}/${entry.date.month}/${entry.date.year} · '
        '$formatted ${_metric.unit}$certainty';
  }
}

class _HistoryStatusSummary extends StatelessWidget {
  const _HistoryStatusSummary({required this.entries, required this.days});

  final List<ActivityHistoryEntry> entries;
  final int days;

  @override
  Widget build(BuildContext context) {
    final confirmed = entries
        .where((entry) => entry.isConfirmedRecorded)
        .length;
    final legacy = entries.length - confirmed;
    final parts = <String>['$confirmed confirmed of $days days'];
    if (legacy > 0) {
      parts.add('$legacy legacy ${legacy == 1 ? 'record' : 'records'}');
    }
    return Text(
      parts.join(' · '),
      key: const Key('history_status_summary'),
      style: const TextStyle(
        color: PulsePathColors.textSecondary,
        fontSize: 12,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: child,
    );
  }
}

class _InsightsContent extends StatelessWidget {
  const _InsightsContent({required this.insights, required this.metric});

  final ActivityInsights insights;
  final HistoryMetric metric;

  @override
  Widget build(BuildContext context) {
    if (insights.currentRecordedDays == 0) {
      final message = insights.currentLegacyDays > 0
          ? 'No confirmed recorded days for insights. '
                'Legacy records remain visible in the graph.'
          : 'Not enough data yet.';
      return _InsightCard(child: _Message(text: message));
    }

    final messages = <String>[_rangeSummary()];
    final comparison = _comparisonMessage();
    if (comparison != null) {
      messages.add(comparison);
    } else if (insights.hasComparablePeriods) {
      messages.add('No valid comparison because the previous value is zero.');
    }
    final strongest = switch (metric) {
      HistoryMetric.steps => insights.strongestStepsDay,
      HistoryMetric.dailyScore => insights.strongestScoreDay,
      _ => null,
    };
    if (strongest case final day?) {
      final value = metric == HistoryMetric.steps
          ? '${day.steps.round()} steps'
          : 'Score ${day.dailyScore.round()}';
      messages.add(
        'Strongest confirmed day: ${day.date.day}/${day.date.month} · '
        '$value.',
      );
    }
    if (!insights.hasComparablePeriods) {
      messages.add('Not enough data yet for period comparisons.');
    }

    return _InsightCard(
      child: Column(
        key: const Key('progress_insights'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final message in messages) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    size: 16,
                    color: PulsePathColors.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Comparisons use confirmed recorded days only. '
            'Legacy records remain visible in the graph.',
            style: TextStyle(
              color: PulsePathColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _rangeSummary() {
    final count = insights.currentRecordedDays;
    final dayLabel = count == 1 ? 'day' : 'days';
    return switch (metric) {
      HistoryMetric.steps =>
        'Average ${insights.averageSteps?.round() ?? 0} steps across '
            '$count confirmed $dayLabel.',
      HistoryMetric.distance =>
        '${insights.totalDistance.toStringAsFixed(2)} km across '
            '$count confirmed $dayLabel.',
      HistoryMetric.activeCalories =>
        '${insights.totalActiveCalories.round()} active kcal across '
            '$count confirmed $dayLabel.',
      HistoryMetric.dailyScore =>
        'Average Daily Score ${insights.averageScore?.toStringAsFixed(1) ?? '—'} '
            'across $count confirmed $dayLabel.',
    };
  }

  String? _comparisonMessage() {
    return switch (metric) {
      HistoryMetric.steps => _percentMessage(
        insights.stepsChangePercent,
        'Average steps',
      ),
      HistoryMetric.distance => _percentMessage(
        insights.distanceChangePercent,
        'Total distance',
      ),
      HistoryMetric.activeCalories => _percentMessage(
        insights.activeCaloriesChangePercent,
        'Total active calories',
      ),
      HistoryMetric.dailyScore => _scoreMessage(insights.averageScoreChange),
    };
  }

  String? _percentMessage(double? change, String label) {
    if (change == null) return null;
    final direction = change >= 0 ? 'up' : 'down';
    return '$label $direction ${change.abs().toStringAsFixed(1)}% versus '
        'the previous ${insights.days} days.';
  }

  String? _scoreMessage(double? change) {
    if (change == null) return null;
    final direction = change >= 0 ? 'up' : 'down';
    return 'Average Daily Score $direction '
        '${change.abs().toStringAsFixed(1)} points versus the previous '
        '${insights.days} days.';
  }
}

class _PersonalInsightsCard extends StatelessWidget {
  const _PersonalInsightsCard({required this.insights});

  final ActivityInsights insights;

  @override
  Widget build(BuildContext context) {
    final trend = insights.trend;
    final consistency = insights.consistencyDays;

    final (IconData icon, String label) = switch (trend) {
      'improving' => (Icons.trending_up_rounded, 'Improving'),
      'declining' => (Icons.trending_down_rounded, 'Declining'),
      'stable' => (Icons.trending_flat_rounded, 'Stable'),
      _ => (Icons.hourglass_empty_rounded, 'Not enough data yet'),
    };

    final consistencyMessage =
        'Activity recorded on $consistency of the last 7 days.';

    return _InsightCard(
      child: Column(
        key: const Key('personal_insights'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: PulsePathColors.cyan),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: PulsePathColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(consistencyMessage)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Based on confirmed recorded days only.',
            style: TextStyle(
              color: PulsePathColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFrame extends StatelessWidget {
  const _HistoryFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.heroCardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: child,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({
    required this.entries,
    required this.days,
    required this.metric,
    required this.onSelected,
  });

  final List<ActivityHistoryEntry> entries;
  final int days;
  final HistoryMetric metric;
  final ValueChanged<ActivityHistoryEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        key: const Key('history_chart'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final slot = constraints.maxWidth / days;
          final index = (details.localPosition.dx / slot).floor().clamp(
            0,
            days - 1,
          );
          final selectedDate = start.add(Duration(days: index));
          for (final entry in entries) {
            if (DateUtils.isSameDay(entry.date, selectedDate)) {
              onSelected(entry);
              return;
            }
          }
        },
        child: CustomPaint(
          painter: _HistoryChartPainter(
            entries: entries,
            start: start,
            days: days,
            metric: metric,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  const _HistoryChartPainter({
    required this.entries,
    required this.start,
    required this.days,
    required this.metric,
  });

  final List<ActivityHistoryEntry> entries;
  final DateTime start;
  final int days;
  final HistoryMetric metric;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = PulsePathColors.divider;
    for (var row = 0; row <= 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maxValue = math.max(
      1.0,
      entries.map(metric.valueOf).fold<double>(0, math.max),
    );
    final confirmedPointPaint = Paint()..color = PulsePathColors.cyan;
    final legacyPointPaint = Paint()
      ..color = PulsePathColors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final linePaint = Paint()
      ..color = PulsePathColors.violet
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    Offset? previous;
    int? previousIndex;
    for (final entry in entries) {
      final index = DateUtils.dateOnly(entry.date).difference(start).inDays;
      if (index < 0 || index >= days) continue;
      final x = (index + 0.5) * size.width / days;
      final y =
          size.height -
          5 -
          (metric.valueOf(entry) / maxValue * (size.height - 10));
      final point = Offset(x, y);
      if (previous != null &&
          previousIndex != null &&
          index == previousIndex + 1) {
        canvas.drawLine(previous, point, linePaint);
      }
      canvas.drawCircle(
        point,
        entry.isConfirmedRecorded ? 4 : 4.5,
        entry.isConfirmedRecorded ? confirmedPointPaint : legacyPointPaint,
      );
      previous = point;
      previousIndex = index;
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) =>
      oldDelegate.entries != entries ||
      oldDelegate.days != days ||
      oldDelegate.metric != metric ||
      oldDelegate.start != start;
}
