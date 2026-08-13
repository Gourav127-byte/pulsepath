import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// TEMPORARY DEMO CACHE — remove/replace during final offline-sync architecture.
class TemporaryDemoCache {
  const TemporaryDemoCache({this.userId});

  final String? userId;

  static const _todayKey = 'temporary_demo_today';
  static const _goalsKey = 'temporary_demo_goals';
  static const _profileKey = 'temporary_demo_profile';

  String _scoped(String key) => userId == null ? key : '$key:$userId';

  Future<void> saveToday(Map<String, dynamic> json) {
    return _save(_todayKey, json);
  }

  Future<Map<String, dynamic>?> loadToday() {
    return _loadMap(_todayKey);
  }

  Future<void> saveGoals(List<Map<String, dynamic>> json) {
    return _save(_goalsKey, json);
  }

  Future<List<Map<String, dynamic>>?> loadGoals() async {
    final decoded = await _load(_goalsKey);
    if (decoded is! List) return null;
    try {
      return decoded.cast<Map<String, dynamic>>();
    } on TypeError {
      return null;
    }
  }

  Future<void> saveProfile(Map<String, dynamic> json) {
    return _save(_profileKey, json);
  }

  Future<Map<String, dynamic>?> loadProfile() {
    return _loadMap(_profileKey);
  }

  Future<void> _save(String key, Object json) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_scoped(key), jsonEncode(json));
  }

  Future<Map<String, dynamic>?> _loadMap(String key) async {
    final decoded = await _load(key);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<Object?> _load(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_scoped(key));
    if (encoded == null) return null;
    try {
      return jsonDecode(encoded);
    } on FormatException {
      return null;
    }
  }
}
