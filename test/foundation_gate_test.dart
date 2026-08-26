import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/auth/data/token_storage.dart';

class MockTokenStorage implements TokenStorage {
  String? accessToken = 'initial_access_token';
  String? refreshToken = 'initial_refresh_token';

  @override
  Future<void> saveToken(String access, [String? refresh]) async {
    accessToken = access;
    if (refresh != null) refreshToken = refresh;
  }

  @override
  Future<String?> readToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> deleteToken() async {
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  group('Single-Flight 401 Token Refresh Tests', () {
    test('Simultaneous 401 requests trigger exactly 1 refresh HTTP call', () async {
      int refreshCallCount = 0;
      final tokenStorage = MockTokenStorage();

      late ApiClient client;
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshCallCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
            }),
            200,
          );
        }

        final authHeader = request.headers['Authorization'];
        if (authHeader == 'Bearer new_access_token') {
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }

        // Return 401 for old/initial token
        return http.Response(jsonEncode({'detail': 'Unauthorized'}), 401);
      });

      client = ApiClient(
        baseUrl: 'http://localhost:8000',
        client: mockHttpClient,
        authTokenProvider: tokenStorage.readToken,
        refreshTokenProvider: tokenStorage.readRefreshToken,
        onTokenRefreshed: (acc, ref) => tokenStorage.saveToken(acc, ref),
      );

      // Fire 3 simultaneous API calls receiving 401
      final results = await Future.wait([
        client.getJson('/activity/today'),
        client.getJson('/activity/today'),
        client.getJson('/activity/today'),
      ]);

      expect(refreshCallCount, equals(1));
      expect(results.length, equals(3));
      expect(results[0]['status'], equals('ok'));
      expect(await tokenStorage.readToken(), equals('new_access_token'));
    });
  });
}
