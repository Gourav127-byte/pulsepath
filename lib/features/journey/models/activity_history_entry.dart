class ActivityHistoryEntry {
  const ActivityHistoryEntry({
    required this.date,
    required this.steps,
    required this.activeMinutes,
    required this.distance,
    required this.activeCalories,
    required this.dailyScore,
    required this.scoreVersion,
    required this.source,
    this.recordingStatus = HistoryRecordingStatus.legacyUnknown,
  });

  factory ActivityHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ActivityHistoryEntry(
      date: DateTime.parse(json['date'] as String),
      steps: (json['steps'] as num).toDouble(),
      activeMinutes: (json['active_minutes'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      activeCalories: (json['calories'] as num).toDouble(),
      dailyScore: (json['daily_score'] as num).toDouble(),
      scoreVersion: json['score_version'] as String,
      source: json['source'] as String,
      recordingStatus: HistoryRecordingStatus.fromJson(
        json['recording_status'] as String? ?? 'legacy_unknown',
      ),
    );
  }

  final DateTime date;
  final double steps;
  final double activeMinutes;
  final double distance;
  final double activeCalories;
  final double dailyScore;
  final String scoreVersion;
  final String source;
  final HistoryRecordingStatus recordingStatus;

  bool get isConfirmedRecorded =>
      recordingStatus == HistoryRecordingStatus.recorded;
}

enum HistoryRecordingStatus {
  recorded,
  legacyUnknown;

  factory HistoryRecordingStatus.fromJson(String value) => switch (value) {
    'recorded' => recorded,
    'legacy_unknown' => legacyUnknown,
    _ => throw FormatException('Unsupported history recording status: $value'),
  };
}

enum HistoryMetric { steps, distance, activeCalories, dailyScore }

extension HistoryMetricDetails on HistoryMetric {
  String get label => switch (this) {
    HistoryMetric.steps => 'Steps',
    HistoryMetric.distance => 'Distance',
    HistoryMetric.activeCalories => 'Active calories',
    HistoryMetric.dailyScore => 'Daily Score',
  };

  String get unit => switch (this) {
    HistoryMetric.steps => 'steps',
    HistoryMetric.distance => 'km',
    HistoryMetric.activeCalories => 'kcal',
    HistoryMetric.dailyScore => 'points',
  };

  double valueOf(ActivityHistoryEntry entry) => switch (this) {
    HistoryMetric.steps => entry.steps,
    HistoryMetric.distance => entry.distance,
    HistoryMetric.activeCalories => entry.activeCalories,
    HistoryMetric.dailyScore => entry.dailyScore,
  };
}
