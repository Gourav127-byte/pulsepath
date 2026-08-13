class BackendProfile {
  const BackendProfile({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.darkTheme,
    required this.reduceMotion,
    required this.hapticFeedback,
    required this.useMetricUnits,
  });

  factory BackendProfile.fromJson(Map<String, dynamic> json) {
    return BackendProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      subtitle: json['subtitle'] as String,
      darkTheme: json['dark_theme'] as bool,
      reduceMotion: json['reduce_motion'] as bool,
      hapticFeedback: json['haptic_feedback'] as bool,
      useMetricUnits: json['use_metric_units'] as bool,
    );
  }

  final String id;
  final String displayName;
  final String subtitle;
  final bool darkTheme;
  final bool reduceMotion;
  final bool hapticFeedback;
  final bool useMetricUnits;
}
