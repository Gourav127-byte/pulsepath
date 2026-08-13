import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../services/startup_sound.dart';

class PulsePathStartupScreen extends StatefulWidget {
  const PulsePathStartupScreen({
    required this.destination,
    this.soundPlayer,
    this.firstFrameReady,
    this.duration = const Duration(milliseconds: 3400),
    super.key,
  });

  final Widget destination;
  final StartupSoundPlayer? soundPlayer;
  final Future<void>? firstFrameReady;
  final Duration duration;

  @override
  State<PulsePathStartupScreen> createState() => _PulsePathStartupScreenState();
}

class _PulsePathStartupScreenState extends State<PulsePathStartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final StartupSoundPlayer _soundPlayer;
  late final bool _ownsSoundPlayer;
  bool _started = false;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _complete = true);
        }
      });
    _ownsSoundPlayer = widget.soundPlayer == null;
    _soundPlayer = widget.soundPlayer ?? PulsePathStartupSound();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    unawaited(_startSequence(reduceMotion));
  }

  Future<void> _startSequence(bool reduceMotion) async {
    await (widget.firstFrameReady ??
        WidgetsBinding.instance.waitUntilFirstFrameRasterized);
    if (!mounted) return;
    if (reduceMotion) {
      _controller.duration = const Duration(milliseconds: 350);
    } else {
      unawaited(_soundPlayer.play());
    }
    await _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsSoundPlayer) unawaited(_soundPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.destination;

    return Scaffold(
      backgroundColor: const Color(0xFF02040B),
      body: AnimatedBuilder(
        animation: _controller,
        child: RepaintBoundary(child: widget.destination),
        builder: (context, destination) {
          final progress = _controller.value;
          final reveal = _interval(progress, 0.80, 1);

          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: reveal, child: destination),
              IgnorePointer(
                child: Opacity(
                  opacity: 1 - reveal,
                  child: _StartupVisual(progress: progress),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static double _interval(double value, double start, double end) {
    return ((value - start) / (end - start)).clamp(0, 1);
  }
}

class _StartupVisual extends StatelessWidget {
  const _StartupVisual({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height * 0.42);
    final opening = _segment(0.01, 0.38);
    final portal = _segment(0.31, 0.73);
    final finish = _segment(0.70, 0.93);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.72),
          radius: 1.25,
          colors: [Color(0x242A1B67), Color(0xFF02040B)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: opening * (1 - _segment(0.45, 0.63)),
              child: const _Aurora(),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: opening * 0.48,
              child: CustomPaint(
                painter: _RingsPainter(progress: 0.55 + opening * 0.75),
              ),
            ),
          ),
          Positioned(
            left: center.dx - 47,
            top: center.dy - 47,
            child: Opacity(
              opacity: opening * (1 - _segment(0.43, 0.60)),
              child: Transform.scale(
                scale: 0.55 + opening * 0.45,
                child: Image.asset(
                  'assets/branding/pulsepath_logo.png',
                  width: 94,
                  height: 94,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: center.dy + 76,
            child: Opacity(
              opacity: _segment(0.20, 0.36) * (1 - _segment(0.48, 0.61)),
              child: const Column(
                children: [
                  Text(
                    'PulsePath',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'MOVE  •  BUILD  •  REPEAT',
                    style: TextStyle(
                      color: PulsePathColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: center.dx - 74,
            top: center.dy - 109,
            child: Opacity(
              opacity: portal * (1 - _segment(0.73, 0.83)),
              child: Transform.scale(
                scale: 0.72 + portal * 0.28,
                child: Container(
                  width: 148,
                  height: 218,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(74),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PulsePathColors.violet,
                        PulsePathColors.blue,
                        PulsePathColors.cyan,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PulsePathColors.blue.withValues(alpha: 0.22),
                        blurRadius: 36,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF080B1B),
                      borderRadius: BorderRadius.circular(72),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: center.dx - 105,
            top: center.dy - 31,
            child: Opacity(
              opacity: _segment(0.38, 0.56) * (1 - _segment(0.73, 0.83)),
              child: CustomPaint(
                size: const Size(210, 62),
                painter: _PulsePainter(progress: _segment(0.38, 0.58)),
              ),
            ),
          ),
          _StatChip(
            left: 22,
            top: center.dy - 96,
            value: '7,842',
            label: 'STEPS',
            opacity: _segment(0.49, 0.62) * (1 - _segment(0.72, 0.82)),
          ),
          _StatChip(
            right: 22,
            top: center.dy - 6,
            value: '77',
            label: 'DAILY SCORE',
            opacity: _segment(0.54, 0.67) * (1 - _segment(0.72, 0.82)),
          ),
          _StatChip(
            left: 38,
            top: center.dy + 82,
            value: '46',
            label: 'ACTIVE MIN',
            opacity: _segment(0.59, 0.72) * (1 - _segment(0.72, 0.82)),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: finish * (1 - _segment(0.88, 1)),
              child: CustomPaint(painter: _WavePainter(progress: finish)),
            ),
          ),
          Positioned(
            left: center.dx - 5,
            top: center.dy - 5,
            child: Opacity(
              opacity: math.sin(finish * math.pi).clamp(0, 1),
              child: Transform.scale(
                scale: 0.4 + finish * 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: PulsePathColors.cyan.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _segment(double start, double end) {
    return ((progress - start) / (end - start)).clamp(0, 1);
  }
}

class _Aurora extends StatelessWidget {
  const _Aurora();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.18),
          radius: 0.72,
          colors: [
            PulsePathColors.violet.withValues(alpha: 0.24),
            PulsePathColors.blue.withValues(alpha: 0.11),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    this.left,
    this.right,
    required this.top,
    required this.value,
    required this.label,
    required this.opacity,
  });

  final double? left;
  final double? right;
  final double top;
  final String value;
  final String label;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xE6100F24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: PulsePathColors.textSecondary,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final ring in [0.0, 18.0, 36.0]) {
      final radius = (150 - ring * 2) / 2 * progress;
      paint.color = Color.lerp(
        PulsePathColors.violet,
        PulsePathColors.cyan,
        ring / 36,
      )!.withValues(alpha: 0.55);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress});

  final double progress;

  static final Path _staticPath = Path()
    ..moveTo(2, 31)
    ..lineTo(58, 31)
    ..lineTo(72, 10)
    ..lineTo(84, 52)
    ..lineTo(98, 22)
    ..lineTo(112, 36)
    ..lineTo(128, 31)
    ..lineTo(208, 31);

  static final PathMetric _metric = _staticPath.computeMetrics().first;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = _metric.extractPath(0, _metric.length * progress);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          PulsePathColors.violet,
          PulsePathColors.blue,
          PulsePathColors.cyan,
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(visible, paint);
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rise = size.height * (1 - progress) * 0.55;
    final y = size.height * 0.58 + rise;
    final path = Path()
      ..moveTo(0, y)
      ..cubicTo(
        size.width * 0.2,
        y - 55,
        size.width * 0.35,
        y + 28,
        size.width * 0.52,
        y - 18,
      )
      ..cubicTo(
        size.width * 0.7,
        y - 68,
        size.width * 0.82,
        y + 25,
        size.width,
        y - 34,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          PulsePathColors.violet,
          PulsePathColors.blue,
          PulsePathColors.cyan,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
