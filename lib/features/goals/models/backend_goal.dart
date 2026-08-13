import '../../../core/activity/activity_metric.dart';

class BackendGoal {
  const BackendGoal({
    required this.id,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.progress,
    required this.isCompleted,
  });

  factory BackendGoal.fromJson(Map<String, dynamic> json) {
    return BackendGoal(
      id: json['id'] as String,
      type: _metricTypeFromApi(json['type'] as String),
      targetValue: (json['target_value'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      progress: (json['progress'] as num).toDouble(),
      isCompleted: json['is_completed'] as bool,
    );
  }

  final String id;
  final ActivityMetricType type;
  final double targetValue;
  final double currentValue;
  final double progress;
  final bool isCompleted;

  String get displayLabel => type.label;
  String get unit => type.unit;

  static ActivityMetricType _metricTypeFromApi(String value) {
    return switch (value) {
      'steps' => ActivityMetricType.steps,
      'distance' => ActivityMetricType.distance,
      'active_minutes' => ActivityMetricType.activeMinutes,
      'calories' => ActivityMetricType.calories,
      _ => throw FormatException('Unknown goal type: $value'),
    };
  }
}
