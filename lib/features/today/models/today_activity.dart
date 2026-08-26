class TodayActivity {
  const TodayActivity({
    required this.date,
    this.steps,
    this.activeMinutes,
    this.distance,
    this.calories,
    this.dailyScore,
    required this.scoreVersion,
    required this.source,
    this.recordingStatus = ActivityRecordingStatus.legacyUnknown,
    this.stepsProvenance = 'system',
    this.distanceProvenance = 'system',
    this.caloriesProvenance = 'system',
    this.activeMinutesProvenance = 'system',
  });

  factory TodayActivity.fromJson(Map<String, dynamic> json) {
    return TodayActivity(
      date: DateTime.parse(json['date'] as String),
      steps: json['steps'] != null ? (json['steps'] as num).toDouble() : null,
      activeMinutes: json['active_minutes'] != null
          ? (json['active_minutes'] as num).toDouble()
          : null,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      calories: json['calories'] != null
          ? (json['calories'] as num).toDouble()
          : null,
      dailyScore: json['daily_score'] != null
          ? (json['daily_score'] as num).toDouble()
          : null,
      scoreVersion: json['score_version'] as String,
      source: json['source'] as String,
      recordingStatus: ActivityRecordingStatus.fromJson(
        json['recording_status'] as String? ?? 'legacy_unknown',
      ),
      stepsProvenance: json['steps_provenance'] as String? ?? 'system',
      distanceProvenance: json['distance_provenance'] as String? ?? 'system',
      caloriesProvenance: json['calories_provenance'] as String? ?? 'system',
      activeMinutesProvenance:
          json['active_minutes_provenance'] as String? ?? 'system',
    );
  }

  final DateTime date;
  final double? steps;
  final double? activeMinutes;
  final double? distance;
  final double? calories;
  final double? dailyScore;
  final String scoreVersion;
  final String source;
  final ActivityRecordingStatus recordingStatus;
  final String stepsProvenance;
  final String distanceProvenance;
  final String caloriesProvenance;
  final String activeMinutesProvenance;

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
