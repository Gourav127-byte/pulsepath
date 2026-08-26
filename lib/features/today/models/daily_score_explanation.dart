class DailyScoreComponent {
  const DailyScoreComponent({
    required this.metric,
    this.value,
    this.target,
    this.progress,
    required this.weight,
    this.points,
    this.status = 'recorded',
  });

  factory DailyScoreComponent.fromJson(Map<String, dynamic> json) {
    return DailyScoreComponent(
      metric: json['metric'] as String,
      value: json['value'] != null ? (json['value'] as num).toDouble() : null,
      target: (json['target'] as num?)?.toDouble(),
      progress: json['progress'] != null ? (json['progress'] as num).toDouble() : null,
      weight: (json['weight'] as num).toDouble(),
      points: json['points'] != null ? (json['points'] as num).toDouble() : null,
      status: json['status'] as String? ?? 'recorded',
    );
  }

  final String metric;
  final double? value;
  final double? target;
  final double? progress;
  final double weight;
  final double? points;
  final String status;
}

class DailyScoreExplanation {
  const DailyScoreExplanation({
    this.score,
    required this.scoreVersion,
    required this.available,
    this.message,
    required this.components,
  });

  factory DailyScoreExplanation.fromJson(Map<String, dynamic> json) {
    return DailyScoreExplanation(
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      scoreVersion: json['score_version'] as String,
      available: json['available'] as bool,
      message: json['message'] as String?,
      components: (json['components'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(DailyScoreComponent.fromJson)
          .toList(),
    );
  }

  final double? score;
  final String scoreVersion;
  final bool available;
  final String? message;
  final List<DailyScoreComponent> components;
}
