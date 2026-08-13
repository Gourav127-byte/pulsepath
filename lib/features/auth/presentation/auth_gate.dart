import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../today/presentation/pulse_path_shell.dart';
import '../providers/auth_provider.dart';
import 'auth_screens.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(unauthorizedProvider, (previous, next) {
      if (next) {
        ref.read(authControllerProvider.notifier).logout();
        ref.read(unauthorizedProvider.notifier).state = false;
      }
    });

    final auth = ref.watch(authControllerProvider);
    return switch (auth.status) {
      AuthStatus.checking => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AuthStatus.authenticated => const PulsePathShell(),
      _ => const AuthFlow(),
    };
  }
}
