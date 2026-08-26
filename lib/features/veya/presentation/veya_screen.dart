import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/veya_providers.dart';
import '../widgets/veya_badge.dart';
import '../widgets/veya_chat_sheet.dart';
import '../widgets/veya_insights_card.dart';
import '../widgets/veya_integrity_card.dart';

final veyaRangeProvider = StateProvider<int>((ref) => 7);

class VeyaScreen extends ConsumerWidget {
  const VeyaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(veyaRangeProvider);
    final foundationAsync = ref.watch(veyaFoundationProvider(days));

    return Scaffold(
      backgroundColor: const Color(0xFF040711),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _VeyaHeader(
              days: days,
              onRangeSelected: (value) {
                ref.read(veyaRangeProvider.notifier).state = value;
              },
            ),
            Expanded(
              child: foundationAsync.when(
                data: (data) => RefreshIndicator(
                  color: const Color(0xFF8A5BFF),
                  backgroundColor: const Color(0xFF0B1021),
                  onRefresh: () async {
                    ref.invalidate(veyaFoundationProvider(days));
                    await ref.read(veyaFoundationProvider(days).future);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          children: [
                            VeyaIntegrityCard(
                              integrity: data.evidence.integrity,
                              rangeDays: days,
                            ),
                            const SizedBox(height: 16),
                            VeyaInsightsCard(response: data.response),
                            const SizedBox(height: 24),
                            _AskVeyaButton(
                              onPressed: () => VeyaChatSheet.show(context),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8A5BFF)),
                ),
                error: (error, stack) => _VeyaErrorState(
                  onRetry: () => ref.invalidate(veyaFoundationProvider(days)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VeyaHeader extends StatelessWidget {
  final int days;
  final ValueChanged<int> onRangeSelected;

  const _VeyaHeader({required this.days, required this.onRangeSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
      child: Row(
        children: [
          const VeyaBadge(size: 48),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VEYA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Evidence in. Intelligence out.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF8E9BBD), fontSize: 12.5),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            initialValue: days,
            tooltip: 'Select evidence range',
            onSelected: onRangeSelected,
            color: const Color(0xFF0D1429),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 7, child: Text('7-Day Range')),
              PopupMenuItem(value: 30, child: Text('30-Day Range')),
            ],
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF090E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1E2846),
                ),
              ),
              child: const Icon(Icons.tune_rounded, color: Color(0xFFC69CFF), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _AskVeyaButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AskVeyaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF321A77), Color(0xFF5F36F4), Color(0xFF0BBAD7)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F36F4).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: Material(
          color: const Color(0xFF060914),
          borderRadius: BorderRadius.circular(27),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(27),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Ask VEYA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .3,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VeyaErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _VeyaErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const VeyaBadge(size: 72),
            const SizedBox(height: 20),
            const Text(
              'VEYA couldn’t connect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your PulsePath data is safe. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFAAB4D1),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
