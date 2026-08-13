import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _developmentFallbackUrl = 'http://192.168.29.78:8000';
  static const _configuredUrl = String.fromEnvironment(
    'PULSEPATH_API_BASE_URL',
  );

  static const baseUrl = _configuredUrl == ''
      ? _developmentFallbackUrl
      : _configuredUrl;

  static void logDevelopmentFallbackWarning() {
    if (kDebugMode && _configuredUrl.isEmpty) {
      debugPrint(
        'PULSEPATH_API_BASE_URL was not supplied; using the '
        'development fallback $_developmentFallbackUrl.',
      );
    }
  }
}
