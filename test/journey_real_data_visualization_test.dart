import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/features/journey/models/activity_history_entry.dart';
import 'package:pulsepath/features/journey/widgets/real_activity_snapshot_card.dart';
import 'package:pulsepath/features/journey/widgets/real_metric_progression_card.dart';

void main() {
  group('Phase 22.5B — Journey Real-Data Visualization Tests', () {
    testWidgets('RealActivitySnapshotCard displays recorded metrics and renders -- for missing values', (tester) async {
      final recordedEntry = ActivityHistoryEntry(
        date: DateTime(2026, 8, 28),
        steps: 4210,
        distance: 3.15,
        activeMinutes: 45,
        activeCalories: 210,
        scoreVersion: 'v2',
        source: 'health_connect',
        recordingStatus: HistoryRecordingStatus.recorded,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RealActivitySnapshotCard(entry: recordedEntry),
            ),
          ),
        ),
      );

      expect(find.text('Real Activity Snapshot'), findsOneWidget);
      expect(find.text('Recorded Evidence'), findsOneWidget);
      expect(find.text('4,210 steps'), findsOneWidget);
      expect(find.text('3.15 km'), findsOneWidget);
      expect(find.text('45 mins'), findsOneWidget);
      expect(find.text('210 kcal'), findsOneWidget);
      expect(find.textContaining('Source Provenance: health_connect'), findsOneWidget);
    });

    testWidgets('RealActivitySnapshotCard renders -- / Not recorded for missing metrics without step estimation', (tester) async {
      final missingEntry = ActivityHistoryEntry(
        date: DateTime(2026, 8, 28),
        steps: 5000,
        distance: null, // Missing distance
        activeMinutes: null, // Missing active minutes
        activeCalories: null, // Missing calories
        scoreVersion: 'v2',
        source: 'health_connect',
        recordingStatus: HistoryRecordingStatus.recorded,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RealActivitySnapshotCard(entry: missingEntry),
            ),
          ),
        ),
      );

      expect(find.text('5,000 steps'), findsOneWidget);
      expect(find.text('-- / Not recorded'), findsNWidgets(3)); // 3 missing metrics
    });

    testWidgets('RealMetricProgressionCard toggles metric tabs and renders recorded entries', (tester) async {
      final entries = [
        ActivityHistoryEntry(
          date: DateTime(2026, 8, 28),
          steps: 5000,
          distance: 3.8,
          activeMinutes: 40,
          activeCalories: 200,
          scoreVersion: 'v2',
          source: 'health_connect',
          recordingStatus: HistoryRecordingStatus.recorded,
        ),
        ActivityHistoryEntry(
          date: DateTime(2026, 8, 27),
          steps: 3000,
          distance: null, // Missing distance
          activeMinutes: 25,
          activeCalories: null,
          scoreVersion: 'v2',
          source: 'health_connect',
          recordingStatus: HistoryRecordingStatus.recorded,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RealMetricProgressionCard(entries: entries, days: 7),
            ),
          ),
        ),
      );

      expect(find.text('Real Metric Progression'), findsOneWidget);
      expect(find.text('Missing != Zero'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);

      // Verify Steps tab shows step counts
      expect(find.text('5000'), findsOneWidget);
      expect(find.text('3000'), findsOneWidget);

      // Tap Distance tab
      await tester.tap(find.text('Distance'));
      await tester.pumpAndSettle();

      expect(find.text('3.8'), findsOneWidget);
      expect(find.text('--'), findsOneWidget); // Missing distance renders --
    });
  });
}
