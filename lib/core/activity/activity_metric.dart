import 'package:flutter/material.dart';

import '../theme/pulse_path_theme.dart';

enum ActivityMetricType { steps, distance, activeMinutes, calories }

extension ActivityMetricDetails on ActivityMetricType {
  String get label {
    return switch (this) {
      ActivityMetricType.steps => 'Steps',
      ActivityMetricType.distance => 'Distance',
      ActivityMetricType.activeMinutes => 'Active minutes',
      ActivityMetricType.calories => 'Calories',
    };
  }

  String get shortLabel {
    return this == ActivityMetricType.activeMinutes ? 'Active' : label;
  }

  String get unit {
    return switch (this) {
      ActivityMetricType.steps => 'steps',
      ActivityMetricType.distance => 'km',
      ActivityMetricType.activeMinutes => 'min',
      ActivityMetricType.calories => 'kcal',
    };
  }

  IconData get icon {
    return switch (this) {
      ActivityMetricType.steps => Icons.directions_walk_rounded,
      ActivityMetricType.distance => Icons.near_me_rounded,
      ActivityMetricType.activeMinutes => Icons.timer_outlined,
      ActivityMetricType.calories => Icons.local_fire_department_rounded,
    };
  }

  Color get accent {
    return switch (this) {
      ActivityMetricType.steps => PulsePathColors.violet,
      ActivityMetricType.distance => PulsePathColors.blue,
      ActivityMetricType.activeMinutes => PulsePathColors.cyan,
      ActivityMetricType.calories => PulsePathColors.violet,
    };
  }
}
