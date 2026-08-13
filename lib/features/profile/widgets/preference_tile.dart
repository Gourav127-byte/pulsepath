import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';

class PreferenceTile extends StatelessWidget {
  const PreferenceTile({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.controlKey,
    this.disabledCaption,
    super.key,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key controlKey;
  final String? disabledCaption;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;

    return Semantics(
      label: title,
      hint: isDisabled ? disabledCaption : description,
      enabled: !isDisabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDisabled
                            ? PulsePathColors.textSecondary
                            : PulsePathColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        color: PulsePathColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (disabledCaption != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        disabledCaption!,
                        style: const TextStyle(
                          color: PulsePathColors.violet,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Switch(key: controlKey, value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
