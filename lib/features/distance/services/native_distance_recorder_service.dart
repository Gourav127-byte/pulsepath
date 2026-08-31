import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/distance_recording_state.dart';

abstract interface class NativeDistanceRecorder {
  Future<NativeRecorderStatus> startRecording(DistanceActivityType activityType);
  Future<NativeRecorderStatus> finishRecording();
  Future<NativeRecorderStatus> getRecorderState();
  Future<bool> hasLocationPermission();
  Future<bool> requestLocationPermission();
  Stream<NativeRecorderStatus> observeStateChanges();
}

class MethodChannelDistanceRecorder implements NativeDistanceRecorder {
  MethodChannelDistanceRecorder({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel('com.pulsepath.app/distance_recorder'),
        _eventChannel = eventChannel ??
            const EventChannel('com.pulsepath.app/distance_recorder_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  Stream<NativeRecorderStatus>? _stateStream;

  @override
  Future<NativeRecorderStatus> startRecording(DistanceActivityType activityType) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const NativeRecorderStatus(
        state: DistanceRecordingLifecycle.interrupted,
      );
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'startRecording',
        {'activityType': activityType.name},
      );
      if (result != null) {
        return NativeRecorderStatus.fromMap(result);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[DISTANCE_RECORDER] startRecording failed: ${e.message}');
      }
    }
    return NativeRecorderStatus(
      state: DistanceRecordingLifecycle.interrupted,
      activityType: activityType,
    );
  }

  @override
  Future<NativeRecorderStatus> finishRecording() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const NativeRecorderStatus(state: DistanceRecordingLifecycle.finalized);
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'finishRecording',
      );
      if (result != null) {
        return NativeRecorderStatus.fromMap(result);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[DISTANCE_RECORDER] finishRecording failed: ${e.message}');
      }
    }
    return const NativeRecorderStatus(state: DistanceRecordingLifecycle.finalized);
  }

  @override
  Future<NativeRecorderStatus> getRecorderState() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const NativeRecorderStatus(state: DistanceRecordingLifecycle.idle);
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getRecorderState',
      );
      if (result != null) {
        return NativeRecorderStatus.fromMap(result);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[DISTANCE_RECORDER] getRecorderState failed: ${e.message}');
      }
    }
    return const NativeRecorderStatus(state: DistanceRecordingLifecycle.idle);
  }

  @override
  Future<bool> hasLocationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasLocationPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestLocationPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<NativeRecorderStatus> observeStateChanges() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Stream.empty();
    }
    _stateStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          if (event is Map<Object?, Object?>) {
            return NativeRecorderStatus.fromMap(event);
          }
          return const NativeRecorderStatus(state: DistanceRecordingLifecycle.idle);
        })
        .handleError((Object error) {
          if (kDebugMode) {
            debugPrint('[DISTANCE_RECORDER] Stream error: $error');
          }
          return const NativeRecorderStatus(state: DistanceRecordingLifecycle.interrupted);
        });
    return _stateStream!;
  }
}
