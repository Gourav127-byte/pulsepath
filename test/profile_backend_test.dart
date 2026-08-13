import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/profile/data/profile_repository.dart';
import 'package:pulsepath/features/profile/models/backend_profile.dart';

void main() {
  const profileJson = <String, dynamic>{
    'id': '11111111-1111-1111-1111-111111111111',
    'display_name': 'Alex',
    'subtitle': 'Building better daily habits',
    'dark_theme': true,
    'reduce_motion': false,
    'haptic_feedback': true,
    'use_metric_units': true,
  };

  test('BackendProfile parses every snake_case response field', () {
    final profile = BackendProfile.fromJson(profileJson);

    expect(profile.id, profileJson['id']);
    expect(profile.displayName, profileJson['display_name']);
    expect(profile.subtitle, profileJson['subtitle']);
    expect(profile.darkTheme, isTrue);
    expect(profile.reduceMotion, isFalse);
    expect(profile.hapticFeedback, isTrue);
    expect(profile.useMetricUnits, isTrue);
  });

  test('ProfileRepository performs GET /profile', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/profile');
      return http.Response(
        '{"id":"11111111-1111-1111-1111-111111111111",'
        '"display_name":"Alex",'
        '"subtitle":"Building better daily habits",'
        '"dark_theme":true,"reduce_motion":false,'
        '"haptic_feedback":true,"use_metric_units":true}',
        200,
      );
    });
    final repository = ProfileRepository(
      ApiClient(baseUrl: 'http://example.test', client: client),
    );

    final profile = await repository.fetchProfile();

    expect(profile.displayName, 'Alex');
    expect(profile.hapticFeedback, isTrue);
  });

  test('ProfileRepository PATCH sends only supplied fields', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/profile');
      expect(jsonDecode(request.body), {
        'display_name': 'Alex M',
        'haptic_feedback': false,
      });
      return http.Response(
        '{"id":"11111111-1111-1111-1111-111111111111",'
        '"display_name":"Alex M","subtitle":"Building better daily habits",'
        '"dark_theme":true,"reduce_motion":false,'
        '"haptic_feedback":false,"use_metric_units":true}',
        200,
      );
    });
    final repository = ProfileRepository(
      ApiClient(baseUrl: 'http://example.test', client: client),
    );

    final profile = await repository.updateProfile({
      'display_name': 'Alex M',
      'haptic_feedback': false,
    });

    expect(profile.displayName, 'Alex M');
    expect(profile.hapticFeedback, isFalse);
  });
}
