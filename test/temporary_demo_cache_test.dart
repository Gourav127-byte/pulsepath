import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/cache/temporary_demo_cache.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/goals/data/goals_repository.dart';
import 'package:pulsepath/features/journey/data/activity_history_repository.dart';
import 'package:pulsepath/features/profile/data/profile_repository.dart';
import 'package:pulsepath/features/today/data/today_activity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const todayJson = <String, dynamic>{
    'date': '2026-08-10',
    'steps': 7842.0,
    'active_minutes': 46.0,
    'distance': 5.6,
    'calories': 324.0,
    'daily_score': 77.0,
    'score_version': 'v1',
    'source': 'manual',
    'recording_status': 'recorded',
  };
  const goalsJson = <Map<String, dynamic>>[
    {
      'id': 'goal-1',
      'type': 'steps',
      'target_value': 10000.0,
      'current_value': 7842.0,
      'progress': 0.7842,
      'is_completed': false,
    },
  ];
  const profileJson = <String, dynamic>{
    'id': 'profile-1',
    'display_name': 'Alex',
    'subtitle': 'Building better daily habits',
    'dark_theme': true,
    'reduce_motion': false,
    'haptic_feedback': true,
    'use_metric_units': true,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('successful fetches populate cache used by offline fallback', () async {
    final onlineClient = MockClient((request) async {
      return switch (request.url.path) {
        '/activity/today' => http.Response(jsonEncode(todayJson), 200),
        '/goals' => http.Response(jsonEncode(goalsJson), 200),
        '/profile' => http.Response(jsonEncode(profileJson), 200),
        '/activity/history' => http.Response(jsonEncode([todayJson]), 200),
        _ => http.Response('', 404),
      };
    });
    final offlineClient = MockClient((_) async => http.Response('', 503));
    const cache = TemporaryDemoCache();
    final onlineApi = ApiClient(
      baseUrl: 'http://example.test',
      client: onlineClient,
    );
    final offlineApi = ApiClient(
      baseUrl: 'http://example.test',
      client: offlineClient,
    );

    await TodayActivityRepository(onlineApi, cache).fetchTodayActivity();
    await GoalsRepository(onlineApi, cache).fetchGoals();
    await ProfileRepository(onlineApi, cache).fetchProfile();
    await ActivityHistoryRepository(onlineApi, cache).fetchHistory(days: 7);

    final cachedToday = await TodayActivityRepository(
      offlineApi,
      cache,
      () => DateTime(2026, 8, 10),
    ).fetchTodayActivity();
    final cachedGoals = await GoalsRepository(offlineApi, cache).fetchGoals();
    final cachedProfile = await ProfileRepository(
      offlineApi,
      cache,
    ).fetchProfile();
    final cachedHistory = await ActivityHistoryRepository(
      offlineApi,
      cache,
    ).fetchHistory(days: 7);

    expect(cachedToday.steps, 7842);
    expect(cachedGoals.single.progress, 0.7842);
    expect(cachedProfile.displayName, 'Alex');
    expect(cachedHistory.single.steps, 7842);
  });

  test(
    'scopes cache by userId to prevent data leakage between users',
    () async {
      const cacheA = TemporaryDemoCache(userId: 'user-a');
      const cacheB = TemporaryDemoCache(userId: 'user-b');

      await cacheA.saveToday({...todayJson, 'steps': 5000.0});
      await cacheB.saveToday({...todayJson, 'steps': 10000.0});
      await cacheA.saveHistory(7, [todayJson]);

      final loadedA = await cacheA.loadToday();
      final loadedB = await cacheB.loadToday();

      expect(loadedA?['steps'], 5000.0);
      expect(loadedB?['steps'], 10000.0);
      expect(await cacheB.loadHistory(7), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('temporary_demo_today:user-a'), isTrue);
      expect(prefs.containsKey('temporary_demo_today:user-b'), isTrue);
    },
  );

  test('clearAll removes only the signed-out user cache', () async {
    const cacheA = TemporaryDemoCache(userId: 'user-a');
    const cacheB = TemporaryDemoCache(userId: 'user-b');
    await cacheA.saveToday(todayJson);
    await cacheA.saveGoals(goalsJson);
    await cacheA.saveProfile(profileJson);
    await cacheA.saveHistory(7, [todayJson]);
    await cacheA.saveHistory(30, [todayJson]);
    await cacheB.saveToday({...todayJson, 'steps': 10000.0});

    await cacheA.clearAll();

    expect(await cacheA.loadToday(), isNull);
    expect(await cacheA.loadGoals(), isNull);
    expect(await cacheA.loadProfile(), isNull);
    expect(await cacheA.loadHistory(7), isNull);
    expect(await cacheA.loadHistory(30), isNull);
    expect((await cacheB.loadToday())?['steps'], 10000.0);
  });

  test('network failure without cached data remains an error', () async {
    final offlineClient = MockClient((_) async => http.Response('', 503));
    final repository = TodayActivityRepository(
      ApiClient(baseUrl: 'http://example.test', client: offlineClient),
      const TemporaryDemoCache(),
    );

    await expectLater(
      repository.fetchTodayActivity(),
      throwsA(isA<NetworkException>()),
    );
  });

  test('previous-day Today cache is rejected after a date change', () async {
    const cache = TemporaryDemoCache();
    await cache.saveToday(todayJson);
    final offlineClient = MockClient((_) async => http.Response('', 503));
    final repository = TodayActivityRepository(
      ApiClient(baseUrl: 'http://example.test', client: offlineClient),
      cache,
      () => DateTime(2026, 8, 11),
    );

    await expectLater(
      repository.fetchTodayActivity(),
      throwsA(isA<NetworkException>()),
    );
  });

  test('failed write does not mutate the cached fallback', () async {
    const cache = TemporaryDemoCache();
    await cache.saveToday(todayJson);
    final offlineClient = MockClient((request) async {
      expect(request.method, 'PATCH');
      return http.Response('', 503);
    });
    final repository = TodayActivityRepository(
      ApiClient(baseUrl: 'http://example.test', client: offlineClient),
      cache,
    );

    await expectLater(
      repository.updateTodayActivity(steps: 9000),
      throwsA(isA<NetworkException>()),
    );

    expect((await cache.loadToday())?['steps'], 7842.0);
  });
}
