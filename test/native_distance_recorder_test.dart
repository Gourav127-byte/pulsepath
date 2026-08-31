import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/features/distance/models/distance_recording_state.dart';
import 'package:pulsepath/features/distance/services/native_distance_recorder_service.dart';
import 'package:pulsepath/features/distance/providers/distance_recorder_provider.dart';
import 'package:pulsepath/features/distance/widgets/distance_recorder_card.dart';

class FakeNativeDistanceRecorder implements NativeDistanceRecorder {
  NativeRecorderStatus currentStatus = const NativeRecorderStatus(
    state: DistanceRecordingLifecycle.idle,
  );
  bool hasPermission = true;
  int startCalls = 0;
  int finishCalls = 0;

  @override
  Future<NativeRecorderStatus> startRecording(
    DistanceActivityType activityType,
  ) async {
    startCalls++;
    if (!hasPermission) {
      currentStatus = NativeRecorderStatus(
        state: DistanceRecordingLifecycle.interrupted,
        sessionId: 'session-123',
        activityType: activityType,
        interruptionReason: 'permission_revoked',
        isDistanceMissing: true,
      );
      return currentStatus;
    }
    currentStatus = NativeRecorderStatus(
      state: DistanceRecordingLifecycle.recording,
      sessionId: 'session-123',
      activityType: activityType,
      startTimeUtc: '2026-08-28T20:00:00Z',
      isDistanceMissing: true,
    );
    return currentStatus;
  }

  @override
  Future<NativeRecorderStatus> finishRecording() async {
    finishCalls++;
    currentStatus = NativeRecorderStatus(
      state: DistanceRecordingLifecycle.finalized,
      sessionId: currentStatus.sessionId,
      activityType: currentStatus.activityType,
      distanceMeters: currentStatus.distanceMeters ?? 450.0,
      isDistanceMissing: false,
      startTimeUtc: currentStatus.startTimeUtc,
      acceptedPointCount: currentStatus.acceptedPointCount,
      segmentCount: currentStatus.segmentCount,
    );
    return currentStatus;
  }

  @override
  Future<NativeRecorderStatus> getRecorderState() async {
    return currentStatus;
  }

  @override
  Future<bool> hasLocationPermission() async => hasPermission;

  @override
  Future<bool> requestLocationPermission() async => hasPermission;

  @override
  Stream<NativeRecorderStatus> observeStateChanges() {
    return Stream.value(currentStatus);
  }
}

class ControlledNativeDistanceRecorder extends FakeNativeDistanceRecorder {
  final StreamController<NativeRecorderStatus> events =
      StreamController<NativeRecorderStatus>.broadcast();
  final Completer<NativeRecorderStatus> stateResponse =
      Completer<NativeRecorderStatus>();

  @override
  Future<NativeRecorderStatus> getRecorderState() => stateResponse.future;

  @override
  Stream<NativeRecorderStatus> observeStateChanges() => events.stream;

  void emit(NativeRecorderStatus status) {
    currentStatus = status;
    events.add(status);
  }

