import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';
import '../classes/class_dialogs.dart';
import '../common/admin_widgets.dart';

/// "Add Teacher": creates the sign-in account, then shows the one-time link
/// the teacher uses to set their password.
Future<void> showAddTeacherDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _AddTeacherDialog());

class _AddTeacherDialog extends ConsumerStatefulWidget {
  const _AddTeacherDialog();

  @override
  ConsumerState<_AddTeacherDialog> createState() => _AddTeacherDialogState();
}

class _AddTeacherDialogState extends ConsumerState<_AddTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final link = await runAdminAction(() => ref
        .read(adminFunctionsProvider)
        .createTeacherAccount(displayName: _name.text, email: _email.text));
    if (!mounted) return;
    if (link == null) {
      setState(() => _saving = false);
      return;
    }
    final name = _name.text.trim();
    final email = _email.text.trim();
    Navigator.pop(context);
    showLinkDialog(
      title: '$name can now sign in',
      message: 'Send this link to $email. It lets them choose a password for the teacher '
          'website. Next, create a class for them or approve their class request.',
      link: link,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 460,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHeader(
              title: 'Add Teacher',
              subtitle: 'Creates their EduLearn teacher account',
              leading: ToneIcon(Icons.person_add_alt_1_outlined, tone: Tone.blue, size: 46),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Full name'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Rosa Dizon'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter their name.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('School email'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'teacher@school.edu.ph'),
              validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  ? 'Enter a valid email.'
                  : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create account'),
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

Future<void> sendPasswordLink(BuildContext context, WidgetRef ref, Teacher t) async {
  final link = await runAdminAction(() => ref.read(adminFunctionsProvider).teacherPasswordLink(t.uid));
  if (link != null) {
    showLinkDialog(
        title: 'Password link for ${t.firstName}',
        message: 'Send this to ${t.email ?? t.displayName}. It lets them set a new password.',
        link: link);
  }
}

Future<void> toggleTeacher(BuildContext context, WidgetRef ref, Teacher t) async {
  final functions = ref.read(adminFunctionsProvider);
  if (!t.isDisabled) {
    final ok = await confirmAction(
      context,
      title: 'Disable ${t.displayName}?',
      message: 'They are signed out and can’t sign in to the teacher website. Their classes and '
          'students stay as they are — reassign the classes if someone else will teach them.',
      confirmLabel: 'Disable account',
      destructive: true,
    );
    if (!ok) return;
  }
  await attempt(
    () => functions.setTeacherStatus(t.uid, disabled: !t.isDisabled),
    success: t.isDisabled ? '${t.displayName} can sign in again' : '${t.displayName} was disabled',
  );
}

/// Right-hand drawer with the teacher's classes and account actions.
Future<void> showTeacherPanel(BuildContext context, Teacher t) =>
    showSidePanel<void>(context: context, width: 440, builder: (_) => _TeacherPanel(uid: t.uid, fallback: t));

class _TeacherPanel extends ConsumerWidget {
  const _TeacherPanel({required this.uid, required this.fallback});

  final String uid;
  final Teacher fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(teacherByIdProvider)[uid] ?? fallback;
    final classes = ref.watch(classesByTeacherProvider)[uid] ?? const <ClassRoom>[];
    final students = classes.fold<int>(0, (n, c) => n + c.studentCount);
    final completion = classes.isEmpty
        ? null
        : classes.fold<double>(0, (n, c) => n + c.completionRate) / classes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PanelHeader(
                title: t.displayName,
                subtitle: t.email,
                leading: InitialsAvatar(initials: t.initials, tone: toneForName(t.displayName), size: 60),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: t.isDisabled
                    ? const Pill('Disabled', tone: Tone.red, dot: true)
                    : const Pill('Active', tone: Tone.green, dot: true),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              Row(
                children: [
                  _Mini('${classes.length}', 'Classes'),
                  _Mini('$students', 'Students'),
                  _Mini(percent(completion), 'Avg completion'),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              Row(
                children: [
                  Expanded(child: Text('Classes', style: AppText.sectionTitle.copyWith(fontSize: 15.5))),
                  LinkButton(
                    label: 'Create class',
                    showArrow: false,
                    onTap: t.isDisabled ? null : () => showCreateClassDialog(context, teacherId: t.uid),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (classes.isEmpty)
                const EmptyNote('No active classes yet.')
              else
                for (final c in classes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        ClassThumbnail(classRoom: c, width: 52, height: 40, radius: 8),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                              Text('${c.studentCount} students · ${percent(c.completionRate)} completion',
                                  style: AppText.meta.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        CodeChip(c.classCode),
                        IconButton(
                          tooltip: 'Edit / reassign',
                          onPressed: () => showEditClassDialog(context, c),
                          icon: const Icon(Icons.edit_outlined, size: 19),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => sendPasswordLink(context, ref, t),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Password setup link'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  goTo(AdminRoutes.classes(teacherId: t.uid));
                },
                child: const Text('Open in Classes'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: t.isDisabled ? null : FilledButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: () => toggleTeacher(context, ref, t),
                child: Text(t.isDisabled ? 'Enable account' : 'Disable account'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(label, style: AppText.meta.copyWith(fontSize: 12)),
          ],
        ),
      );
}
