import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/core/theme/pulse_path_theme.dart';
import 'package:pulsepath/features/startup/presentation/startup_screen.dart';
import 'package:pulsepath/features/startup/services/startup_sound.dart';

void main() {
  testWidgets('plays the branded startup sequence then reveals the app', (
    tester,
  ) async {
    final sound = _FakeStartupSound();
    await tester.pumpWidget(
      MaterialApp(
        theme: PulsePathTheme.dark,
        home: PulsePathStartupScreen(
          duration: const Duration(milliseconds: 100),
          soundPlayer: sound,
          firstFrameReady: Future<void>.value(),
          destination: const Text('PulsePath home'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PulsePath'), findsOneWidget);
    expect(find.text('MOVE  •  BUILD  •  REPEAT'), findsOneWidget);
    expect(sound.playCount, 1);

    // The startup timeline intentionally begins after the first rendered frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();

    expect(find.text('PulsePath home'), findsOneWidget);
    expect(find.text('MOVE  •  BUILD  •  REPEAT'), findsNothing);
  });

  testWidgets('system reduce-motion skips sound and shortens the sequence', (
    tester,
  ) async {
    final sound = _FakeStartupSound();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: PulsePathTheme.dark,
          home: PulsePathStartupScreen(
            soundPlayer: sound,
            firstFrameReady: Future<void>.value(),
            destination: const Text('PulsePath home'),
          ),
        ),
      ),
    );

    expect(sound.playCount, 0);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('PulsePath home'), findsOneWidget);
  });
}

class _FakeStartupSound implements StartupSoundPlayer {
  int playCount = 0;

  @override
  Future<void> play() async => playCount++;

  @override
  Future<void> dispose() async {}
}
