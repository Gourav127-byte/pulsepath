import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/veya_repository.dart';
import '../models/veya_chat_message.dart';
import '../models/veya_foundation.dart';

final veyaRepositoryProvider = Provider<VeyaRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VeyaRepository(apiClient);
});

final veyaFoundationProvider =
    FutureProvider.family<VeyaFoundationResponse, int>((ref, days) async {
  final repository = ref.watch(veyaRepositoryProvider);
  return repository.fetchFoundation(days: days);
});

class VeyaChatNotifier extends StateNotifier<List<VeyaChatMessage>> {
  final VeyaRepository _repository;

  VeyaChatNotifier(this._repository)
      : super([
          VeyaChatMessage.assistant(
            text:
                "Hello! I am VEYA, your evidence-grounded activity intelligence assistant. Ask me anything about your recorded steps, streak, consistency, or activity trends.",
          ),
        ]);

  bool _isSending = false;
  bool get isSending => _isSending;

  Future<void> sendMessage(String text, {int days = 7}) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMsg = VeyaChatMessage.user(text.trim());
    state = [...state, userMsg];
    _isSending = true;

    try {
      final res = await _repository.sendChatMessage(
        message: text.trim(),
        rangeDays: days,
      );

      final replyText = res['reply'] as String? ?? 'No response generated.';
      final status = res['status'] as String? ?? 'provider_unavailable';
      final rawObs = res['observations'] as List<dynamic>? ?? [];
      final observations = rawObs
          .map((o) => VeyaObservation.fromJson(o as Map<String, dynamic>))
          .toList();

      final assistantMsg = VeyaChatMessage.assistant(
        text: replyText,
        observations: observations,
        isGrounded: status == 'grounded',
      );

      state = [...state, assistantMsg];
    } catch (e) {
      final errorMsg = VeyaChatMessage.assistant(
        text:
            "VEYA is currently operating in offline mode. Verified PulsePath evidence remains intact.",
        isGrounded: false,
      );
      state = [...state, errorMsg];
    } finally {
      _isSending = false;
    }
  }
}

final veyaChatProvider =
    StateNotifierProvider<VeyaChatNotifier, List<VeyaChatMessage>>((ref) {
  final repository = ref.watch(veyaRepositoryProvider);
  return VeyaChatNotifier(repository);
});
