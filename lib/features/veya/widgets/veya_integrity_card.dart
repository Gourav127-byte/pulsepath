import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/veya_foundation.dart';

class VeyaIntegrityCard extends StatelessWidget {
  final VeyaIntegrityLens integrity;
  final int rangeDays;

  const VeyaIntegrityCard({
    super.key,
    required this.integrity,
    this.rangeDays = 7,
  });

  Color get _levelColor {
    switch (integrity.level.toLowerCase()) {
      case 'solid':
        return const Color(0xFF42E8A4);
      case 'partial':
        return const Color(0xFFFFBE32);
      default:
        return const Color(0xFFFF495B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (integrity.confirmedCoverage * 100).round();
    final rationaleText = integrity.rationale.isNotEmpty
        ? integrity.rationale
        : (integrity.confirmedDays < 2
            ? 'Fewer than two confirmed recorded days are available. VEYA needs more data to generate reliable insights.'
            : 'Confirmed records help VEYA distinguish reliable patterns from gaps in your activity history.');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF090E1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF1E2846).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4627E8).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(levelColor: _levelColor, level: integrity.level),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  !constraints.hasBoundedWidth || constraints.maxWidth < 360;
              final ring = _CoverageRing(
                value: integrity.confirmedCoverage,
                percent: percent,
                size: compact ? 100 : 110,
              );
              final textContent = Column(
                crossAxisAlignment:
                    compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(
                    rangeDays == 30
                        ? 'Your month at a glance'
                        : 'Your week at a glance',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only ${integrity.confirmedDays} confirmed day${integrity.confirmedDays == 1 ? '' : 's'} so far.\nMore consistent data helps VEYA deliver deeper, more accurate insights.',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(
                      color: Color(0xFF9BA6C7),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  children: [
                    ring,
                    const SizedBox(height: 14),
                    textContent,
                  ],
                );
              }

              return Row(
                children: [
                  ring,
                  const SizedBox(width: 16),
                  Expanded(child: textContent),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF050812),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF141C33)),
            ),
            child: Row(
              children: [
                _EvidenceStat(
                  value: integrity.confirmedDays,
                  label: 'CONFIRMED',
                  suffix: integrity.confirmedDays == 1 ? 'day' : 'days',
                  color: const Color(0xFF34EAB6),
                  icon: Icons.check_circle_outline_rounded,
                ),
                const _StatDivider(),
                _EvidenceStat(
                  value: integrity.legacyDays,
                  label: 'LEGACY',
                  suffix: integrity.legacyDays == 1 ? 'day' : 'days',
                  color: const Color(0xFFFFBF2C),
                  icon: Icons.access_time_rounded,
                ),
                const _StatDivider(),
                _EvidenceStat(
                  value: integrity.missingDays,
                  label: 'MISSING',
                  suffix: integrity.missingDays == 1 ? 'day' : 'days',
                  color: const Color(0xFFFF5263),
                  icon: Icons.blur_circular_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF060B18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF141C33)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF8191B9),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rationaleText,
                    style: const TextStyle(
                      color: Color(0xFF9BA6C7),
                      fontSize: 12,
                      height: 1.4,
                    ),
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

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFF1B2644),
    );
  }
}

class _Header extends StatelessWidget {
  final Color levelColor;
  final String level;
  const _Header({required this.levelColor, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.shield_outlined,
          color: Color(0xFF7887FF),
          size: 22,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INTEGRITY LENS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Snapshot of your activity evidence',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFF8E9BBD), fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: levelColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: levelColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            level.toUpperCase(),
            style: TextStyle(
              color: levelColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverageRing extends StatelessWidget {
  final double value;
  final int percent;
  final double size;

  const _CoverageRing({
    required this.value,
    required this.percent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _RingPainter(value)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'COVERAGE',
                style: TextStyle(
                  color: Color(0xFF8E9BBD),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  const _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(8);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0xFF161F38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0,
    );

    if (value > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 10.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _EvidenceStat extends StatelessWidget {
  final int value;
  final String label;
  final String suffix;
  final Color color;
  final IconData icon;
  const _EvidenceStat({
    required this.value,
    required this.label,
    required this.suffix,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
          Text(
            suffix,
            style: const TextStyle(color: Color(0xFF8E9BBD), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
