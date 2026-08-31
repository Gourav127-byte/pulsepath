import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/distance_recording_state.dart';
import '../services/native_distance_recorder_service.dart';

final nativeDistanceRecorderProvider = Provider<NativeDistanceRecorder>((ref) {
  return MethodChannelDistanceRecorder();
});

class DistanceRecorderController extends StateNotifier<NativeRecorderStatus>
    with WidgetsBindingObserver {
  DistanceRecorderController(this._service)
    : super(
        const NativeRecorderStatus(state: DistanceRecordingLifecycle.idle),
      ) {
    _init();
  }

  final NativeDistanceRecorder _service;
  StreamSubscription<NativeRecorderStatus>? _subscription;
  int _stateRevision = 0;
  bool _commandInFlight = false;

  void _init() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _service.observeStateChanges().listen((status) {
      if (_commandInFlight) {
        return;
      }
      _stateRevision++;
      state = status;
    });
    refreshState();
  }

  Future<void> refreshState() async {
    final revisionAtRequest = _stateRevision;
    final status = await _service.getRecorderState();
    if (revisionAtRequest == _stateRevision) {
      state = status;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshState();
    }
  }

  /// Explicit user action to start recording a Walk session.
  /// Native service is authoritative; duplicate calls are idempotent.
  Future<NativeRecorderStatus> startWalk() async {
    final requestRevision = ++_stateRevision;
    _commandInFlight = true;
    final hasPerm = await _service.hasLocationPermission();
    if (!hasPerm) {
      final granted = await _service.requestLocationPermission();
      if (!granted) {
        final deniedStatus = const NativeRecorderStatus(
          state: DistanceRecordingLifecycle.interrupted,
          activityType: DistanceActivityType.walk,
          interruptionReason: 'permission_revoked',
        );
        if (requestRevision == _stateRevision) {
          _stateRevision++;
          state = deniedStatus;
        }
        _commandInFlight = false;
        return state;
      }
    }
    final status = await _service.startRecording(DistanceActivityType.walk);
    _commandInFlight = false;
    if (requestRevision != _stateRevision) {
      return state;
    }
    _stateRevision++;
    state = status;
    return status;
  }

  /// Explicit user action to start recording a Run session.
  /// Native service is authoritative; duplicate calls are idempotent.
  Future<NativeRecorderStatus> startRun() async {
    final requestRevision = ++_stateRevision;
    _commandInFlight = true;
    final hasPerm = await _service.hasLocationPermission();
    if (!hasPerm) {
      final granted = await _service.requestLocationPermission();
      if (!granted) {
        final deniedStatus = const NativeRecorderStatus(
          state: DistanceRecordingLifecycle.interrupted,
          activityType: DistanceActivityType.run,
          interruptionReason: 'permission_revoked',
        );
        if (requestRevision == _stateRevision) {
          _stateRevision++;
          state = deniedStatus;
        }
        _commandInFlight = false;
        return state;
      }
    }
    final status = await _service.startRecording(DistanceActivityType.run);
    _commandInFlight = false;
    if (requestRevision != _stateRevision) {
      return state;
    }
    _stateRevision++;
    state = status;
    return status;
  }

  /// Explicit user action to finish recording session.
  /// Native service is authoritative; duplicate calls are idempotent.
  Future<NativeRecorderStatus> finish() async {
    final requestRevision = ++_stateRevision;
    _commandInFlight = true;
    final status = await _service.finishRecording();
    _commandInFlight = false;
    if (requestRevision != _stateRevision) {
      return state;
    }
    _stateRevision++;
    state = status;
    return status;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}

final distanceRecorderControllerProvider =
    StateNotifierProvider<DistanceRecorderController, NativeRecorderStatus>((
      ref,
    ) {
      return DistanceRecorderController(
        ref.watch(nativeDistanceRecorderProvider),
      );
    });
