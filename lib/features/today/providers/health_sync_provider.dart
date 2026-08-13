import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/health_sync_repository.dart';
import '../services/health_connect_service.dart';
import 'today_activity_provider.dart';

final healthConnectServiceProvider = Provider<HealthConnectService>((ref) {
  return AndroidHealthConnectService();
});

final healthSyncRepositoryProvider = Provider<HealthSyncRepository>((ref) {
  return HealthSyncRepository(
    ref.watch(healthConnectServiceProvider),
    ref.watch(todayActivityRepositoryProvider),
  );
});

enum HealthSyncStatus { idle, syncing, success, error, unauthorized }

class HealthSyncState {
  const HealthSyncState({required this.status, this.message, this.lastSync});

  final HealthSyncStatus status;
  final String? message;
  final DateTime? lastSync;
}

class HealthSyncController extends StateNotifier<HealthSyncState> {
  HealthSyncController(this._repository, this._ref)
    : super(const HealthSyncState(status: HealthSyncStatus.idle));

  final HealthSyncRepository _repository;
  final Ref _ref;

  Future<void> sync() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      state = const HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Health Connect is only supported on Android.',
      );
      return;
    }

    state = HealthSyncState(
      status: HealthSyncStatus.syncing,
      lastSync: state.lastSync,
    );

    try {
      final service = _ref.read(healthConnectServiceProvider);
      if (!await service.isAvailable()) {
        state = const HealthSyncState(
          status: HealthSyncStatus.error,
          message: 'Health Connect is not available on this device.',
        );
        return;
      }

      final outcome = await _repository.sync();
      if (outcome == HealthSyncOutcome.unavailable) {
        state = const HealthSyncState(
          status: HealthSyncStatus.error,
          message: 'Health Connect is not available on this device.',
        );
        return;
      }
      state = HealthSyncState(
        status: HealthSyncStatus.success,
        message: outcome == HealthSyncOutcome.noData
            ? 'No Health Connect records found for today.'
            : null,
        lastSync: DateTime.now(),
      );

      // Refresh the Today activity provider to show new data
      _ref.invalidate(todayActivityProvider);
    } on HealthConnectPermissionException {
      state = HealthSyncState(
        status: HealthSyncStatus.unauthorized,
        message: 'Health Connect permissions were not granted.',
        lastSync: state.lastSync,
      );
    } on Object {
      state = HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Failed to sync health data.',
        lastSync: state.lastSync,
      );
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final granted = await _ref
          .read(healthConnectServiceProvider)
          .requestPermissions();
      if (!granted) {
        state = const HealthSyncState(
          status: HealthSyncStatus.unauthorized,
          message: 'Health Connect permissions were not granted.',
        );
      }
      return granted;
    } on Object {
      state = const HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Could not request Health Connect permissions.',
      );
      return false;
    }
  }
}

final healthSyncControllerProvider =
    StateNotifierProvider<HealthSyncController, HealthSyncState>((ref) {
      return HealthSyncController(ref.watch(healthSyncRepositoryProvider), ref);
    });
