import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';

/// `/login` — administrators only (no self sign-up; admins are added in
/// Settings → Administrators or by tools/seed).
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminSessionProvider).signIn(_email.text, _password.text);
      // The router redirects once the admin role is confirmed.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'user-not-found' || 'wrong-password' || 'invalid-credential' =>
              'Email or password is incorrect.',
            'user-disabled' => 'This account has been disabled.',
            'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
            'network-request-failed' => 'No connection. Check your internet and try again.',
            _ => e.message ?? 'Sign-in failed (${e.code}).',
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter your email first, then tap “Forgot password?”.');
      return;
    }
    try {
      await ref.read(adminSessionProvider).sendPasswordReset(_email.text);
      showToast('Password reset link sent to ${_email.text.trim()}');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Administrator sign in', style: AppText.greeting),
                const SizedBox(height: 6),
                Text('Manage classes, teachers and students for your school.',
                    style: AppText.meta.copyWith(fontSize: 14)),
                const SizedBox(height: 26),
                const FieldLabel('Email'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(hintText: 'admin@school.edu.ph'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email.' : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Password'),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password.' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration:
                        BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.red)),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 900) return SafeArea(child: form);
        return Row(
          children: [
            Expanded(
              child: Container(
                color: AppColors.sidebar,
                padding: const EdgeInsets.all(56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school_rounded, color: AppColors.gold, size: 64),
                    const SizedBox(height: 12),
                    Text('EDULEARN',
                        style: AppTheme.font(size: 40, weight: FontWeight.w800, color: AppColors.gold)),
                    Text('ADMIN DASHBOARD',
                        style: AppTheme.font(size: 14, weight: FontWeight.w700, color: AppColors.gold)
                            .copyWith(letterSpacing: 1.4)),
                    const SizedBox(height: 28),
                    Text(
                      'Create classes and official class codes, manage teacher accounts and '
                      'class rosters, and follow school-wide progress.',
                      style: AppTheme.font(size: 18, color: Colors.white.withValues(alpha: 0.9))
                          .copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: form),
          ],
        );
      }),
    );
  }
}
