import 'package:flutter/material.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../models/today_activity.dart';

class ManualActivityEditSheet extends StatefulWidget {
  const ManualActivityEditSheet({
    required this.activity,
    required this.onSave,
    this.confirmUnchanged = false,
    super.key,
  });

  final TodayActivity activity;
  final Future<void> Function({
    double? steps,
    double? activeMinutes,
    double? calories,
    double? distance,
  })
  onSave;
  final bool confirmUnchanged;

  @override
  State<ManualActivityEditSheet> createState() =>
      _ManualActivityEditSheetState();
}

class _ManualActivityEditSheetState extends State<ManualActivityEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stepsController;
  late final TextEditingController _activeMinutesController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _distanceController;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _stepsController = TextEditingController(
      text: _displayValue(widget.activity.steps),
    );
    _activeMinutesController = TextEditingController(
      text: _displayValue(widget.activity.activeMinutes),
    );
    _caloriesController = TextEditingController(
      text: _displayValue(widget.activity.calories),
    );
    _distanceController = TextEditingController(
      text: _displayValue(widget.activity.distance),
    );
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _activeMinutesController.dispose();
    _caloriesController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PulsePathColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Edit today's activity",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Update only the metrics you logged today.',
                  style: TextStyle(color: PulsePathColors.textSecondary),
                ),
                const SizedBox(height: 22),
                _MetricField(
                  fieldKey: const Key('activity_steps_field'),
                  controller: _stepsController,
                  label: 'Steps',
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 14),
                _MetricField(
                  fieldKey: const Key('activity_active_minutes_field'),
                  controller: _activeMinutesController,
                  label: 'Active minutes',
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 14),
                _MetricField(
                  fieldKey: const Key('activity_calories_field'),
                  controller: _caloriesController,
                  label: 'Calories',
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 14),
                _MetricField(
                  fieldKey: const Key('activity_distance_field'),
                  controller: _distanceController,
                  label: 'Distance (km)',
                  textInputAction: TextInputAction.done,
                  enabled: !_isSaving,
                  onSubmitted: (_) => _submit(),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    key: const Key('activity_save_error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('save_activity_button'),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save activity'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final steps = double.parse(_stepsController.text.trim());
    final activeMinutes = double.parse(_activeMinutesController.text.trim());
    final calories = double.parse(_caloriesController.text.trim());
    final distance = double.parse(_distanceController.text.trim());

    final changedSteps = steps != widget.activity.steps ? steps : null;
    final changedActiveMinutes = activeMinutes != widget.activity.activeMinutes
        ? activeMinutes
        : null;
    final changedCalories = calories != widget.activity.calories
        ? calories
        : null;
    final changedDistance = distance != widget.activity.distance
        ? distance
        : null;

    if (!widget.confirmUnchanged &&
        changedSteps == null &&
        changedActiveMinutes == null &&
        changedCalories == null &&
        changedDistance == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(
        steps: widget.confirmUnchanged && changedSteps == null
            ? steps
            : changedSteps,
        activeMinutes: changedActiveMinutes,
        calories: changedCalories,
        distance: changedDistance,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Could not save your activity. Please try again.';
      });
    }
  }

  static String _displayValue(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}

class _MetricField extends StatelessWidget {
  const _MetricField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.textInputAction,
    required this.enabled,
    this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      decoration: InputDecoration(labelText: label),
      validator: _validate,
      onFieldSubmitted: onSubmitted,
    );
  }

  String? _validate(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return '$label is required';
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) return 'Enter a valid number';
    if (parsed < 0) return '$label cannot be negative';
    return null;
  }
}
