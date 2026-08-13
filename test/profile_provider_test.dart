import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/features/profile/models/profile_data.dart';
import 'package:pulsepath/features/profile/models/profile_preferences.dart';
import 'package:pulsepath/features/profile/providers/preferences_provider.dart';
import 'package:pulsepath/features/profile/providers/profile_provider.dart';

void main() {
  test('profile state starts with mock data and accepts local updates', () {
    final notifier = ProfileNotifier();

    expect(notifier.state.displayName, 'Alex');
    expect(notifier.state.subtitle, 'Building better daily habits');

    notifier.updateProfile(
      displayName: '  Taylor  ',
      subtitle: '  Moving every day  ',
    );

    expect(notifier.state.displayName, 'Taylor');
    expect(notifier.state.subtitle, 'Moving every day');
  });

  test('preferences update local state only', () {
    final notifier = PreferencesNotifier(
      initialPreferences: const ProfilePreferences.defaults(),
    );

    notifier.setReduceMotion(true);
    notifier.setHapticFeedback(false);
    notifier.setUseMetricUnits(false);

    expect(notifier.state.reduceMotion, isTrue);
    expect(notifier.state.hapticFeedback, isFalse);
    expect(notifier.state.useMetricUnits, isFalse);
  });

  test('profile notifier can accept replacement-ready initial data', () {
    final notifier = ProfileNotifier(
      initialProfile: const ProfileData(
        displayName: 'Sam',
        subtitle: 'Steady progress',
      ),
    );

    expect(notifier.state.displayName, 'Sam');
    expect(notifier.state.subtitle, 'Steady progress');
  });
}
