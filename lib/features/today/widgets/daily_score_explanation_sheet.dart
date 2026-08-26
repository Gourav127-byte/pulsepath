import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../models/daily_score_explanation.dart';
import '../providers/today_activity_provider.dart';

class DailyScoreExplanationSheet extends ConsumerWidget {
  const DailyScoreExplanationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explanationAsync = ref.watch(dailyScoreExplanationProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PulsePathColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Score Breakdown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: explanationAsync.when(
                  data: (explanation) => _ExplanationContent(
                    explanation: explanation,
                    controller: scrollController,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load score breakdown.'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(dailyScoreExplanationProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExplanationContent extends StatelessWidget {
  const _ExplanationContent({
    required this.explanation,
    required this.controller,
  });

  final DailyScoreExplanation explanation;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      children: [
        if (explanation.message != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PulsePathColors.surfaceBright,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              explanation.message!,
              style: const TextStyle(
                color: PulsePathColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final component in explanation.components)
          _ComponentRow(component: component),
        const Divider(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Score', style: Theme.of(context).textTheme.titleMedium),
            Text(
              explanation.score != null ? explanation.score!.round().toString() : '--',
              key: const Key('explained_daily_score'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: PulsePathColors.cyan),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final DailyScoreComponent component;

  @override
  Widget build(BuildContext context) {
    final label = switch (component.metric) {
      'steps' => 'Steps',
      'active_minutes' => 'Active minutes',
      'calories' => 'Active calories',
      _ => component.metric,
    };
    final weight = (component.weight * 100).round();
    final points = component.points != null ? component.points!.toStringAsFixed(1) : '--';
    final value = _formatValue(component.value);
    final target = component.target;
    final detail = component.status == 'unrecorded' || component.value == null
        ? 'Not recorded'
        : (target == null
              ? 'No goal set'
              : '$value / ${_formatValue(target)} ${_unit(component.metric)} · '
                '${((component.progress ?? 0) * 100).toStringAsFixed(1)}%');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · $weight% weight',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: PulsePathColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+$points pts',
            key: Key('score_component_${component.metric}'),
            style: const TextStyle(
              color: PulsePathColors.cyan,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double? value) {
    if (value == null) return '--';
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _unit(String metric) {
    return switch (metric) {
      'steps' => 'steps',
      'active_minutes' => 'min',
      'calories' => 'kcal',
      _ => '',
    };
  }
}
