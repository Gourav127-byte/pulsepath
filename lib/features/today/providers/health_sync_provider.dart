import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../journey/providers/activity_history_provider.dart';
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
  const HealthSyncState({required this.status, this.message, this.lastSuccessfulSync});

  final HealthSyncStatus status;
  final String? message;
  final DateTime? lastSuccessfulSync;
}

class HealthSyncController extends StateNotifier<HealthSyncState> {
  HealthSyncController(this._repository, this._ref)
    : super(const HealthSyncState(status: HealthSyncStatus.idle));

  final HealthSyncRepository _repository;
  final Ref _ref;
  static const syncFreshnessThreshold = Duration(minutes: 5);

  Future<void> syncIfStale() async {
    if (state.status == HealthSyncStatus.syncing) return;

    final last = state.lastSuccessfulSync;
    if (last != null && DateTime.now().difference(last) < syncFreshnessThreshold) {
      return; // Skip sync if fresh (< 5 mins)
    }

    try {
      await sync();
    } catch (_) {
      // Prevent unhandled plugin exceptions from affecting UI
    }
  }

  Future<void> sync() async {
    if (state.status == HealthSyncStatus.syncing) return;

    if (defaultTargetPlatform != TargetPlatform.android) {
      state = HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Health Connect is only supported on Android.',
        lastSuccessfulSync: state.lastSuccessfulSync,
      );
      return;
    }

    state = HealthSyncState(
      status: HealthSyncStatus.syncing,
      lastSuccessfulSync: state.lastSuccessfulSync,
    );

    try {
      final service = _ref.read(healthConnectServiceProvider);
      if (!await service.isAvailable()) {
        state = HealthSyncState(
          status: HealthSyncStatus.error,
          message: 'Health Connect is not available on this device.',
          lastSuccessfulSync: state.lastSuccessfulSync,
        );
        return;
      }

      final outcome = await _repository.sync();
      if (outcome == HealthSyncOutcome.unavailable) {
        state = HealthSyncState(
          status: HealthSyncStatus.error,
          message: 'Health Connect is not available on this device.',
          lastSuccessfulSync: state.lastSuccessfulSync,
        );
        return;
      }

      // ONLY UPDATE lastSuccessfulSync on actual successful sync
      state = HealthSyncState(
        status: HealthSyncStatus.success,
        message: outcome == HealthSyncOutcome.noData
            ? 'No Health Connect records found for today.'
            : null,
        lastSuccessfulSync: DateTime.now(),
      );

      // Refresh the Today activity provider to show new data
      _ref.invalidate(todayActivityProvider);
      _ref.invalidate(activityStreakProvider);
      _ref.invalidate(activityEngagementProvider);
      if (outcome == HealthSyncOutcome.updated) {
        _ref.invalidate(activityHistoryProvider(7));
        _ref.invalidate(activityHistoryProvider(30));
      }
    } on HealthConnectPermissionException {
      state = HealthSyncState(
        status: HealthSyncStatus.unauthorized,
        message: 'Health Connect permissions were not granted.',
        lastSuccessfulSync: state.lastSuccessfulSync,
      );
    } on Object {
      state = HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Failed to sync health data.',
        lastSuccessfulSync: state.lastSuccessfulSync,
      );
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final granted = await _ref
          .read(healthConnectServiceProvider)
          .requestPermissions();
      if (!granted) {
        state = HealthSyncState(
          status: HealthSyncStatus.unauthorized,
          message: 'Health Connect permissions were not granted.',
          lastSuccessfulSync: state.lastSuccessfulSync,
        );
      }
      return granted;
    } on Object {
      state = HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Could not request Health Connect permissions.',
        lastSuccessfulSync: state.lastSuccessfulSync,
      );
      return false;
    }
  }
}

final healthSyncControllerProvider =
    StateNotifierProvider<HealthSyncController, HealthSyncState>((ref) {
      return HealthSyncController(ref.watch(healthSyncRepositoryProvider), ref);
    });
