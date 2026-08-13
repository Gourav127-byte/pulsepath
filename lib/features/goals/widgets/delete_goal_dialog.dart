import 'package:flutter/material.dart';

import '../models/backend_goal.dart';

class DeleteGoalDialog extends StatefulWidget {
  const DeleteGoalDialog({
    required this.goal,
    required this.onDelete,
    super.key,
  });

  final BackendGoal goal;
  final Future<void> Function() onDelete;

  @override
  State<DeleteGoalDialog> createState() => _DeleteGoalDialogState();
}

class _DeleteGoalDialogState extends State<DeleteGoalDialog> {
  bool _isDeleting = false;
  String? _deleteError;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete ${widget.goal.displayLabel} goal?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This daily goal target will be removed.'),
          if (_deleteError != null) ...[
            const SizedBox(height: 12),
            Text(
              _deleteError!,
              key: const Key('goal_delete_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancel_delete_goal_button'),
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_delete_goal_button'),
          onPressed: _isDeleting ? null : _delete,
          child: _isDeleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
      _deleteError = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _deleteError = 'Could not delete this goal. Please try again.';
      });
    }
  }
}
