import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _developmentFallbackUrl = 'http://127.0.0.1:8000';
  static const _productionBackendUrl = 'https://pulsepath-2-yg33.onrender.com';
  static const _configuredUrl = String.fromEnvironment(
    'PULSEPATH_API_BASE_URL',
  );

  static const baseUrl = _configuredUrl == ''
      ? _productionBackendUrl
      : _configuredUrl;

  static const _configuredGoogleClientId = String.fromEnvironment(
    'PULSEPATH_GOOGLE_CLIENT_ID',
  );

  static const googleClientId = _configuredGoogleClientId == ''
      ? '203075262869-97sdh39dl408s9omi6m1q2co5t6s1nvt.apps.googleusercontent.com'
      : _configuredGoogleClientId;

  static bool get hasConfiguredUrl => _configuredUrl.isNotEmpty;

  static void logDevelopmentFallbackWarning() {
    if (kDebugMode && _configuredUrl.isEmpty) {
      debugPrint(
        'PULSEPATH_API_BASE_URL was not supplied; using the '
        'development fallback $_developmentFallbackUrl.',
      );
    }
  }
}
