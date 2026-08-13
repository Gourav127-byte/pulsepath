import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'core/network/api_config.dart';
import 'core/network/api_client.dart';
import 'core/network/health_check_service.dart';
import 'core/theme/pulse_path_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/startup/presentation/startup_screen.dart';
import 'features/startup/services/startup_sound.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    unawaited(_logBackendHealth());
  }
  runApp(const ProviderScope(child: PulsePathApp()));
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
