import 'package:flutter/material.dart';
import '../models/veya_foundation.dart';

class VeyaIntegrityCard extends StatelessWidget {
  final VeyaIntegrityLens integrity;

  const VeyaIntegrityCard({
    super.key,
    required this.integrity,
  });

  Color _levelColor() {
    switch (integrity.level.toLowerCase()) {
      case 'solid':
        return const Color(0xFF00E676);
      case 'partial':
        return const Color(0xFFFFB300);
      case 'sparse':
      default:
        return const Color(0xFFFF5252);
    }
  }

  IconData _levelIcon() {
    switch (integrity.level.toLowerCase()) {
      case 'solid':
        return Icons.verified_user_rounded;
      case 'partial':
        return Icons.gpp_maybe_rounded;
      case 'sparse':
      default:
        return Icons.gpp_bad_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor();
    final coveragePercent = (integrity.confirmedCoverage * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16132D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: levelColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_levelIcon(), color: levelColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'INTEGRITY LENS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: levelColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  integrity.level.toUpperCase(),
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: integrity.confirmedCoverage,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$coveragePercent% Coverage',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statTile('Confirmed', '${integrity.confirmedDays}d', const Color(0xFF00E676)),
              _statTile('Legacy', '${integrity.legacyDays}d', const Color(0xFFFFB300)),
              _statTile('Missing', '${integrity.missingDays}d', const Color(0xFFFF5252)),
            ],
          ),
          if (integrity.rationale.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            Text(
              integrity.rationale,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
