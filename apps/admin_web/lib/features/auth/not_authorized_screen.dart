import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';

/// Signed in, but the account doesn't have the admin role.
class NotAuthorizedScreen extends ConsumerWidget {
  const NotAuthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ToneIcon(Icons.lock_outline_rounded, tone: Tone.red, size: 72, circle: true),
                const SizedBox(height: 18),
                Text('This account isn’t an administrator',
                    textAlign: TextAlign.center, style: AppText.dialogTitle),
                const SizedBox(height: 8),
                Text(
                  '${session.user?.email ?? 'This account'} can’t open the admin website. '
                  'Teachers should use the teacher website. If an admin just gave you access, '
                  'tap “Check again”.',
                  textAlign: TextAlign.center,
                  style: AppText.meta.copyWith(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(onPressed: session.signOut, child: const Text('Sign out')),
                    FilledButton(
                      onPressed: () async {
                        await session.refreshRole();
                        if (!session.isAdmin) showToast('Still no admin access for this account.');
                      },
                      child: const Text('Check again'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
