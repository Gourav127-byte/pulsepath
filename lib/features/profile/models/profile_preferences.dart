class ProfilePreferences {
  const ProfilePreferences({
    required this.reduceMotion,
    required this.hapticFeedback,
    required this.useMetricUnits,
  });

  const ProfilePreferences.defaults()
    : reduceMotion = false,
      hapticFeedback = true,
      useMetricUnits = true;

  final bool reduceMotion;
  final bool hapticFeedback;
  final bool useMetricUnits;

  ProfilePreferences copyWith({
    bool? reduceMotion,
    bool? hapticFeedback,
    bool? useMetricUnits,
  }) {
    return ProfilePreferences(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      useMetricUnits: useMetricUnits ?? this.useMetricUnits,
    );
  }
}
