class ActivityAchievement {
  const ActivityAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.progress,
    this.unlockDate,
  });

  factory ActivityAchievement.fromJson(Map<String, dynamic> json) {
    final rawDate = json['unlock_date'];
    return ActivityAchievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      unlocked: json['unlocked'] as bool? ?? false,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      unlockDate: rawDate == null ? null : DateTime.parse(rawDate as String),
    );
  }

  final String id;
  final String title;
  final String description;
  final bool unlocked;
  final double progress;
  final DateTime? unlockDate;
}

class ActivityEngagement {
  const ActivityEngagement({
    required this.currentStreak,
    required this.bestStreak,
    required this.todayPending,
    required this.achievements,
  });

  factory ActivityEngagement.fromJson(Map<String, dynamic> json) {
    final achievementsJson =
        json['achievements'] as List<dynamic>? ?? const <dynamic>[];
    return ActivityEngagement(
      currentStreak: json['current_streak'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
      todayPending: json['today_pending'] as bool? ?? false,
      achievements: achievementsJson
          .map(
            (entry) =>
                ActivityAchievement.fromJson(entry as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final int currentStreak;
  final int bestStreak;
  final bool todayPending;
  final List<ActivityAchievement> achievements;
}
