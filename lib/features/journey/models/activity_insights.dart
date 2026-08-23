class StrongestActivityDay {
  const StrongestActivityDay({
    required this.date,
    required this.dailyScore,
    required this.steps,
  });

  factory StrongestActivityDay.fromJson(Map<String, dynamic> json) {
    return StrongestActivityDay(
      date: DateTime.parse(json['date'] as String),
      dailyScore: (json['daily_score'] as num).toDouble(),
      steps: (json['steps'] as num).toDouble(),
    );
  }

  final DateTime date;
  final double dailyScore;
  final double steps;
}

class ActivityInsights {
  const ActivityInsights({
    required this.days,
    required this.currentRecordedDays,
    required this.previousRecordedDays,
    this.currentLegacyDays = 0,
    this.previousLegacyDays = 0,
    this.totalSteps = 0,
    this.averageSteps,
    this.totalDistance = 0,
    this.totalActiveCalories = 0,
    this.averageScore,
    required this.stepsChangePercent,
    this.distanceChangePercent,
    this.activeCaloriesChangePercent,
    required this.averageScoreChange,
    this.trend = 'insufficient_data',
    this.consistencyDays = 0,
    this.strongestStepsDay,
    StrongestActivityDay? strongestScoreDay,
    StrongestActivityDay? strongestDay,
  }) : strongestScoreDay = strongestScoreDay ?? strongestDay;

  factory ActivityInsights.fromJson(Map<String, dynamic> json) {
    final strongestSteps = json['strongest_steps_day'];
    final strongestScore = json['strongest_score_day'];
    return ActivityInsights(
      days: json['days'] as int,
      currentRecordedDays: json['current_recorded_days'] as int,
      previousRecordedDays: json['previous_recorded_days'] as int,
      currentLegacyDays: json['current_legacy_days'] as int,
      previousLegacyDays: json['previous_legacy_days'] as int,
      totalSteps: (json['total_steps'] as num).toDouble(),
      averageSteps: (json['average_steps'] as num?)?.toDouble(),
      totalDistance: (json['total_distance'] as num).toDouble(),
      totalActiveCalories: (json['total_active_calories'] as num).toDouble(),
      averageScore: (json['average_score'] as num?)?.toDouble(),
      stepsChangePercent: (json['steps_change_percent'] as num?)?.toDouble(),
      distanceChangePercent: (json['distance_change_percent'] as num?)
          ?.toDouble(),
      activeCaloriesChangePercent:
          (json['active_calories_change_percent'] as num?)?.toDouble(),
      averageScoreChange: (json['average_score_change'] as num?)?.toDouble(),
      trend: json['trend'] as String? ?? 'insufficient_data',
      consistencyDays: json['consistency_days'] as int? ?? 0,
      strongestStepsDay: strongestSteps is Map<String, dynamic>
          ? StrongestActivityDay.fromJson(strongestSteps)
          : null,
      strongestScoreDay: strongestScore is Map<String, dynamic>
          ? StrongestActivityDay.fromJson(strongestScore)
          : null,
    );
  }

  final int days;
  final int currentRecordedDays;
  final int previousRecordedDays;
  final int currentLegacyDays;
  final int previousLegacyDays;
  final double totalSteps;
  final double? averageSteps;
  final double totalDistance;
  final double totalActiveCalories;
  final double? averageScore;
  final double? stepsChangePercent;
  final double? distanceChangePercent;
  final double? activeCaloriesChangePercent;
  final double? averageScoreChange;
  final String trend;
  final int consistencyDays;
  final StrongestActivityDay? strongestStepsDay;
  final StrongestActivityDay? strongestScoreDay;

  StrongestActivityDay? get strongestDay => strongestScoreDay;

  bool get hasComparablePeriods =>
      currentRecordedDays > 0 && previousRecordedDays > 0;
}
