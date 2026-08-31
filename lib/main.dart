import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'core/network/api_config.dart';
import 'core/network/api_client.dart';
import 'core/network/health_check_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/theme/pulse_path_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/startup/presentation/startup_screen.dart';
import 'features/startup/services/startup_sound.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[UNCAUGHT_ASYNC_ERROR] error=$error\n$stack');
    return true;
  };

  runApp(const ProviderScope(child: PulsePathApp()));
  unawaited(_initializeNotifications());
  if (kDebugMode) {
    unawaited(_logBackendHealth());
  }
}

Future<void> _initializeNotifications() async {
  try {
    await LocalNotificationService.instance.initialize();
  } on Object catch (error) {
    if (kDebugMode) {
      debugPrint(
        '[NOTIFICATION] initialization_failed type=${error.runtimeType}',
      );
    }
  }
}

Future<void> _logBackendHealth() async {
  ApiConfig.logDevelopmentFallbackWarning();

  final httpClient = http.Client();
  final healthService = HealthCheckService(
    ApiClient(baseUrl: ApiConfig.baseUrl, client: httpClient),
  );

  try {
    await healthService.checkHealth();
    debugPrint('PulsePath backend health check succeeded.');
  } on NetworkException catch (error) {
    debugPrint('PulsePath backend health check failed: ${error.message}');
  } finally {
    httpClient.close();
  }
}

class PulsePathApp extends StatelessWidget {
  const PulsePathApp({
    this.showStartup = true,
    this.startupSoundPlayer,
    super.key,
  });

  final bool showStartup;
  final StartupSoundPlayer? startupSoundPlayer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PulsePath',
      debugShowCheckedModeBanner: false,
      theme: PulsePathTheme.dark,
      home: showStartup
          ? PulsePathStartupScreen(
              soundPlayer: startupSoundPlayer,
              destination: const AuthGate(),
            )
          : const AuthGate(),
    );
  }
}
