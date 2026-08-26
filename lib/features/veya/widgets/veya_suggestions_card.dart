import 'package:flutter/material.dart';
import '../models/veya_foundation.dart';

class VeyaSuggestionsCard extends StatelessWidget {
  final List<VeyaObservation> observations;

  const VeyaSuggestionsCard({super.key, required this.observations});

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7F00FF).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFE100FF),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SMART SUGGESTIONS & HIGHLIGHTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...observations.map((obs) {
            IconData categoryIcon;
            switch (obs.category.toLowerCase()) {
              case 'consistency':
                categoryIcon = Icons.repeat_rounded;
                break;
              case 'trend':
                categoryIcon = Icons.trending_up_rounded;
                break;
              case 'goal_progress':
                categoryIcon = Icons.flag_rounded;
                break;
              case 'routine_recovery':
              default:
                categoryIcon = Icons.fitness_center_rounded;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(categoryIcon, color: const Color(0xFF00F2FE), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      obs.text,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
