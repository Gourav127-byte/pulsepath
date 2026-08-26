import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/veya/data/veya_repository.dart';
import 'package:pulsepath/features/veya/models/veya_foundation.dart';
import 'package:pulsepath/features/veya/providers/veya_providers.dart';
import 'package:pulsepath/features/veya/widgets/veya_badge.dart';
import 'package:pulsepath/features/veya/widgets/veya_integrity_card.dart';
import 'package:pulsepath/features/veya/widgets/veya_insights_card.dart';
import 'package:pulsepath/features/veya/widgets/veya_suggestions_card.dart';

void main() {
  testWidgets('VeyaBadge renders logo correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: VeyaBadge(size: 32))),
      ),
    );

    expect(find.text('V'), findsOneWidget);
  });

  testWidgets('VeyaIntegrityCard displays level and coverage statistics', (
    tester,
  ) async {
    const integrity = VeyaIntegrityLens(
      level: 'solid',
      confirmedDays: 5,
      legacyDays: 0,
      missingDays: 2,
      confirmedCoverage: 0.71,
      rationale: '71% confirmed coverage over 7 days.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VeyaIntegrityCard(integrity: integrity)),
      ),
    );

    expect(find.text('INTEGRITY LENS'), findsOneWidget);
    expect(find.text('SOLID'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget);
    expect(find.text('COVERAGE'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VeyaInsightsCard renders summary and observations', (
    tester,
  ) async {
    const response = VeyaStructuredResponse(
      status: 'generated',
      summary: 'Strong activity pattern detected.',
      observations: [
        VeyaObservation(
          text: '5,000 steps reached consistently.',
          confidence: 'high',
          category: 'consistency',
          evidence: [VeyaEvidenceCitation(fact: 'steps', date: '2026-08-23')],
        ),
      ],
      limitations: ['Sparse historical data.'],
      medicalOrCausalClaims: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VeyaInsightsCard(response: response)),
      ),
    );

    expect(find.text('VEYA INSIGHTS'), findsOneWidget);
    expect(find.text('Strong activity pattern detected.'), findsOneWidget);
    expect(find.text('5,000 steps reached consistently.'), findsOneWidget);
    expect(find.text('HIGH CONFIDENCE'), findsOneWidget);
    expect(find.text('Fact: steps (2026-08-23)'), findsOneWidget);
  });

  testWidgets('VEYA cards remain responsive on narrow Android width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const integrity = VeyaIntegrityLens(
      level: 'sparse',
      confirmedDays: 1,
      legacyDays: 0,
      missingDays: 6,
      confirmedCoverage: 0.14,
      rationale: 'Fewer than two confirmed recorded days are available.',
    );
    const response = VeyaStructuredResponse(
      status: 'provider_unavailable',
      summary: 'VEYA insights are temporarily unavailable.',
      observations: [],
      limitations: [],
      medicalOrCausalClaims: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                VeyaIntegrityCard(integrity: integrity),
                VeyaInsightsCard(response: response),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text("Insights aren't ready yet"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VeyaSuggestionsCard renders category action items', (
    tester,
  ) async {
    const observations = [
      VeyaObservation(
        text: 'Maintain your current daily streak.',
        confidence: 'high',
        category: 'consistency',
        evidence: [VeyaEvidenceCitation(fact: 'current_streak')],
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VeyaSuggestionsCard(observations: observations)),
      ),
    );

    expect(find.text('SMART SUGGESTIONS & HIGHLIGHTS'), findsOneWidget);
    expect(find.text('Maintain your current daily streak.'), findsOneWidget);
  });

  test('VeyaChatNotifier prevents duplicate in-flight requests', () async {
    final mockRepo = _MockVeyaRepository();
    final notifier = VeyaChatNotifier(mockRepo);

    expect(notifier.state.length, 1);
    final future1 = notifier.sendMessage('First query');
    final future2 = notifier.sendMessage(
      'Second query',
    ); // Should be ignored while sending

    await Future.wait([future1, future2]);
    expect(mockRepo.sendCount, 1);
  });
}

class _MockVeyaRepository extends VeyaRepository {
  int sendCount = 0;

  _MockVeyaRepository()
    : super(ApiClient(baseUrl: 'http://localhost:8000', client: http.Client()));

  @override
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    int rangeDays = 7,
  }) async {
    sendCount++;
    await Future.delayed(const Duration(milliseconds: 50));
    return {
      'query': message,
      'reply': 'Mocked answer',
      'status': 'grounded',
      'observations': [],
    };
  }
}
