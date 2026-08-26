class ActivityHistoryEntry {
  const ActivityHistoryEntry({
    required this.date,
    this.steps,
    this.activeMinutes,
    this.distance,
    this.activeCalories,
    this.dailyScore,
    required this.scoreVersion,
    required this.source,
    this.recordingStatus = HistoryRecordingStatus.legacyUnknown,
  });

  factory ActivityHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ActivityHistoryEntry(
      date: DateTime.parse(json['date'] as String),
      steps: json['steps'] != null ? (json['steps'] as num).toDouble() : null,
      activeMinutes: json['active_minutes'] != null
          ? (json['active_minutes'] as num).toDouble()
          : null,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      activeCalories: json['calories'] != null
          ? (json['calories'] as num).toDouble()
          : null,
      dailyScore: json['daily_score'] != null
          ? (json['daily_score'] as num).toDouble()
          : null,
      scoreVersion: json['score_version'] as String,
      source: json['source'] as String,
      recordingStatus: HistoryRecordingStatus.fromJson(
        json['recording_status'] as String? ?? 'legacy_unknown',
      ),
    );
  }

  final DateTime date;
  final double? steps;
  final double? activeMinutes;
  final double? distance;
  final double? activeCalories;
  final double? dailyScore;
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
    HistoryMetric.steps => entry.steps ?? 0.0,
    HistoryMetric.distance => entry.distance ?? 0.0,
    HistoryMetric.activeCalories => entry.activeCalories ?? 0.0,
    HistoryMetric.dailyScore => entry.dailyScore ?? 0.0,
  };
}
