class DailyScoreComponent {
  const DailyScoreComponent({
    required this.metric,
    required this.value,
    required this.target,
    required this.progress,
    required this.weight,
    required this.points,
  });

  factory DailyScoreComponent.fromJson(Map<String, dynamic> json) {
    return DailyScoreComponent(
      metric: json['metric'] as String,
      value: (json['value'] as num).toDouble(),
      target: (json['target'] as num?)?.toDouble(),
      progress: (json['progress'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      points: (json['points'] as num).toDouble(),
    );
  }

  final String metric;
  final double value;
  final double? target;
  final double progress;
  final double weight;
  final double points;
}

class DailyScoreExplanation {
  const DailyScoreExplanation({
    required this.score,
    required this.scoreVersion,
    required this.available,
    required this.message,
    required this.components,
  });

  factory DailyScoreExplanation.fromJson(Map<String, dynamic> json) {
    return DailyScoreExplanation(
      score: (json['score'] as num).toDouble(),
      scoreVersion: json['score_version'] as String,
      available: json['available'] as bool,
      message: json['message'] as String?,
      components: (json['components'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(DailyScoreComponent.fromJson)
          .toList(),
    );
  }

  final double score;
  final String scoreVersion;
  final bool available;
  final String? message;
  final List<DailyScoreComponent> components;
}
