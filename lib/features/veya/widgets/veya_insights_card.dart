import 'package:flutter/material.dart';
import '../models/veya_foundation.dart';

class VeyaInsightsCard extends StatelessWidget {
  final VeyaStructuredResponse response;
  final VoidCallback? onAskVeya;

  const VeyaInsightsCard({super.key, required this.response, this.onAskVeya});

  @override
  Widget build(BuildContext context) {
    final isUnavailable = response.status == 'provider_unavailable';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF090E1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF1E2846).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4627E8).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF8B59FF),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VEYA INSIGHTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
              ),
              Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFF26D0FF),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isUnavailable)
            const _UnavailableInsight()
          else ...[
            Text(
              response.summary,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            if (response.observations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'GROUNDED OBSERVATIONS',
                style: TextStyle(
                  color: Color(0xFF8E9BBD),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              ...response.observations.map(_buildObservationTile),
            ],
            if (response.limitations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF050812),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF141C33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: response.limitations
                      .map(
                        (lim) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: Color(0xFF8191B9),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lim,
                                  style: const TextStyle(
                                    color: Color(0xFF8191B9),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF050812),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF141C33)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF8E9BBD),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Private by default',
                    style: TextStyle(
                      color: Color(0xFF8E9BBD),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('•', style: TextStyle(color: Color(0xFF26324D))),
                  ),
                  const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF8E9BBD),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Evidence stays on your side',
                    style: TextStyle(
                      color: Color(0xFF8E9BBD),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationTile(VeyaObservation obs) {
    Color confColor;
    switch (obs.confidence.toLowerCase()) {
      case 'high':
        confColor = const Color(0xFF34EAB6);
        break;
      case 'medium':
        confColor = const Color(0xFFFFBF2C);
        break;
      case 'low':
      default:
        confColor = const Color(0xFFFF5263);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF050812),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF141C33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF141C33),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  obs.category.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: confColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${obs.confidence.toUpperCase()} CONFIDENCE',
                  style: TextStyle(
                    color: confColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            obs.text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (obs.evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: obs.evidence.map((cit) {
                final dateText = cit.date != null ? ' (${cit.date})' : '';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26D0FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF26D0FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Fact: ${cit.fact}$dateText',
                    style: const TextStyle(
                      color: Color(0xFF26D0FF),
                      fontSize: 10,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailableInsight extends StatelessWidget {
  const _UnavailableInsight();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            !constraints.hasBoundedWidth || constraints.maxWidth < 360;
        final orb = const _InsightOrb();
        final copy = Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              "Insights aren't ready yet",
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Our intelligence engine is temporarily paused. Your verified PulsePath evidence stays safe and ready.',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: Color(0xFF8E9BBD),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            children: [orb, const SizedBox(height: 14), copy],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            orb,
            const SizedBox(width: 16),
            Expanded(child: copy),
          ],
        );
      },
    );
  }
}

class _InsightOrb extends StatelessWidget {
  const _InsightOrb();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF8344FF), Color(0xFF5519D4), Color(0xFF130838)],
                stops: [0, .6, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B26FF).withValues(alpha: .45),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(88, 88),
            painter: _OrbOrbitPainter(),
          ),
        ],
      ),
    );
  }
}

class _OrbOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF986BFF).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 84, height: 26),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
