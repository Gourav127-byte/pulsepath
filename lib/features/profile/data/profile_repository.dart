import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../models/backend_profile.dart';

class ProfileRepository {
  const ProfileRepository(this._apiClient, [this._cache]);

  final ApiClient _apiClient;
  final TemporaryDemoCache? _cache;

  Future<BackendProfile> fetchProfile() async {
    try {
      final response = await _apiClient.getJson('/profile');
      final profile = BackendProfile.fromJson(response);
      await _cache?.saveProfile(response);
      return profile;
    } on NetworkException {
      final cached = await _cache?.loadProfile();
      if (cached != null) return BackendProfile.fromJson(cached);
      rethrow;
    }
  }

  Future<BackendProfile> updateProfile(Map<String, Object?> fields) async {
    final response = await _apiClient.patchJson('/profile', fields);
    return BackendProfile.fromJson(response);
  }
}
