import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';
import '../common/admin_widgets.dart';
import '../shell/top_bar.dart';

/// `/settings` — school profile and who can use the admin website.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      header: AdminPageHeader(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'School profile and administrator access.',
      ),
      children: [
        TwoColumn(leftFlex: 1, rightFlex: 1, left: [_SchoolProfile()], right: [_Administrators()]),
      ],
    );
  }
}

class _SchoolProfile extends ConsumerStatefulWidget {
  const _SchoolProfile();

  @override
  ConsumerState<_SchoolProfile> createState() => _SchoolProfileState();
}

class _SchoolProfileState extends ConsumerState<_SchoolProfile> {
  final _name = TextEditingController();
  final _year = TextEditingController();
  final _email = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Fill the fields once, when the saved profile first arrives (outside
    // build, so the text fields can update safely).
    ref.listenManual<AsyncValue<SchoolSettings>>(
      settingsProvider,
      (previous, next) {
        final s = next.valueOrNull;
        if (_loaded || s == null) return;
        _name.text = s.schoolName;
        _year.text = s.schoolYear;
        _email.text = s.contactEmail;
        _loaded = true;
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showToast('Enter the school name.');
      return;
    }
    setState(() => _saving = true);
    await attempt(
      () => ref.read(adminRepositoryProvider).saveSettings(SchoolSettings(
            schoolName: _name.text,
            schoolYear: _year.text,
            contactEmail: _email.text,
          )),
      success: 'School profile saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider); // keep the stream open while this page is shown
    return SectionCard(
      icon: Icons.apartment_rounded,
      title: 'School Profile',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('School name'),
            TextField(controller: _name),
            const SizedBox(height: 14),
            const FieldLabel('School year'),
            TextField(controller: _year, decoration: const InputDecoration(hintText: 'e.g. 2026–2027')),
            const SizedBox(height: 14),
            const FieldLabel('Contact email'),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save profile')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Administrators extends ConsumerStatefulWidget {
  const _Administrators();

  @override
  ConsumerState<_Administrators> createState() => _AdministratorsState();
}

class _AdministratorsState extends ConsumerState<_Administrators> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      showToast('Enter the person’s email address.');
      return;
    }
    setState(() => _busy = true);
    final ok = await attempt(
      () => ref.read(adminFunctionsProvider).setAdminRole(email, admin: true),
      success: '$email is now an administrator. They may need to sign in again.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _email.clear();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(adminSessionProvider).user?.uid;
    return SectionCard(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Administrators',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AsyncValueView<List<AdminUser>>(
            value: ref.watch(adminsProvider),
            data: (admins) => Column(
              children: [
                for (final a in admins)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: PersonCell(name: a.displayName, subtitle: a.email, size: 36)),
                        if (a.uid == me)
                          const Pill('You', tone: Tone.blue)
                        else
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppColors.red),
                            onPressed: () async {
                              final functions = ref.read(adminFunctionsProvider);
                              final ok = await confirmAction(
                                context,
                                title: 'Remove ${a.displayName}?',
                                message: 'They lose access to the admin website. If they are also a '
                                    'teacher, their teacher account keeps working.',
                                confirmLabel: 'Remove admin',
                                destructive: true,
                              );
                              if (ok) {
                                await attempt(() => functions.setAdminRole(a.email, admin: false),
                                    success: '${a.displayName} is no longer an administrator');
                              }
                            },
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          const FieldLabel('Add an administrator'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'their-email@school.edu.ph'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _busy ? null : _add, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 8),
          Text('They need an EduLearn account first (for example, an existing teacher).',
              style: AppText.meta.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
