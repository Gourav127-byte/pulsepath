import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../models/backend_profile.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    required this.profile,
    required this.onSave,
    super.key,
  });

  final BackendProfile profile;
  final Future<void> Function(Map<String, Object?> fields) onSave;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _subtitleController;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _subtitleController = TextEditingController(text: widget.profile.subtitle);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
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
                  'Edit profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Keep your profile simple and personal.',
                  style: TextStyle(color: PulsePathColors.textSecondary),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  key: const Key('profile_name_field'),
                  controller: _nameController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 40,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: _validateName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('profile_subtitle_field'),
                  controller: _subtitleController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  maxLength: 80,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle or status',
                    hintText: 'Optional',
                  ),
                  validator: _validateSubtitle,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    key: const Key('profile_save_error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('save_profile_button'),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateName(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Display name is required';
    if (value.length > 40) return 'Display name must be 40 characters or less';
    return null;
  }

  String? _validateSubtitle(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.length > 80) return 'Subtitle must be 80 characters or less';
    return null;
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final displayName = _nameController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final fields = <String, Object?>{
      if (displayName != widget.profile.displayName)
        'display_name': displayName,
      if (subtitle != widget.profile.subtitle) 'subtitle': subtitle,
    };
    if (fields.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(fields);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Could not save your profile. Please try again.';
      });
    }
  }
}
