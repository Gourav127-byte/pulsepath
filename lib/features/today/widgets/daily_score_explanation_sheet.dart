import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../models/daily_score_explanation.dart';
import '../providers/today_activity_provider.dart';

class DailyScoreExplanationSheet extends ConsumerWidget {
  const DailyScoreExplanationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explanation = ref.watch(dailyScoreExplanationProvider);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PulsePathColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Why this score?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Calculated on the server from today’s activity and score rules.',
                style: TextStyle(color: PulsePathColors.textSecondary),
              ),
              const SizedBox(height: 20),
              explanation.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(dailyScoreExplanationProvider),
                    child: const Text('Could not load explanation · Retry'),
                  ),
                ),
                data: (value) => _ExplanationContent(explanation: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationContent extends StatelessWidget {
  const _ExplanationContent({required this.explanation});

  final DailyScoreExplanation explanation;

  @override
  Widget build(BuildContext context) {
    if (!explanation.available) {
      return Text(
        explanation.message ?? 'This score breakdown is unavailable.',
        key: const Key('score_explanation_unavailable'),
        style: const TextStyle(color: PulsePathColors.textSecondary),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final component in explanation.components)
          _ComponentRow(component: component),
        const Divider(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Score', style: Theme.of(context).textTheme.titleMedium),
            Text(
              explanation.score.round().toString(),
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
    final points = component.points.toStringAsFixed(1);
    final value = _formatValue(component.value);
    final target = component.target;
    final detail = target == null
        ? 'No goal set · 0.0% progress'
        : '$value / ${_formatValue(target)} ${_unit(component.metric)} · '
              '${(component.progress * 100).toStringAsFixed(1)}%';
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
                  style: Theme.of(context).textTheme.bodyMedium,
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

  String _formatValue(double value) {
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
