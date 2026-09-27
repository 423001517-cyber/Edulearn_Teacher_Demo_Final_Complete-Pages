import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';
import '../common/admin_widgets.dart';

/// "Create Class" — the server reserves a unique official code.
Future<void> showCreateClassDialog(BuildContext context, {String? teacherId}) =>
    showDialog<void>(context: context, builder: (_) => _ClassForm(teacherId: teacherId));

/// Rename, change grade/subject, or reassign to another teacher.
Future<void> showEditClassDialog(BuildContext context, ClassRoom c) =>
    showDialog<void>(context: context, builder: (_) => _ClassForm(existing: c));

class _ClassForm extends ConsumerStatefulWidget {
  const _ClassForm({this.existing, this.teacherId});

  final ClassRoom? existing;
  final String? teacherId;

  @override
  ConsumerState<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends ConsumerState<_ClassForm> {
  final _formKey = GlobalKey<FormState>();
  late final _section = TextEditingController(text: widget.existing?.section ?? '');
  late final _subject = TextEditingController(text: widget.existing?.subject ?? 'Araling Panlipunan');
  late int _grade = widget.existing?.gradeLevel ?? 4;
  late String? _teacherId = widget.existing?.teacherId ?? widget.teacherId;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _section.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_teacherId == null) {
      setState(() => _error = 'Choose a teacher.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final existing = widget.existing;
    if (existing != null) {
      final ok = await attempt(
        () => ref.read(adminRepositoryProvider).updateClass(
              existing,
              teacherId: _teacherId!,
              gradeLevel: _grade,
              section: _section.text,
              subject: _subject.text,
            ),
        success: 'Class updated',
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() => _saving = false);
      }
      return;
    }
    final code = await runAdminAction(() => ref.read(adminFunctionsProvider).createClass(
          gradeLevel: _grade,
          section: _section.text,
          subject: _subject.text,
          teacherId: _teacherId!,
        ));
    if (!mounted) return;
    if (code == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.pop(context);
    showClassCreated('Grade $_grade – ${_section.text.trim()}', code);
  }

  @override
  Widget build(BuildContext context) {
    final teachers = ref.watch(teachersProvider).valueOrNull ?? const <Teacher>[];
    final reassigning = _editing && _teacherId != widget.existing!.teacherId;
    return AppDialog(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              title: _editing ? 'Edit ${widget.existing!.name}' : 'Create Class',
              subtitle: _editing
                  ? 'Class code ${widget.existing!.classCode} stays the same'
                  : 'An official class code is issued automatically',
              leading: const ToneIcon(Icons.menu_book_outlined, tone: Tone.green, size: 46),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Grade'),
                      GradePicker(value: _grade, onChanged: (g) => setState(() => _grade = g)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Section'),
                      TextFormField(
                        controller: _section,
                        decoration: const InputDecoration(hintText: 'e.g. Rizal'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a section name.' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Subject'),
            TextFormField(
              controller: _subject,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a subject.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Teacher'),
            TeacherPicker(
              teachers: teachers,
              value: _teacherId,
              onChanged: (v) => setState(() => _teacherId = v),
            ),
            if (reassigning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: AppColors.amber),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The class moves to the new teacher with all its students, classwork, '
                        'submissions and reports.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.red)),
            ],
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
                    child: Text(_editing ? 'Save changes' : 'Create class'),
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

/// "Grade 4 – Luna created · LUNA-4A [Copy]"
Future<void> showClassCreated(String name, String code) => showRootDialog<void>(
      (ctx) => AppDialog(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ToneIcon(Icons.check_rounded, tone: Tone.green, size: 64, circle: true),
            const SizedBox(height: 14),
            Text('$name created', textAlign: TextAlign.center, style: AppText.dialogTitle),
            const SizedBox(height: 6),
            Text('Students join with this official class code:',
                textAlign: TextAlign.center, style: AppText.meta.copyWith(fontSize: 14)),
            const SizedBox(height: 14),
            Text(code,
                style: AppText.statValue.copyWith(fontSize: 34, letterSpacing: 1.5, color: AppColors.primary)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => copyText(code, 'Class code copied — $code is ready to paste.'),
                    icon: const Icon(Icons.content_copy_outlined, size: 18),
                    label: const Text('Copy code'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

enum AdminClassAction { edit, students, newCode, archive, restore }

/// ⋮ menu on a class row.
class AdminClassMenu extends ConsumerWidget {
  const AdminClassMenu({super.key, required this.classRoom, required this.onStudents});

  final ClassRoom classRoom;
  final VoidCallback onStudents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    return MoreMenu<AdminClassAction>(
      items: [
        menuItem(AdminClassAction.edit, Icons.edit_outlined, 'Edit / reassign'),
        menuItem(AdminClassAction.students, Icons.groups_outlined, 'View students'),
        menuItem(AdminClassAction.newCode, Icons.autorenew_rounded, 'Issue new class code'),
        const PopupMenuDivider(),
        c.isArchived
            ? menuItem(AdminClassAction.restore, Icons.unarchive_outlined, 'Restore class')
            : menuItem(AdminClassAction.archive, Icons.archive_outlined, 'Archive class', destructive: true),
      ],
      onSelected: (a) async {
        final repo = ref.read(adminRepositoryProvider);
        final functions = ref.read(adminFunctionsProvider);
        switch (a) {
          case AdminClassAction.edit:
            showEditClassDialog(context, c);
          case AdminClassAction.students:
            onStudents();
          case AdminClassAction.newCode:
            final ok = await confirmAction(
              context,
              title: 'Issue a new code for ${c.name}?',
              message: '${c.classCode} will stop working for new students. Students already in the '
                  'class are not affected. The teacher is notified of the new code.',
              confirmLabel: 'Issue new code',
            );
            if (!ok) return;
            final code = await runAdminAction(() => functions.regenerateClassCode(c.id));
            if (code != null) showClassCreated(c.name, code);
          case AdminClassAction.archive:
            final ok = await confirmAction(
              context,
              title: 'Archive ${c.name}?',
              message: 'It disappears from Active Classes for the teacher and students. Lessons, '
                  'submissions, grades and reports are kept and it can be restored later.',
              confirmLabel: 'Archive Class',
              destructive: true,
            );
            if (ok) await attempt(() => repo.setArchived(c, true), success: '${c.name} archived');
          case AdminClassAction.restore:
            await attempt(() => repo.setArchived(c, false), success: '${c.name} is active again');
        }
      },
    );
  }
}