  @override
  Future<NativeRecorderStatus> finishRecording() async {
    finishCalls++;
    final status = NativeRecorderStatus(
      state: DistanceRecordingLifecycle.finalized,
      sessionId: currentStatus.sessionId,
      activityType: currentStatus.activityType,
      distanceMeters: currentStatus.distanceMeters,
      isDistanceMissing: currentStatus.isDistanceMissing,
    );
    currentStatus = status;
    return status;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Distance Recording Models', () {
    test('DistanceRecordingLifecycle parses all states correctly', () {
      expect(
        DistanceRecordingLifecycle.fromString('IDLE'),
        DistanceRecordingLifecycle.idle,
      );
      expect(
        DistanceRecordingLifecycle.fromString('RECORDING'),
        DistanceRecordingLifecycle.recording,
      );
      expect(
        DistanceRecordingLifecycle.fromString('FINALIZED'),
        DistanceRecordingLifecycle.finalized,
      );
      expect(
        DistanceRecordingLifecycle.fromString('INTERRUPTED'),
        DistanceRecordingLifecycle.interrupted,
      );
      expect(
        DistanceRecordingLifecycle.fromString(null),
        DistanceRecordingLifecycle.idle,
      );
      expect(
        DistanceRecordingLifecycle.fromString('UNKNOWN'),
        DistanceRecordingLifecycle.idle,
      );
    });

    test('DistanceActivityType parses walk and run correctly', () {
      expect(
        DistanceActivityType.fromString('walk'),
        DistanceActivityType.walk,
      );
      expect(DistanceActivityType.fromString('run'), DistanceActivityType.run);
      expect(
        DistanceActivityType.fromString('WALK'),
        DistanceActivityType.walk,
      );
      expect(DistanceActivityType.fromString(null), isNull);
    });

    test(
      'NativeRecorderStatus serialization, distance conversion and getters',
      () {
        final status = NativeRecorderStatus.fromMap({
          'sessionId': 'uuid-1234',
          'state': 'RECORDING',
          'activityType': 'walk',
          'distanceMeters': 1250.0,
          'isDistanceMissing': false,
          'interruptionReason': null,
          'startTimeUtc': '2026-08-28T20:00:00Z',
          'acceptedPointCount': 12,
          'segmentCount': 2,
        });

        expect(status.sessionId, 'uuid-1234');
        expect(status.state, DistanceRecordingLifecycle.recording);
        expect(status.activityType, DistanceActivityType.walk);
        expect(status.distanceMeters, 1250.0);
        expect(status.distanceKm, 1.25);
        expect(status.isDistanceMissing, isFalse);
        expect(status.acceptedPointCount, 12);
        expect(status.segmentCount, 2);
        expect(status.isRecording, isTrue);

        final map = status.toMap();
        expect(map['sessionId'], 'uuid-1234');
        expect(map['state'], 'RECORDING');
        expect(map['activityType'], 'walk');
        expect(map['distanceMeters'], 1250.0);
      },
    );

    test('Missing distance remains null and isDistanceMissing is true', () {
      final status = NativeRecorderStatus.fromMap({
        'sessionId': 'uuid-5678',
        'state': 'RECORDING',
        'activityType': 'run',
        'distanceMeters': null,
        'isDistanceMissing': true,
      });

      expect(status.distanceMeters, isNull);
      expect(status.distanceKm, isNull);
      expect(status.isDistanceMissing, isTrue);
    });
  });

  group('MethodChannelDistanceRecorder Channel Bridge', () {
    const channel = MethodChannel('com.pulsepath.app/distance_recorder');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'startRecording') {
              final args = methodCall.arguments as Map<Object?, Object?>?;
              final type = args?['activityType'] as String? ?? 'walk';
              return {
                'sessionId': 'uuid-test',
                'state': 'RECORDING',
                'activityType': type,
                'distanceMeters': null,
                'isDistanceMissing': true,
                'segmentCount': 1,
                'acceptedPointCount': 0,
              };
            } else if (methodCall.method == 'finishRecording') {
              return {
                'sessionId': 'uuid-test',
                'state': 'FINALIZED',
                'activityType': 'walk',
                'distanceMeters': 350.0,
                'isDistanceMissing': false,
                'segmentCount': 1,
                'acceptedPointCount': 4,
              };
            } else if (methodCall.method == 'getRecorderState') {
              return {
                'sessionId': null,
                'state': 'IDLE',
                'activityType': null,
                'distanceMeters': null,
                'isDistanceMissing': true,
              };
            } else if (methodCall.method == 'hasLocationPermission' ||
                methodCall.method == 'requestLocationPermission') {
              return true;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'startRecording sends activityType and returns RECORDING status',
      () async {
        final recorder = MethodChannelDistanceRecorder();
        final result = await recorder.startRecording(DistanceActivityType.walk);

        expect(result.state, DistanceRecordingLifecycle.recording);
        expect(result.activityType, DistanceActivityType.walk);
        expect(result.sessionId, 'uuid-test');
        expect(result.isDistanceMissing, isTrue);
      },
    );

    test(
      'finishRecording transitions to FINALIZED status with distance',
      () async {
        final recorder = MethodChannelDistanceRecorder();
        final result = await recorder.finishRecording();

        expect(result.state, DistanceRecordingLifecycle.finalized);
        expect(result.distanceMeters, 350.0);
        expect(result.distanceKm, 0.35);
        expect(result.isDistanceMissing, isFalse);
      },
    );

    test('getRecorderState returns current status', () async {
      final recorder = MethodChannelDistanceRecorder();
      final result = await recorder.getRecorderState();

      expect(result.state, DistanceRecordingLifecycle.idle);
      expect(result.isDistanceMissing, isTrue);
    });
  });

  group('DistanceRecorderController', () {
    test('startWalk triggers native recorder and updates state', () async {
      final fakeRecorder = FakeNativeDistanceRecorder();
      final controller = DistanceRecorderController(fakeRecorder);

      await controller.startWalk();
      expect(controller.state.state, DistanceRecordingLifecycle.recording);
      expect(controller.state.activityType, DistanceActivityType.walk);
      expect(controller.state.sessionId, 'session-123');
      expect(fakeRecorder.startCalls, 1);
    });

    test('startRun triggers native recorder for run', () async {
      final fakeRecorder = FakeNativeDistanceRecorder();
      final controller = DistanceRecorderController(fakeRecorder);

      await controller.startRun();
      expect(controller.state.state, DistanceRecordingLifecycle.recording);
      expect(controller.state.activityType, DistanceActivityType.run);
      expect(fakeRecorder.startCalls, 1);
    });

    test('finish triggers finishRecording on native service', () async {
      final fakeRecorder = FakeNativeDistanceRecorder();
      final controller = DistanceRecorderController(fakeRecorder);

      await controller.startWalk();
      await controller.finish();

      expect(controller.state.state, DistanceRecordingLifecycle.finalized);
      expect(fakeRecorder.finishCalls, 1);
    });

    test('permission denial sets state to INTERRUPTED', () async {
      final fakeRecorder = FakeNativeDistanceRecorder()..hasPermission = false;
      final controller = DistanceRecorderController(fakeRecorder);

      final status = await controller.startWalk();
      expect(status.state, DistanceRecordingLifecycle.interrupted);
      expect(controller.state.state, DistanceRecordingLifecycle.interrupted);
      expect(status.interruptionReason, 'permission_revoked');
    });

    test('duplicate start/finish calls are idempotent', () async {
      final fakeRecorder = FakeNativeDistanceRecorder();
      final controller = DistanceRecorderController(fakeRecorder);

      await controller.startWalk();
      await controller.startWalk(); // Duplicate call

      expect(controller.state.state, DistanceRecordingLifecycle.recording);

      await controller.finish();
      await controller.finish(); // Duplicate call

      expect(controller.state.state, DistanceRecordingLifecycle.finalized);
    });

    test('recording event wins over delayed stale initial state', () async {
      final recorder = ControlledNativeDistanceRecorder();
      final controller = DistanceRecorderController(recorder);
      await Future<void>.delayed(Duration.zero);

      recorder.emit(
        const NativeRecorderStatus(
          state: DistanceRecordingLifecycle.recording,
          sessionId: 'recording-session',
          activityType: DistanceActivityType.walk,
        ),
      );
      recorder.stateResponse.complete(
        const NativeRecorderStatus(
          state: DistanceRecordingLifecycle.finalized,
          sessionId: 'stale-session',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.state, DistanceRecordingLifecycle.recording);
      expect(controller.state.sessionId, 'recording-session');
      controller.dispose();
    });

    test('listener attach reconciles a session already recording', () async {
      final recorder = ControlledNativeDistanceRecorder()
        ..currentStatus = const NativeRecorderStatus(
          state: DistanceRecordingLifecycle.recording,
          sessionId: 'existing-session',
          activityType: DistanceActivityType.walk,
        );
      final controller = DistanceRecorderController(recorder);
      recorder.emit(recorder.currentStatus);
      recorder.stateResponse.complete(recorder.currentStatus);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.state, DistanceRecordingLifecycle.recording);
      expect(controller.state.sessionId, 'existing-session');
      controller.dispose();
    });

    test(
      'Flutter recreation restores an existing native recording session',
      () async {
        final recorder = FakeNativeDistanceRecorder();
        await recorder.startRecording(DistanceActivityType.walk);

        final firstController = DistanceRecorderController(recorder);
        await Future<void>.delayed(Duration.zero);
        firstController.dispose();

        final recreatedController = DistanceRecorderController(recorder);
        await Future<void>.delayed(Duration.zero);

        expect(
          recreatedController.state.state,
          DistanceRecordingLifecycle.recording,
        );
        expect(recreatedController.state.sessionId, 'session-123');
        recreatedController.dispose();
      },
    );

    test(
      'finish remains FINALIZED and cannot be overwritten by older state',
      () async {
        final recorder = ControlledNativeDistanceRecorder();
        final controller = DistanceRecorderController(recorder);
        await controller.startWalk();

        recorder.emit(
          const NativeRecorderStatus(
            state: DistanceRecordingLifecycle.recording,
            sessionId: 'session-123',
            activityType: DistanceActivityType.walk,
          ),
        );
        final finish = controller.finish();
        await finish;

        expect(controller.state.state, DistanceRecordingLifecycle.finalized);
        controller.dispose();
      },
    );
  });

  group('DistanceRecorderCard Widget Tests', () {
    testWidgets(
      'DistanceRecorderCard renders Start Walk, Start Run, and Finish controls',
      (tester) async {
        final fakeRecorder = FakeNativeDistanceRecorder();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nativeDistanceRecorderProvider.overrideWithValue(fakeRecorder),
            ],
            child: const MaterialApp(
              home: Scaffold(body: DistanceRecorderCard()),
            ),
          ),
        );

        expect(find.byKey(const Key('distance_recorder_card')), findsOneWidget);
        expect(find.byKey(const Key('start_walk_button')), findsOneWidget);
        expect(find.byKey(const Key('start_run_button')), findsOneWidget);
        expect(find.byKey(const Key('finish_session_button')), findsOneWidget);

        // Start Walk tap
        await tester.tap(find.byKey(const Key('start_walk_button')));
        await tester.pumpAndSettle();

        expect(fakeRecorder.startCalls, 1);
        expect(find.text('RECORDING (WALK)'), findsOneWidget);

        // Finish tap
        await tester.tap(find.byKey(const Key('finish_session_button')));
        await tester.pumpAndSettle();

        expect(fakeRecorder.finishCalls, 1);
        expect(find.text('FINALIZED'), findsOneWidget);
      },
    );

    testWidgets(
      'DistanceRecorderCard renders without overflow on a narrow 320px viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRecorder = FakeNativeDistanceRecorder();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nativeDistanceRecorderProvider.overrideWithValue(fakeRecorder),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DistanceRecorderCard(),
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('distance_recorder_card')), findsOneWidget);
        expect(find.byKey(const Key('start_walk_button')), findsOneWidget);
        expect(find.byKey(const Key('start_run_button')), findsOneWidget);
        expect(find.byKey(const Key('finish_session_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
