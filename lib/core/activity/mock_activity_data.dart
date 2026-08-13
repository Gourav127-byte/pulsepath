import 'activity_metric.dart';

abstract final class MockActivityData {
  static const steps = 7842.0;
  static const distance = 5.6;
  static const activeMinutes = 46.0;
  static const calories = 324.0;

  static double currentValueFor(ActivityMetricType type) {
    return switch (type) {
      ActivityMetricType.steps => steps,
      ActivityMetricType.distance => distance,
      ActivityMetricType.activeMinutes => activeMinutes,
      ActivityMetricType.calories => calories,
    };
  }

  static String displayValueFor(ActivityMetricType type) {
    return switch (type) {
      ActivityMetricType.steps => '7,842',
      ActivityMetricType.distance => '5.6',
      ActivityMetricType.activeMinutes => '46',
      ActivityMetricType.calories => '324',
    };
  }
}
