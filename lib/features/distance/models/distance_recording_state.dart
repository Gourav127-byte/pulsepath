enum DistanceRecordingLifecycle {
  idle,
  recording,
  finalized,
  interrupted;

  static DistanceRecordingLifecycle fromString(String? value) {
    return switch (value?.toUpperCase()) {
      'RECORDING' => DistanceRecordingLifecycle.recording,
      'FINALIZED' => DistanceRecordingLifecycle.finalized,
      'INTERRUPTED' => DistanceRecordingLifecycle.interrupted,
      _ => DistanceRecordingLifecycle.idle,
    };
  }
}

enum DistanceActivityType {
  walk,
  run;

  static DistanceActivityType? fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'walk' => DistanceActivityType.walk,
      'run' => DistanceActivityType.run,
      _ => null,
    };
  }
}

class NativeRecorderStatus {
  const NativeRecorderStatus({
    required this.state,
    this.sessionId,
    this.activityType,
    this.distanceMeters,
    this.isDistanceMissing = true,
    this.interruptionReason,
    this.startTimeUtc,
    this.acceptedPointCount = 0,
    this.segmentCount = 1,
  });

  factory NativeRecorderStatus.fromMap(Map<Object?, Object?> map) {
    final stateStr = map['state'] as String?;
    final typeStr = map['activityType'] as String?;
    final distVal = map['distanceMeters'];
    final double? distanceMeters = (distVal is num) ? distVal.toDouble() : null;
    final bool isDistanceMissing = (map['isDistanceMissing'] as bool?) ?? (distanceMeters == null);

    return NativeRecorderStatus(
      state: DistanceRecordingLifecycle.fromString(stateStr),
      sessionId: map['sessionId'] as String?,
      activityType: DistanceActivityType.fromString(typeStr),
      distanceMeters: distanceMeters,
      isDistanceMissing: isDistanceMissing,
      interruptionReason: map['interruptionReason'] as String?,
      startTimeUtc: map['startTimeUtc'] as String?,
      acceptedPointCount: (map['acceptedPointCount'] as num?)?.toInt() ?? 0,
      segmentCount: (map['segmentCount'] as num?)?.toInt() ?? 1,
    );
  }

  final DistanceRecordingLifecycle state;
  final String? sessionId;
  final DistanceActivityType? activityType;
  final double? distanceMeters;
  final bool isDistanceMissing;
  final String? interruptionReason;
  final String? startTimeUtc;
  final int acceptedPointCount;
  final int segmentCount;

  bool get isRecording => state == DistanceRecordingLifecycle.recording;
  bool get isIdle => state == DistanceRecordingLifecycle.idle;
  bool get isFinalized => state == DistanceRecordingLifecycle.finalized;
  bool get isInterrupted => state == DistanceRecordingLifecycle.interrupted;

  double? get distanceKm => distanceMeters != null ? distanceMeters! / 1000.0 : null;

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'state': state.name.toUpperCase(),
        'activityType': activityType?.name,
        'distanceMeters': distanceMeters,
        'isDistanceMissing': isDistanceMissing,
        'interruptionReason': interruptionReason,
        'startTimeUtc': startTimeUtc,
        'acceptedPointCount': acceptedPointCount,
        'segmentCount': segmentCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeRecorderStatus &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          sessionId == other.sessionId &&
          activityType == other.activityType &&
          distanceMeters == other.distanceMeters &&
          isDistanceMissing == other.isDistanceMissing &&
          interruptionReason == other.interruptionReason &&
          startTimeUtc == other.startTimeUtc &&
          acceptedPointCount == other.acceptedPointCount &&
          segmentCount == other.segmentCount;

  @override
  int get hashCode =>
      state.hashCode ^
      sessionId.hashCode ^
      activityType.hashCode ^
      distanceMeters.hashCode ^
      isDistanceMissing.hashCode ^
      interruptionReason.hashCode ^
      startTimeUtc.hashCode ^
      acceptedPointCount.hashCode ^
      segmentCount.hashCode;

  @override
  String toString() =>
      'NativeRecorderStatus(state: ${state.name}, sessionId: $sessionId, activityType: ${activityType?.name}, distanceMeters: $distanceMeters, isDistanceMissing: $isDistanceMissing, reason: $interruptionReason, segments: $segmentCount, points: $acceptedPointCount)';
}
