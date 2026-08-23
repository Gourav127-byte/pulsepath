import 'veya_foundation.dart';

enum VeyaSender { user, assistant }

class VeyaChatMessage {
  final String id;
  final VeyaSender sender;
  final String text;
  final DateTime timestamp;
  final List<VeyaObservation> observations;
  final bool isGrounded;

  const VeyaChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.observations = const [],
    this.isGrounded = true,
  });

  factory VeyaChatMessage.user(String message) {
    return VeyaChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: VeyaSender.user,
      text: message,
      timestamp: DateTime.now(),
    );
  }

  factory VeyaChatMessage.assistant({
    required String text,
    List<VeyaObservation> observations = const [],
    bool isGrounded = true,
  }) {
    return VeyaChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: VeyaSender.assistant,
      text: text,
      timestamp: DateTime.now(),
      observations: observations,
      isGrounded: isGrounded,
    );
  }
}
