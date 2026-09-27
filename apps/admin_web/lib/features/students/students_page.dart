import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';
import '../common/admin_widgets.dart';
import '../shell/top_bar.dart';
import 'student_dialogs.dart';

/// `/students?classId=` — every student in the school (class rosters).
class AdminStudentsPage extends ConsumerStatefulWidget {
  const AdminStudentsPage({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends ConsumerState<AdminStudentsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider);
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final classById = ref.watch(classByIdProvider);
    final teacherById = ref.watch(teacherByIdProvider);
    final cls = classById[widget.classId];
    final now = DateTime.now();

    final q = _query.trim().toLowerCase();
    final shown = (students.valueOrNull ?? const <Student>[]).where((s) {
      if (widget.classId != null && s.classId != widget.classId) return false;
      if (widget.classId == null && !(classById[s.classId] != null && !classById[s.classId]!.isArchived)) {
        return false; // "All classes" = active classes
      }
      return q.isEmpty || '${s.name} ${s.studentNumber}'.toLowerCase().contains(q);
    }).toList();

    return PageScaffold(
      header: AdminPageHeader(
        icon: Icons.groups_outlined,
        title: 'Students',
        subtitle: cls == null
            ? 'Class rosters for the whole school · ${shown.length} students'
            : '${cls.name} · ${teacherById[cls.teacherId]?.displayName ?? 'No teacher'} · ${shown.length} students',
      ),
      children: [
        Container(
          decoration: AppDecorations.card,
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(builder: (context, box) {
            final search = SearchField(
              hint: 'Search by name or student number...',
              onChanged: (v) => setState(() => _query = v),
            );
            final tools = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterDropdown<ClassRoom?>(
                  value: cls,
                  options: [null, ...classes, if (cls != null && cls.isArchived) cls],
                  labelOf: (c) => c?.name ?? 'All Classes',
                  icon: Icons.menu_book_outlined,
                  onChanged: (c) => context.go(AdminRoutes.students(classId: c?.id)),
                ),
                OutlinedButton.icon(
                  onPressed: () => showImportDialog(context, classId: widget.classId),
                  icon: const Icon(Icons.upload_file_outlined, size: 20),
                  label: const Text('Import CSV'),
                ),
                FilledButton.icon(
                  onPressed: classes.isEmpty ? null : () => showStudentForm(context, classId: widget.classId),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  label: const Text('Add Student'),
                ),
              ],
            );
            if (box.maxWidth < 1000) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 10), tools],
              );
            }
            return Row(children: [Expanded(child: search), const SizedBox(width: 12), tools]);
          }),
        ),
        AsyncValueView<List<Student>>(
          value: students,
          loadingHeight: 240,
          data: (_) => AdminTable<Student>(
            noun: 'students',
            emptyMessage: classes.isEmpty
                ? 'Create a class first, then add or import its students.'
                : 'No students here yet. Add them one by one or import a CSV.',
            items: shown,
            columns: const [
              TableCol('Student', flex: 24),
              TableCol('Class', flex: 16),
              TableCol('Teacher', flex: 15),
              TableCol('Quest Completion', flex: 14),
              TableCol('Avg Score', flex: 9),
              TableCol('Attendance', flex: 9),
              TableCol('Status', flex: 13),
              TableCol('', flex: 12),
            ],
            cells: (s) {
              final c = classById[s.classId];
              final standing = s.standing(now);
              return [
                PersonCell(name: s.name, subtitle: s.numberLabel),
                Text(c?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                Text(teacherById[c?.teacherId]?.displayName ?? '—',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
                RateCell(s.questProgress),
                Text(percent(s.averageScore), style: AppText.body),
                Text(percent(s.attendanceRate), style: AppText.body),
                Pill(standing.label, tone: standing.tone, icon: standing.icon),
                _StudentActions(student: s),
              ];
            },
            compact: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PersonCell(name: s.name, subtitle: '${s.numberLabel} · ${classById[s.classId]?.name ?? ''}'),
                const SizedBox(height: 6),
                Text(
                  'Quests ${percent(s.questProgress)} · Avg ${percent(s.averageScore)} · '
                  'Attendance ${percent(s.attendanceRate)} · Missing ${s.missingCount}',
                  style: AppText.meta,
                ),
                Align(alignment: Alignment.centerRight, child: _StudentActions(student: s)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentActions extends ConsumerWidget {
  const _StudentActions({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () => showStudentForm(context, existing: student),
          child: const Text('Edit'),
        ),
        const SizedBox(width: 6),
        MoreMenu<String>(
          items: [
            menuItem('move', Icons.swap_horiz_rounded, 'Move to another class'),
            const PopupMenuDivider(),
            menuItem('remove', Icons.person_remove_outlined, 'Remove from school', destructive: true),
          ],
          onSelected: (v) async {
            if (v == 'move') {
              showStudentForm(context, existing: student);
              return;
            }
            final repo = ref.read(adminRepositoryProvider);
            final ok = await confirmAction(
              context,
              title: 'Remove ${student.name}?',
              message: 'They disappear from their class roster. Past submissions stay in the '
                  'class reports. This can’t be undone — to change classes, use Move instead.',
              confirmLabel: 'Remove',
              destructive: true,
            );
            if (ok) await attempt(() => repo.deleteStudent(student.id), success: '${student.name} removed');
          },
        ),
      ],
    );
  }
}
