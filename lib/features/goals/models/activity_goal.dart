import '../../../core/activity/activity_metric.dart';

class ActivityGoal {
  const ActivityGoal({
    required this.type,
    required this.targetValue,
    required this.currentValue,
  });

  final ActivityMetricType type;
  final double targetValue;
  final double currentValue;

  String get displayLabel => type.label;
  String get unit => type.unit;
  bool get isCompleted => currentValue >= targetValue;

  double get progress {
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0, 1);
  }

  ActivityGoal copyWithTarget(double newTargetValue) {
    return ActivityGoal(
      type: type,
      targetValue: newTargetValue,
      currentValue: currentValue,
    );
  }
}
