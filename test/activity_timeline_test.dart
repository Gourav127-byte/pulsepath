import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/today/data/health_sync_repository.dart';
import 'package:pulsepath/features/today/data/today_activity_repository.dart';
import 'package:pulsepath/features/today/services/health_connect_service.dart';

class MockHealthConnectServiceForTimeline implements HealthConnectService {
  MockHealthConnectServiceForTimeline({required this.samples});

  final List<StepSampleRecord> samples;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<HealthSyncResult> fetchDailyData() async {
    return HealthSyncResult(
      steps: 1650,
      distance: 1.2,
      calories: 120,
      activeMinutes: 25,
      timelineSamples: samples,
    );
  }
}

void main() {
  test('StepSampleRecord serializes correctly to json with ISO UTC time', () {
    final start = DateTime.utc(2026, 8, 26, 8, 15);
    final end = start.add(const Duration(minutes: 15));
    final sample = StepSampleRecord(
      startTime: start,
      endTime: end,
      steps: 450,
      sourceOrigin: 'health_connect_aggregate',
      sampleId: 'hc_agg_1787645700000_1787646600000',
    );

    final json = sample.toJson();
    expect(json['sample_id'], equals('hc_agg_1787645700000_1787646600000'));
    expect(json['start_time'], equals('2026-08-26T08:15:00.000Z'));
    expect(json['end_time'], equals('2026-08-26T08:30:00.000Z'));
    expect(json['steps'], equals(450));
    expect(json['source_origin'], equals('health_connect_aggregate'));
  });

  test('HealthSyncRepository syncs 15-minute duration aggregate samples to backend', () async {
    int syncCallCount = 0;
    List<Map<String, dynamic>> syncedSamples = [];

    final mockClient = MockClient((request) async {
      if (request.url.path == '/activity/timeline/sync') {
        syncCallCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        syncedSamples = (body['samples'] as List).cast<Map<String, dynamic>>();
        return http.Response(
          jsonEncode({
            'date': '2026-08-26',
            'total_steps': 41,
            'samples_count': syncedSamples.length,
            'timeline': syncedSamples,
          }),
          200,
        );
      }
      if (request.url.path == '/activity/today') {
        return http.Response(
          jsonEncode({
            'date': '2026-08-26',
            'steps': 41.0,
            'active_minutes': null,
            'distance': null,
            'calories': null,
            'daily_score': 10.0,
            'score_version': 'v2',
            'source': 'health_connect',
            'recording_status': 'recorded',
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:8000', client: mockClient);
    final activityRepository = TodayActivityRepository(apiClient);

    // 15-minute duration bucket (08:15 to 08:30 = 41 steps)
    final bucketSample = StepSampleRecord(
      startTime: DateTime.utc(2026, 8, 26, 8, 15),
      endTime: DateTime.utc(2026, 8, 26, 8, 30),
      steps: 41,
      sourceOrigin: 'health_connect_aggregate',
      sampleId: 'hc_agg_1787645700000_1787646600000',
    );

    final healthService = MockHealthConnectServiceForTimeline(samples: [bucketSample]);
    final syncRepository = HealthSyncRepository(healthService, activityRepository);

    // Initial sync
    final outcome1 = await syncRepository.sync();
    expect(outcome1, equals(HealthSyncOutcome.updated));
    expect(syncCallCount, equals(1));
    expect(syncedSamples.length, equals(1));
    expect(syncedSamples.first['source_origin'], equals('health_connect_aggregate'));

    // Duplicate sync (idempotency test - same sampleId re-sent)
    final outcome2 = await syncRepository.sync();
    expect(outcome2, equals(HealthSyncOutcome.updated));
    expect(syncCallCount, equals(2));
    expect(syncedSamples.first['sample_id'], equals('hc_agg_1787645700000_1787646600000'));
  });
}
