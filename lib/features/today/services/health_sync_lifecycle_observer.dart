import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/health_sync_provider.dart';

class HealthSyncLifecycleObserver with WidgetsBindingObserver {
  HealthSyncLifecycleObserver(this._ref);

  final WidgetRef _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ref.read(healthSyncControllerProvider.notifier).syncIfStale();
    }
  }
}
