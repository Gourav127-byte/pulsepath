import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/local_notification_service.dart';
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

enum HealthSyncIssue { unavailable, permission, network, read }

class HealthSyncState {
  const HealthSyncState({
    required this.status,
    this.message,
    this.lastSuccessfulSync,
    this.issue,
  });

  final HealthSyncStatus status;
  final String? message;
  final DateTime? lastSuccessfulSync;
  final HealthSyncIssue? issue;
}

class HealthSyncController extends StateNotifier<HealthSyncState> {
  HealthSyncController(this._repository, this._ref)
    : super(const HealthSyncState(status: HealthSyncStatus.idle));

  final HealthSyncRepository _repository;
  final Ref _ref;
  Future<void>? _syncInFlight;
  Future<void>? _userSyncInFlight;
  static const syncFreshnessThreshold = Duration(minutes: 5);

  Future<void> syncIfStale() async {
    if (state.status == HealthSyncStatus.syncing) return;

    final last = state.lastSuccessfulSync;
    if (last != null &&
        DateTime.now().difference(last) < syncFreshnessThreshold) {
      return; // Skip sync if fresh (< 5 mins)
    }

    try {
      await sync();
    } catch (_) {
      // Prevent unhandled plugin exceptions from affecting UI
    }
  }

  Future<void> sync({bool showNotification = false}) {
    final existing = _syncInFlight;
    if (existing != null) return existing;
    final operation = _runSync(showNotification: showNotification);
    _syncInFlight = operation;
    return operation.whenComplete(() => _syncInFlight = null);
  }

  Future<void> userInitiatedSync() {
    final existing = _userSyncInFlight;
    if (existing != null) return existing;
    final operation = _runUserInitiatedSync();
    _userSyncInFlight = operation;
    return operation.whenComplete(() => _userSyncInFlight = null);
  }

  Future<void> _runUserInitiatedSync() async {
    await _ref.read(notificationServiceProvider).requestPermissions();
    if (state.status == HealthSyncStatus.unauthorized ||
        state.issue == HealthSyncIssue.unavailable ||
        state.issue == HealthSyncIssue.permission) {
      final granted = await requestPermissions();
      if (!granted) return;
    }
    await sync(showNotification: true);
  }

  Future<void> _runSync({required bool showNotification}) async {
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
      final outcome = await _repository.sync();
      if (outcome == HealthSyncOutcome.unavailable) {
        state = HealthSyncState(
          status: HealthSyncStatus.error,
          message: 'Health Connect is not available on this device.',
          lastSuccessfulSync: state.lastSuccessfulSync,
          issue: HealthSyncIssue.unavailable,
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
      if (showNotification) {
        try {
          await _ref
              .read(notificationServiceProvider)
              .showSyncStatus(
                success: true,
                syncedCount: outcome == HealthSyncOutcome.updated ? 1 : 0,
              );
        } on Object catch (error) {
          if (kDebugMode) {
            debugPrint(
              '[NOTIFICATION] health_sync_notice_failed '
              'type=${error.runtimeType}',
            );
          }
        }
      }
    } on HealthConnectPermissionException {
      state = HealthSyncState(
        status: HealthSyncStatus.unauthorized,
        message: 'Health Connect permissions were not granted.',
        lastSuccessfulSync: state.lastSuccessfulSync,
        issue: HealthSyncIssue.permission,
      );
    } on NetworkException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[HEALTH_SYNC] stage=backend_failed status=${error.statusCode}',
        );
      }
      state = HealthSyncState(
        status: HealthSyncStatus.error,
        message:
            'Could not sync with PulsePath. Check your connection and retry.',
        lastSuccessfulSync: state.lastSuccessfulSync,
        issue: HealthSyncIssue.network,
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[HEALTH_SYNC] stage=health_read_failed type=${error.runtimeType}',
        );
      }
      state = HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Health Connect could not be read. Please retry.',
        lastSuccessfulSync: state.lastSuccessfulSync,
        issue: HealthSyncIssue.read,
      );
    }
  }

  Future<bool> requestPermissions() async {
    if (state.status == HealthSyncStatus.syncing) return false;
    state = HealthSyncState(
      status: HealthSyncStatus.syncing,
      lastSuccessfulSync: state.lastSuccessfulSync,
    );
    try {
      final granted = await _ref
          .read(healthConnectServiceProvider)
          .requestPermissions();
      if (!granted) {
        state = HealthSyncState(
          status: HealthSyncStatus.unauthorized,
          message: 'Health Connect permissions were not granted.',
          lastSuccessfulSync: state.lastSuccessfulSync,
          issue: HealthSyncIssue.permission,
        );
      } else {
        state = HealthSyncState(
          status: HealthSyncStatus.idle,
          lastSuccessfulSync: state.lastSuccessfulSync,
        );
      }
      return granted;
    } on Object {
      state = HealthSyncState(
        status: HealthSyncStatus.error,
        message: 'Could not request Health Connect permissions.',
        lastSuccessfulSync: state.lastSuccessfulSync,
        issue: HealthSyncIssue.permission,
      );
      return false;
    }
  }
}

final healthSyncControllerProvider =
    StateNotifierProvider<HealthSyncController, HealthSyncState>((ref) {
      return HealthSyncController(ref.watch(healthSyncRepositoryProvider), ref);
    });
