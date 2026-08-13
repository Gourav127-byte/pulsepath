import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';

void main() {
  group('ApiClient Authentication', () {
    test('injects Bearer token when authTokenProvider is supplied', () async {
      late http.BaseRequest capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://example.test',
        client: client,
        authTokenProvider: () async => 'test-token',
      );

      await apiClient.getJson('/test');

      expect(capturedRequest.headers['Authorization'], 'Bearer test-token');
    });

    test('manual token in getJsonWithBearer overrides provider', () async {
      late http.BaseRequest capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://example.test',
        client: client,
        authTokenProvider: () async => 'provider-token',
      );

      await apiClient.getJsonWithBearer('/test', 'manual-token');

      expect(capturedRequest.headers['Authorization'], 'Bearer manual-token');
    });

    test('triggers onUnauthorized callback on 401 response', () async {
      var unauthorizedCalled = false;
      final client = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://example.test',
        client: client,
        onUnauthorized: () => unauthorizedCalled = true,
      );

      try {
        await apiClient.getJson('/test');
      } catch (_) {}

      expect(unauthorizedCalled, isTrue);
    });
  });
}
