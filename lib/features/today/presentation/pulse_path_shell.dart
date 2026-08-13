import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'today_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class PulsePathShell extends ConsumerWidget {
  const PulsePathShell({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          TodayScreen(),
          _PlaceholderScreen(title: 'Journey', icon: Icons.route_rounded),
          GoalsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: _destinations,
        onDestinationSelected: (index) {
          ref.read(selectedTabProvider.notifier).state = index;
        },
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: PulsePathColors.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text(
              'Coming in a future phase',
              style: TextStyle(color: PulsePathColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
