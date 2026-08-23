class ActivityStreak {
  const ActivityStreak({
    required this.currentStreak,
    required this.todayPending,
  });

  factory ActivityStreak.fromJson(Map<String, dynamic> json) {
    return ActivityStreak(
      currentStreak: json['current_streak'] as int,
      todayPending: json['today_pending'] as bool,
    );
  }

  final int currentStreak;
  final bool todayPending;
}
