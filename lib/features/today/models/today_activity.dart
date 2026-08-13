class TodayActivity {
  const TodayActivity({
    required this.date,
    required this.steps,
    required this.activeMinutes,
    required this.distance,
    required this.calories,
    required this.dailyScore,
    required this.scoreVersion,
    required this.source,
  });

  factory TodayActivity.fromJson(Map<String, dynamic> json) {
    return TodayActivity(
      date: DateTime.parse(json['date'] as String),
      steps: (json['steps'] as num).toDouble(),
      activeMinutes: (json['active_minutes'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      dailyScore: (json['daily_score'] as num).toDouble(),
      scoreVersion: json['score_version'] as String,
      source: json['source'] as String,
    );
  }

  final DateTime date;
  final double steps;
  final double activeMinutes;
  final double distance;
  final double calories;
  final double dailyScore;
  final String scoreVersion;
  final String source;
}
