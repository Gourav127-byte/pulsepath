import 'package:flutter/material.dart';
import '../models/veya_foundation.dart';
import 'veya_badge.dart';

class VeyaInsightsCard extends StatelessWidget {
  final VeyaStructuredResponse response;
  final VoidCallback? onAskVeya;

  const VeyaInsightsCard({
    super.key,
    required this.response,
    this.onAskVeya,
  });

  @override
  Widget build(BuildContext context) {
    final isUnavailable = response.status == 'provider_unavailable';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E173E),
            Color(0xFF130E2A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00F2FE).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  VeyaBadge(size: 26),
                  SizedBox(width: 10),
                  Text(
                    'VEYA INTELLIGENCE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (onAskVeya != null)
                TextButton.icon(
                  onPressed: onAskVeya,
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: Color(0xFF00F2FE)),
                  label: const Text(
                    'Ask VEYA',
                    style: TextStyle(
                      color: Color(0xFF00F2FE),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            response.summary,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (!isUnavailable && response.observations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Grounded Observations',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ...response.observations.map(_buildObservationTile),
          ],
          if (response.limitations.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
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
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: Colors.white38),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lim,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
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
      ),
    );
  }

  Widget _buildObservationTile(VeyaObservation obs) {
    Color confColor;
    switch (obs.confidence.toLowerCase()) {
      case 'high':
        confColor = const Color(0xFF00E676);
        break;
      case 'medium':
        confColor = const Color(0xFFFFB300);
        break;
      case 'low':
      default:
        confColor = const Color(0xFFFF5252);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  obs.category.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: confColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${obs.confidence.toUpperCase()} CONFIDENCE',
                  style: TextStyle(
                    color: confColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            obs.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          if (obs.evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: obs.evidence.map((cit) {
                final dateText = cit.date != null ? ' (${cit.date})' : '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Fact: ${cit.fact}$dateText',
                    style: const TextStyle(
                      color: Color(0xFF00F2FE),
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
