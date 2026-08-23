import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/veya_providers.dart';
import '../widgets/veya_badge.dart';
import '../widgets/veya_chat_sheet.dart';
import '../widgets/veya_insights_card.dart';
import '../widgets/veya_integrity_card.dart';
import '../widgets/veya_suggestions_card.dart';

final veyaRangeProvider = StateProvider<int>((ref) => 7);

class VeyaScreen extends ConsumerWidget {
  const VeyaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(veyaRangeProvider);
    final foundationAsync = ref.watch(veyaFoundationProvider(days));

    return Scaffold(
      backgroundColor: const Color(0xFF0C091D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF120B2E),
        elevation: 0,
        title: const Row(
          children: [
            VeyaBadge(size: 28),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VEYA INTELLIGENCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Evidence in. Intelligence out.',
                  style: TextStyle(
                    color: Color(0xFF00F2FE),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            initialValue: days,
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            onSelected: (val) {
              ref.read(veyaRangeProvider.notifier).state = val;
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 7, child: Text('7-Day Range')),
              PopupMenuItem(value: 30, child: Text('30-Day Range')),
            ],
          ),
        ],
      ),
      body: foundationAsync.when(
        data: (data) {
          final evidence = data.evidence;
          final response = data.response;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(veyaFoundationProvider(days));
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VeyaIntegrityCard(integrity: evidence.integrity),
                  VeyaInsightsCard(
                    response: response,
                    onAskVeya: () => VeyaChatSheet.show(context),
                  ),
                  VeyaSuggestionsCard(observations: response.observations),
                  const SizedBox(height: 80), // padding for FAB
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00F2FE)),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Could not load VEYA Intelligence',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(veyaFoundationProvider(days)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => VeyaChatSheet.show(context),
        backgroundColor: const Color(0xFF00F2FE),
        icon: const Icon(Icons.chat_bubble_rounded, color: Colors.black),
        label: const Text(
          'Ask VEYA',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
