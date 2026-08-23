import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepath/features/veya/models/veya_foundation.dart';
import 'package:pulsepath/features/veya/widgets/veya_badge.dart';
import 'package:pulsepath/features/veya/widgets/veya_integrity_card.dart';
import 'package:pulsepath/features/veya/widgets/veya_insights_card.dart';
import 'package:pulsepath/features/veya/widgets/veya_suggestions_card.dart';

void main() {
  testWidgets('VeyaBadge renders logo correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: VeyaBadge(size: 32)),
        ),
      ),
    );

    expect(find.text('V'), findsOneWidget);
  });

  testWidgets('VeyaIntegrityCard displays level and coverage statistics', (tester) async {
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
        home: Scaffold(
          body: VeyaIntegrityCard(integrity: integrity),
        ),
      ),
    );

    expect(find.text('INTEGRITY LENS'), findsOneWidget);
    expect(find.text('SOLID'), findsOneWidget);
    expect(find.text('71% Coverage'), findsOneWidget);
    expect(find.text('5d'), findsOneWidget);
    expect(find.text('0d'), findsOneWidget);
    expect(find.text('2d'), findsOneWidget);
  });

  testWidgets('VeyaInsightsCard renders summary and observations', (tester) async {
    const response = VeyaStructuredResponse(
      status: 'generated',
      summary: 'Strong activity pattern detected.',
      observations: [
        VeyaObservation(
          text: '5,000 steps reached consistently.',
          confidence: 'high',
          category: 'consistency',
          evidence: [
            VeyaEvidenceCitation(fact: 'steps', date: '2026-08-23'),
          ],
        ),
      ],
      limitations: ['Sparse historical data.'],
      medicalOrCausalClaims: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VeyaInsightsCard(response: response),
        ),
      ),
    );

    expect(find.text('VEYA INTELLIGENCE'), findsOneWidget);
    expect(find.text('Strong activity pattern detected.'), findsOneWidget);
    expect(find.text('5,000 steps reached consistently.'), findsOneWidget);
    expect(find.text('HIGH CONFIDENCE'), findsOneWidget);
    expect(find.text('Fact: steps (2026-08-23)'), findsOneWidget);
  });

  testWidgets('VeyaSuggestionsCard renders category action items', (tester) async {
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
        home: Scaffold(
          body: VeyaSuggestionsCard(observations: observations),
        ),
      ),
    );

    expect(find.text('SMART SUGGESTIONS & HIGHLIGHTS'), findsOneWidget);
    expect(find.text('Maintain your current daily streak.'), findsOneWidget);
  });
}
