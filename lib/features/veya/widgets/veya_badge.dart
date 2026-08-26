import 'dart:math' as math;

import 'package:flutter/material.dart';

class VeyaBadge extends StatelessWidget {
  final double size;
  final bool showGlow;

  const VeyaBadge({super.key, this.size = 28.0, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _VeyaOrbitPainter(showGlow: showGlow),
        child: Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB8C8FF), Color(0xFFE3A7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.48,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VeyaOrbitPainter extends CustomPainter {
  final bool showGlow;
  const _VeyaOrbitPainter({required this.showGlow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.37;
    if (showGlow) {
      canvas.drawCircle(
        center,
        radius * 1.18,
        Paint()
          ..color = const Color(0xFF6337FF).withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.11),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF101D58), Color(0xFF28115C), Color(0xFF071128)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final orbitRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.88,
      height: size.height * 0.72,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.32);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
      orbitRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF13D8FF), Color(0xFF7542FF), Color(0xFFD15CFF)],
        ).createShader(orbitRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, size.width * 0.022),
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.26),
      math.max(1.2, size.width * 0.035),
      Paint()..color = const Color(0xFFC968FF),
    );
  }

  @override
  bool shouldRepaint(covariant _VeyaOrbitPainter oldDelegate) =>
      oldDelegate.showGlow != showGlow;
}
