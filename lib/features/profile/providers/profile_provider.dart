import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_data.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileData>(
  (ref) => ProfileNotifier(),
);

class ProfileNotifier extends StateNotifier<ProfileData> {
  ProfileNotifier({ProfileData? initialProfile})
    : super(
        initialProfile ??
            const ProfileData(
              displayName: 'Alex',
              subtitle: 'Building better daily habits',
            ),
      );

  void updateProfile({required String displayName, required String subtitle}) {
    state = ProfileData(
      displayName: displayName.trim(),
      subtitle: subtitle.trim(),
    );
  }
}
