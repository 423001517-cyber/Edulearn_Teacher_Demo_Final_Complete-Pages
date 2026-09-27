import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';

/// `/login` — the router sends signed-out visitors here and forwards them
/// to where they were going after sign-in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // The router's auth listener redirects on success.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authRepositoryProvider);
    await _run(() => _register
        ? auth.register(name: _name.text, email: _email.text, password: _password.text)
        : auth.signIn(email: _email.text, password: _password.text));
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first, then tap “Forgot password?”.');
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      showToast('Password reset link sent to ${_email.text.trim()}');
    });
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address looks wrong.',
        'user-disabled' => 'This account has been disabled. Contact your administrator.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email. Sign in instead.',
        'weak-password' => 'Use at least 6 characters for your password.',
        'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Google sign-in was cancelled.',
        'network-request-failed' => 'No connection. Check your internet and try again.',
        _ => e.message ?? 'Sign-in failed (${e.code}).',
      };

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
                Text(_register ? 'Create your account' : 'Welcome back', style: AppText.greeting),
                const SizedBox(height: 6),
                Text(
                  _register
                      ? 'Set up your EduLearn teacher account.'
                      : 'Sign in to your EduLearn teacher dashboard.',
                  style: AppText.meta.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 26),
                if (_register) ...[
                  const FieldLabel('Full name'),
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Jean Magallanes'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name.' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                const FieldLabel('Email'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'you@school.edu.ph'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email.' : null,
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
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'At least 6 characters.' : null,
                ),
                if (!_register)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.redSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.red)),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_register ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref.read(authRepositoryProvider).signInWithGoogle()),
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                  child: Text(_register
                      ? 'Already have an account? Sign in'
                      : 'New teacher? Create an account'),
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
                    Text('TEACHER DASHBOARD',
                        style: AppTheme.font(size: 14, weight: FontWeight.w700, color: AppColors.gold)
                            .copyWith(letterSpacing: 1.4)),
                    const SizedBox(height: 28),
                    Text(
                      'Plan weekly quests, review submissions, and see which students need '
                      'support — all in one place.',
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
