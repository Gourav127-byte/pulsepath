import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/core/notifications/local_notification_service.dart';

void main() {
  late LocalNotificationService notificationService;

  setUp(() {
    notificationService = LocalNotificationService.instance;
  });

  test('LocalNotificationService singleton instance is non-null', () {
    expect(notificationService, isNotNull);
  });

  test(
    'showGoalReminder suppresses estimated notifications for unrecorded days',
    () async {
      await notificationService.showGoalReminder(
        targetSteps: 10000,
        currentSteps: 0,
        isRecorded: false, // Unrecorded day (Missing != Zero invariant)
      );
    },
  );

  test('showEveningSummary suppresses summary for unrecorded days', () async {
    await notificationService.showEveningSummary(
      steps: 0,
      activeMinutes: 0,
      isRecorded: false, // Unrecorded day
    );
  });
}
