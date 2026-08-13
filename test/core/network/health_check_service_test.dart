import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/core/network/health_check_service.dart';

void main() {
  const baseUrl = 'http://192.168.29.78:8000';

  test('health check succeeds for an ok response', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.toString(), '$baseUrl/health');
      return http.Response('{"status":"ok"}', 200);
    });
    final service = HealthCheckService(
      ApiClient(baseUrl: baseUrl, client: mockClient),
    );

    await expectLater(service.checkHealth(), completes);
  });

  test('health check converts a server error to NetworkException', () async {
    final mockClient = MockClient((_) async => http.Response('error', 500));
    final service = HealthCheckService(
      ApiClient(baseUrl: baseUrl, client: mockClient),
    );

    await expectLater(
      service.checkHealth(),
      throwsA(
        isA<NetworkException>().having(
          (error) => error.message,
          'message',
          'Request failed with status 500.',
        ),
      ),
    );
  });

  test('request timeout becomes a clean NetworkException', () async {
    final mockClient = MockClient((_) => Completer<http.Response>().future);
    final service = HealthCheckService(
      ApiClient(
        baseUrl: baseUrl,
        client: mockClient,
        requestTimeout: const Duration(milliseconds: 1),
      ),
    );

    await expectLater(
      service.checkHealth(),
      throwsA(
        isA<NetworkException>().having(
          (error) => error.message,
          'message',
          'Request timed out.',
        ),
      ),
    );
  });

  test('PATCH sends JSON content and decodes the response', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.toString(), '$baseUrl/profile');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {'haptic_feedback': false});
      return http.Response('{"saved":true}', 200);
    });
    final client = ApiClient(baseUrl: baseUrl, client: mockClient);

    final response = await client.patchJson('/profile', {
      'haptic_feedback': false,
    });

    expect(response, {'saved': true});
  });

  test('PATCH backend errors use NetworkException', () async {
    final mockClient = MockClient((_) async => http.Response('error', 500));
    final client = ApiClient(baseUrl: baseUrl, client: mockClient);

    await expectLater(
      client.patchJson('/profile', {'display_name': 'Alex'}),
      throwsA(isA<NetworkException>()),
    );
  });

  test('POST sends JSON content and decodes the response', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), '$baseUrl/goals');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {
        'type': 'distance',
        'target_value': 8.0,
      });
      return http.Response('{"created":true}', 201);
    });
    final client = ApiClient(baseUrl: baseUrl, client: mockClient);

    final response = await client.postJson('/goals', {
      'type': 'distance',
      'target_value': 8.0,
    });

    expect(response, {'created': true});
  });

  test('DELETE accepts a 204 response without decoding JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.toString(), '$baseUrl/goals/goal-1');
      return http.Response('', 204);
    });
    final client = ApiClient(baseUrl: baseUrl, client: mockClient);

    await expectLater(client.delete('/goals/goal-1'), completes);
  });

  test('POST and DELETE backend errors use NetworkException', () async {
    final client = ApiClient(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('error', 500)),
    );

    await expectLater(
      client.postJson('/goals', {'type': 'distance'}),
      throwsA(isA<NetworkException>()),
    );
    await expectLater(
      client.delete('/goals/goal-1'),
      throwsA(isA<NetworkException>()),
    );
  });
}
