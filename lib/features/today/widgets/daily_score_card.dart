import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';

class DailyScoreCard extends StatelessWidget {
  const DailyScoreCard({
    required this.score,
    required this.streakDays,
    this.onExplain,
    super.key,
  }) : onRetry = null,
       isLoading = false;

  const DailyScoreCard.loading({super.key})
    : score = null,
      streakDays = null,
      onExplain = null,
      onRetry = null,
      isLoading = true;

  const DailyScoreCard.error({required this.onRetry, super.key})
    : score = null,
      streakDays = null,
      onExplain = null,
      isLoading = false;

  final int? score;
  final int? streakDays;
  final VoidCallback? onRetry;
  final VoidCallback? onExplain;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.heroCardRadius),
        border: Border.all(color: PulsePathColors.divider),
        boxShadow: [
          BoxShadow(
            color: PulsePathColors.violet.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isLoading) {
            return const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (onRetry != null) {
            return SizedBox(
              height: 150,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Could not load today's activity."),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final compact = constraints.maxWidth < 320;
          final scoreRing = _ScoreRing(
            score: score!,
            size: compact ? 130 : 150,
          );
          final summary = _ScoreSummary(
            streakDays: streakDays,
            onExplain: onExplain,
          );

          if (compact) {
            return Column(
              children: [scoreRing, const SizedBox(height: 20), summary],
            );
          }

          return Row(
            children: [
              scoreRing,
              const SizedBox(width: 22),
              Expanded(child: summary),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.streakDays, required this.onExplain});

  final int? streakDays;
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Strong day', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 7),
        const Text(
          'You are moving steadily toward your daily goals.',
          style: TextStyle(color: PulsePathColors.textSecondary, height: 1.45),
        ),
        if (onExplain != null) ...[
          const SizedBox(height: 6),
          TextButton(
            key: const Key('explain_daily_score_button'),
            onPressed: onExplain,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Why this score?'),
          ),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: PulsePathColors.surfaceBright,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                streakDays == null
                    ? Icons.history_toggle_off_rounded
                    : Icons.local_fire_department_rounded,
                size: 18,
                color: PulsePathColors.violet,
              ),
              const SizedBox(width: 7),
              Text(
                streakDays == null
                    ? 'Streak unavailable'
                    : '$streakDays day streak',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.size});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ScoreRingPainter(progress: score / 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$score', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 2),
            Text(
              'DAILY SCORE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: PulsePathColors.textSecondary,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final rect = Offset.zero & size;
    final ringRect = rect.deflate(strokeWidth / 2);
    final startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress;

    canvas.drawArc(
      ringRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = PulsePathColors.surfaceBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      ringRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..shader = const SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [
            PulsePathColors.violet,
            PulsePathColors.blue,
            PulsePathColors.cyan,
            PulsePathColors.violet,
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
