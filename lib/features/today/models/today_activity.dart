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
    this.recordingStatus = ActivityRecordingStatus.legacyUnknown,
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
      recordingStatus: ActivityRecordingStatus.fromJson(
        json['recording_status'] as String? ?? 'legacy_unknown',
      ),
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
  final ActivityRecordingStatus recordingStatus;

  bool get isRecorded => recordingStatus != ActivityRecordingStatus.unrecorded;
}

enum ActivityRecordingStatus {
  unrecorded,
  recorded,
  legacyUnknown;

  static ActivityRecordingStatus fromJson(String value) {
    return switch (value) {
      'unrecorded' => unrecorded,
      'recorded' => recorded,
      _ => legacyUnknown,
    };
  }
}
