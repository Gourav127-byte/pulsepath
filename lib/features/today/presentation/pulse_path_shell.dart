import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/presentation/goals_screen.dart';
import '../../journey/presentation/journey_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../veya/presentation/veya_screen.dart';
import 'today_screen.dart';
import '../providers/today_activity_provider.dart';
import '../../goals/providers/backend_goals_provider.dart';
import '../../journey/providers/activity_history_provider.dart';
import '../../veya/providers/veya_providers.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);
final midnightTimerFactoryProvider =
    Provider<Timer Function(Duration, void Function())>(
      (ref) =>
          (duration, callback) => Timer(duration, callback),
    );

class PulsePathShell extends ConsumerStatefulWidget {
  const PulsePathShell({super.key});

  @override
  ConsumerState<PulsePathShell> createState() => _PulsePathShellState();
}

class _PulsePathShellState extends ConsumerState<PulsePathShell>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  late DateTime _observedDay;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today_rounded),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route_rounded),
      label: 'Journey',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome_rounded),
      label: 'VEYA',
    ),
    NavigationDestination(
      icon: Icon(Icons.flag_outlined),
      selectedIcon: Icon(Icons.flag_rounded),
      label: 'Goals',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedDay = _dateOnly(ref.read(currentDateProvider)());
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAfterDateChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          TodayScreen(),
          JourneyScreen(),
          VeyaScreen(),
          GoalsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: _destinations,
        onDestinationSelected: (index) {
          final wasSelected = ref.read(selectedTabProvider);
          ref.read(selectedTabProvider.notifier).state = index;
          if (index == 0 && wasSelected != 0) {
            _refreshTodayData();
          }
        },
      ),
    );
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = ref.read(currentDateProvider)();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = ref.read(midnightTimerFactoryProvider)(
      nextDay.difference(now),
      _refreshAfterDateChange,
    );
  }

  void _refreshAfterDateChange() {
    final currentDay = _dateOnly(ref.read(currentDateProvider)());
    if (currentDay != _observedDay) {
      _observedDay = currentDay;
      _refreshTodayData();
    }
    _scheduleMidnightRefresh();
  }

  void _refreshTodayData() {
    ref.invalidate(todayActivityProvider);
    ref.invalidate(activityStreakProvider);
    ref.invalidate(activityEngagementProvider);
    ref.invalidate(dailyScoreExplanationProvider);
    ref.invalidate(backendGoalsProvider);
    ref.invalidate(activityHistoryProvider(7));
    ref.invalidate(activityHistoryProvider(30));
    ref.invalidate(veyaFoundationProvider(7));
    ref.invalidate(veyaFoundationProvider(30));
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
