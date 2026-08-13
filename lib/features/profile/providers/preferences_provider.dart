import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_preferences.dart';

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, ProfilePreferences>(
      (ref) => PreferencesNotifier(),
    );

class PreferencesNotifier extends StateNotifier<ProfilePreferences> {
  PreferencesNotifier({ProfilePreferences? initialPreferences})
    : super(initialPreferences ?? const ProfilePreferences.defaults());

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
  }

  void setHapticFeedback(bool value) {
    state = state.copyWith(hapticFeedback: value);
  }

  void setUseMetricUnits(bool value) {
    state = state.copyWith(useMetricUnits: value);
  }
}
