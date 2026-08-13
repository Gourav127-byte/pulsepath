import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../today/providers/today_activity_provider.dart';
import '../data/profile_repository.dart';
import '../models/backend_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(temporaryDemoCacheProvider),
  );
});

final backendProfileProvider = FutureProvider.autoDispose<BackendProfile>((
  ref,
) {
  return ref.watch(profileRepositoryProvider).fetchProfile();
});
