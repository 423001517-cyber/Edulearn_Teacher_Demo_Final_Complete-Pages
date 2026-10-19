import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';

Future<void> showChangePasswordDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _PasswordDialog());

class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _saving = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Password changed');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (e.code) {
          'wrong-password' || 'invalid-credential' => 'Your current password is incorrect.',
          'weak-password' => 'Choose a stronger password (at least 8 characters).',
          'too-many-requests' => 'Too many tries. Wait a few minutes, then try again.',
          _ => e.message ?? 'Couldn’t change the password.',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          suffixIcon: IconButton(
            tooltip: _show ? 'Hide passwords' : 'Show passwords',
            onPressed: () => setState(() => _show = !_show),
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          ),
        );
    return AppDialog(
      maxWidth: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHeader(title: 'Change password'),
            const SizedBox(height: 14),
            const FieldLabel('Current password'),
            TextFormField(
              controller: _current,
              obscureText: !_show,
              autofocus: true,
              decoration: deco('Current password'),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('New password'),
            TextFormField(
              controller: _next,
              obscureText: !_show,
              decoration: deco('At least 8 characters'),
              validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Type it again'),
            TextFormField(
              controller: _again,
              obscureText: !_show,
              decoration: deco('New password'),
              validator: (v) => v != _next.text ? 'The passwords don’t match.' : null,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Change password'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
