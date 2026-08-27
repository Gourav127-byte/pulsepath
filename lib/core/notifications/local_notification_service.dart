import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class NotificationService {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<bool> areNotificationsEnabled();
  Future<void> showGoalReminder({
    required double targetSteps,
    required double currentSteps,
    required bool isRecorded,
  });
  Future<void> showEveningSummary({
    required double steps,
    required double activeMinutes,
    required bool isRecorded,
  });
  Future<void> showSyncStatus({
    required bool success,
    required int syncedCount,
  });
  Future<void> showVeyaNotice({required String title, required String body});
  Future<void> showSecurityAlert({required String title, required String body});
}

final class LocalNotificationService implements NotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initialization;
  final Map<int, DateTime> _lastShownTimestamps = {};

  static const _reminderChannelId = 'pulsepath_reminders';
  static const _syncChannelId = 'pulsepath_sync';
  static const _insightsChannelId = 'pulsepath_insights';
  static const _securityChannelId = 'pulsepath_security';

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initialization;
    if (pending != null) return pending;
    final operation = _initialize();
    _initialization = operation;
    return operation.whenComplete(() => _initialization = null);
  }

  Future<void> _initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint(
          '[NOTIFICATION] Tapped notification payload: ${response.payload}',
        );
      },
    );

    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      await initialize();
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted =
          await androidImplementation?.requestNotificationsPermission() ??
          false;

      final darwinImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted =
          await darwinImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;

      return androidGranted || iosGranted;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[NOTIFICATION] permission_request_failed type=${error.runtimeType}',
        );
      }
      return false;
    }
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    try {
      await initialize();
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidEnabled =
          await androidImplementation?.areNotificationsEnabled() ?? true;
      return androidEnabled;
    } catch (_) {
      return true;
    }
  }

  bool _shouldThrottle(
    int notificationId, {
    Duration cooldown = const Duration(hours: 1),
  }) {
    final lastShown = _lastShownTimestamps[notificationId];
    if (lastShown != null && DateTime.now().difference(lastShown) < cooldown) {
      return true;
    }
    _lastShownTimestamps[notificationId] = DateTime.now();
    return false;
  }

  @override
  Future<void> showGoalReminder({
    required double targetSteps,
    required double currentSteps,
    required bool isRecorded,
  }) async {
    // Missing Metric Guard: Never issue estimated reminders on unrecorded days
    if (!isRecorded) {
      debugPrint(
        '[NOTIFICATION] Skipped goal reminder: Day is unrecorded (Missing != Zero invariant).',
      );
      return;
    }

    if (currentSteps >= targetSteps) return;

    final remaining = (targetSteps - currentSteps).round();
    const id = 1001;

    if (_shouldThrottle(id)) return;

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      'Goal & Activity Reminders',
      channelDescription: 'Reminders for daily activity goals and progress.',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      id,
      'Keep Going! 🏃',
      'You are $remaining steps away from your daily goal of ${targetSteps.round()} steps.',
      const NotificationDetails(android: androidDetails),
    );
  }

  @override
  Future<void> showEveningSummary({
    required double steps,
    required double activeMinutes,
    required bool isRecorded,
  }) async {
    if (!isRecorded) {
      debugPrint(
        '[NOTIFICATION] Skipped evening summary: No recorded activity today.',
      );
      return;
    }

    const id = 1002;
    if (_shouldThrottle(id)) return;

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      'Evening Summary',
      channelDescription: 'Daily evening activity summaries.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _plugin.show(
      id,
      'Evening Progress Summary 🌙',
      'Great effort today! You logged ${steps.round()} steps and ${activeMinutes.round()} active minutes.',
      const NotificationDetails(android: androidDetails),
    );
  }

  @override
  Future<void> showSyncStatus({
    required bool success,
    required int syncedCount,
  }) async {
    const id = 2001;
    if (_shouldThrottle(id, cooldown: const Duration(minutes: 5))) return;

    const androidDetails = AndroidNotificationDetails(
      _syncChannelId,
      'Health Connect Sync',
      channelDescription: 'Status notices for Health Connect synchronization.',
      importance: Importance.low,
      priority: Priority.low,
    );

    final title = success ? 'Health Sync Complete ✅' : 'Health Sync Notice ⚠️';
    final body = success
        ? syncedCount == 0
              ? 'No new Health Connect records were found for today.'
              : 'Your latest Health Connect activity was synced to PulsePath.'
        : 'Health Connect sync could not finish. Open PulsePath to retry.';

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  @override
  Future<void> showVeyaNotice({
    required String title,
    required String body,
  }) async {
    const id = 3001;
    if (_shouldThrottle(id)) return;

    const androidDetails = AndroidNotificationDetails(
      _insightsChannelId,
      'VEYA AI Insights',
      channelDescription: 'Verified AI activity insights and trends.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  @override
  Future<void> showSecurityAlert({
    required String title,
    required String body,
  }) async {
    const id = 4001;
    // Security alerts are never throttled

    const androidDetails = AndroidNotificationDetails(
      _securityChannelId,
      'Security & Account Alerts',
      channelDescription: 'Important security and authentication alerts.',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService.instance;
});
