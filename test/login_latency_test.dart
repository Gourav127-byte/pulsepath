import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/cache/temporary_demo_cache.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/auth/data/auth_repository.dart';
import 'package:pulsepath/features/auth/data/token_storage.dart';
import 'package:pulsepath/features/auth/models/auth_user.dart';
import 'package:pulsepath/features/auth/presentation/auth_gate.dart';
import 'package:pulsepath/features/auth/providers/auth_provider.dart';
import 'package:pulsepath/features/goals/presentation/goals_screen.dart';
import 'package:pulsepath/features/journey/presentation/journey_screen.dart';
import 'package:pulsepath/features/profile/presentation/profile_screen.dart';
import 'package:pulsepath/features/today/presentation/pulse_path_shell.dart';
import 'package:pulsepath/features/today/presentation/today_screen.dart';
import 'package:pulsepath/features/veya/presentation/veya_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const loginResponse = <String, dynamic>{
    'access_token': 'test_access_token_123',
    'refresh_token': 'test_refresh_token_456',
    'token_type': 'bearer',
    'user': {'id': 'user_123', 'email': 'test@pulsepath.com'},
  };

  const todayResponse = <String, dynamic>{
    'date': '2026-08-25',
    'steps': 5000.0,
    'active_minutes': 30.0,
    'distance': 3.8,
    'calories': 200.0,
    'daily_score': 75.0,
    'score_version': 'v1',
    'source': 'manual',
    'recording_status': 'recorded',
  };

  const goalsResponse = <Map<String, dynamic>>[];
  const historyResponse = <Map<String, dynamic>>[];
  const engagementResponse = <String, dynamic>{
    'user_id': 'user_123',
    'current_streak': 3,
    'longest_streak': 10,
    'weekly_recorded_days': 5,
    'monthly_recorded_days': 20,
    'freeze_credits': 1,
    'is_streak_active': true,
  };
  const veyaResponse = <String, dynamic>{
    'response': 'Veya insights ready',
    'evidence': <String, dynamic>{},
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('measures login latency breakdown and verifies token persistence', (
    WidgetTester tester,
  ) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    int? tApiDone;
    int? tStorageDone;
    int? tStateAuthDone;
    int? tFirstHomeFrameDone;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/auth/login') {
        tApiDone = stopwatch.elapsedMilliseconds;
        return http.Response(jsonEncode(loginResponse), 200);
      }
      if (request.url.path == '/activity/today') {
        return http.Response(jsonEncode(todayResponse), 200);
      }
      if (request.url.path == '/goals') {
        return http.Response(jsonEncode(goalsResponse), 200);
      }
      if (request.url.path == '/activity/history') {
        return http.Response(jsonEncode(historyResponse), 200);
      }
      if (request.url.path == '/activity/engagement') {
        return http.Response(jsonEncode(engagementResponse), 200);
      }
      if (request.url.path.startsWith('/veya/foundation')) {
        return http.Response(jsonEncode(veyaResponse), 200);
      }
      if (request.url.path == '/profile') {
        return http.Response(jsonEncode({'id': 'user_123', 'email': 'test@pulsepath.com'}), 200);
      }
      return http.Response('', 404);
    });

    final storage = MemoryTokenStorage();
    final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:8000', client: mockClient);
    final repository = AuthRepository(apiClient, storage, TemporaryDemoCache());

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );

    final controller = container.read(authControllerProvider.notifier);

    // Step 1: Trigger Login
    final loginFuture = controller.login('test@pulsepath.com', 'Password123!');
    final success = await loginFuture;
    expect(success, isTrue);

    tStorageDone = stopwatch.elapsedMilliseconds;

    // Verify token persistence before navigation
    final storedAccess = await storage.readToken();
    final storedRefresh = await storage.readRefreshToken();
    expect(storedAccess, equals('test_access_token_123'));
    expect(storedRefresh, equals('test_refresh_token_456'));

    tStateAuthDone = stopwatch.elapsedMilliseconds;
    expect(container.read(authControllerProvider).status, equals(AuthStatus.authenticated));

    // Step 2: Render AuthGate to Home Shell
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    tFirstHomeFrameDone = stopwatch.elapsedMilliseconds;

    // Verify Home renders
    expect(find.byType(PulsePathShell), findsOneWidget);
    expect(find.byType(TodayScreen), findsOneWidget);

    // Print evidence-backed latency breakdown
    debugPrint('[LATENCY_AUDIT] Login Tap -> Auth API Response: ${tApiDone}ms');
    debugPrint('[LATENCY_AUDIT] Auth API -> Secure Token Storage: ${tStorageDone - tApiDone!}ms');
    debugPrint('[LATENCY_AUDIT] Secure Storage -> AuthState Authenticated: ${tStateAuthDone - tStorageDone}ms');
    debugPrint('[LATENCY_AUDIT] AuthState -> First Home Frame: ${tFirstHomeFrameDone - tStateAuthDone}ms');
    debugPrint('[LATENCY_AUDIT] Total Login Tap -> First Home Frame: ${tFirstHomeFrameDone}ms');

    stopwatch.stop();
  });

  testWidgets('lazy shell tab rendering defers non-Home screens until selected', (
    WidgetTester tester,
  ) async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode(todayResponse), 200);
    });

    final storage = MemoryTokenStorage();
    await storage.saveToken('test_access', 'test_refresh');
    final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:8000', client: mockClient);
    final repository = AuthRepository(apiClient, storage);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          (ref) => AuthController.forTesting(
            const AuthState(
              AuthStatus.authenticated,
              user: AuthUser(id: 'user_123', email: 'test@pulsepath.com'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    // Verify Home (TodayScreen) is mounted, but Journey, Veya, Goals, Profile are DEFERRED
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(JourneyScreen), findsNothing);
    expect(find.byType(VeyaScreen), findsNothing);
    expect(find.byType(GoalsScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsNothing);

    // Tap Journey tab (index 1)
    await tester.tap(find.byIcon(Icons.route_outlined));
    await tester.pump();

    // Verify JourneyScreen is now mounted lazily
    expect(find.byType(JourneyScreen), findsOneWidget);
  });
}

class MemoryTokenStorage implements TokenStorage {
  String? token;
  String? refreshToken;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveToken(String token, [String? refreshToken]) async {
    this.token = token;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> deleteToken() async {
    token = null;
    refreshToken = null;
  }
}
