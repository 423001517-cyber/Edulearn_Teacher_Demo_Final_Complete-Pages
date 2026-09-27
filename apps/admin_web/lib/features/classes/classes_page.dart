import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/admin_providers.dart';
import '../common/admin_widgets.dart';
import '../shell/top_bar.dart';
import 'class_dialogs.dart';

enum _StatusFilter {
  active('Active Classes'),
  archived('Archived Classes'),
  all('All Classes');

  const _StatusFilter(this.label);
  final String label;
}

/// `/classes?teacher=` — every class in the school.
class AdminClassesPage extends ConsumerStatefulWidget {
  const AdminClassesPage({super.key, this.teacherId});

  final String? teacherId;

  @override
  ConsumerState<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends ConsumerState<AdminClassesPage> {
  String _query = '';
  int? _grade;
  _StatusFilter _status = _StatusFilter.active;

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider);
    final teachers = ref.watch(teachersProvider).valueOrNull ?? const <Teacher>[];
    final byTeacher = ref.watch(teacherByIdProvider);
    final students = ref.watch(studentsByClassProvider);
    final all = classes.valueOrNull ?? const <ClassRoom>[];
    final active = all.where((c) => !c.isArchived).toList();
    final grades = {for (final c in all) c.gradeLevel}.toList()..sort();
    Teacher? teacherFilter = byTeacher[widget.teacherId];

    final q = _query.trim().toLowerCase();
    final shown = all.where((c) {
      if (_status == _StatusFilter.active && c.isArchived) return false;
      if (_status == _StatusFilter.archived && !c.isArchived) return false;
      if (_grade != null && c.gradeLevel != _grade) return false;
      if (widget.teacherId != null && c.teacherId != widget.teacherId) return false;
      final teacher = byTeacher[c.teacherId]?.displayName ?? '';
      return q.isEmpty || '${c.name} ${c.subject} ${c.classCode} $teacher'.toLowerCase().contains(q);
    }).toList();

    double avg(Iterable<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    return PageScaffold(
      header: const AdminPageHeader(
        icon: Icons.menu_book_outlined,
        title: 'Classes',
        subtitle: 'Create classes, issue official class codes and assign teachers.',
      ),
      children: [
        ResponsiveGrid(
          children: [
            StatCard(
              icon: Icons.menu_book_outlined,
              tone: Tone.green,
              label: 'Active Classes',
              value: classes.whenData((_) => '${active.length}'),
              caption: '${all.length - active.length} archived',
            ),
            StatCard(
              icon: Icons.groups_rounded,
              tone: Tone.blue,
              label: 'Enrolled Students',
              value: classes.whenData((_) => '${active.fold<int>(0, (n, c) => n + c.studentCount)}'),
              caption: 'In active classes',
            ),
            StatCard(
              icon: Icons.bar_chart_rounded,
              tone: Tone.amber,
              label: 'Average Completion',
              value: classes.whenData((_) => percent(avg(active.map((c) => c.completionRate)))),
              caption: 'Across active classes',
            ),
            StatCard(
              icon: Icons.star_rounded,
              tone: Tone.purple,
              label: 'Average Score',
              value: classes.whenData((_) => percent(avg(active.map((c) => c.averageScore)))),
              caption: 'Across active classes',
            ),
          ],
        ),
        Container(
          decoration: AppDecorations.card,
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(builder: (context, box) {
            final search = SearchField(hint: 'Search classes, codes or teachers...', onChanged: (v) => setState(() => _query = v));
            final filters = Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterDropdown<int?>(
                  value: _grade,
                  options: [null, ...grades],
                  labelOf: (g) => g == null ? 'All Grades' : 'Grade $g',
                  onChanged: (g) => setState(() => _grade = g),
                ),
                FilterDropdown<Teacher?>(
                  value: teacherFilter,
                  options: [null, ...teachers],
                  labelOf: (t) => t?.displayName ?? 'All Teachers',
                  onChanged: (t) => context.go(AdminRoutes.classes(teacherId: t?.uid)),
                ),
                FilterDropdown<_StatusFilter>(
                  value: _status,
                  options: _StatusFilter.values,
                  labelOf: (s) => s.label,
                  onChanged: (s) => setState(() => _status = s),
                ),
                FilledButton.icon(
                  onPressed: () => showCreateClassDialog(context, teacherId: widget.teacherId),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Create Class'),
                ),
              ],
            );
            if (box.maxWidth < 1100) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 10), filters],
              );
            }
            return Row(children: [Expanded(child: search), const SizedBox(width: 12), filters]);
          }),
        ),
        AsyncValueView<List<ClassRoom>>(
          value: classes,
          loadingHeight: 240,
          data: (_) => AdminTable<ClassRoom>(
            noun: 'classes',
            emptyMessage: all.isEmpty
                ? 'No classes yet. Create one, or approve a teacher’s class request.'
                : 'No classes match these filters.',
            items: shown,
            columns: const [
              TableCol('Class', flex: 24),
              TableCol('Code', flex: 13),
              TableCol('Teacher', flex: 18),
              TableCol('Students', flex: 9),
              TableCol('Completion', flex: 14),
              TableCol('Avg Score', flex: 9),
              TableCol('Status', flex: 10),
              TableCol('', flex: 12),
            ],
            cells: (c) {
              final teacher = byTeacher[c.teacherId];
              final enrolled = students[c.id]?.length ?? c.studentCount;
              return [
                _ClassName(classRoom: c),
                CodeChip(c.classCode),
                Text(teacher?.displayName ?? 'Unassigned',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                Text('$enrolled', style: AppText.body),
                RateCell(c.completionRate),
                Text(percent(c.averageScore), style: AppText.body),
                c.isArchived
                    ? const Pill('Archived', tone: Tone.neutral, dot: true)
                    : const Pill('Active', tone: Tone.green, dot: true),
                _Actions(classRoom: c),
              ];
            },
            compact: (c) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Expanded(child: _ClassName(classRoom: c)), CodeChip(c.classCode)]),
                const SizedBox(height: 8),
                Text(
                  '${byTeacher[c.teacherId]?.displayName ?? 'Unassigned'} · ${c.studentCount} students · '
                  '${percent(c.completionRate)} completion',
                  style: AppText.meta,
                ),
                Align(alignment: Alignment.centerRight, child: _Actions(classRoom: c)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassName extends StatelessWidget {
  const _ClassName({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClassThumbnail(classRoom: classRoom, width: 56, height: 40, radius: 8),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(classRoom.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
              Text(classRoom.subject,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: () => showEditClassDialog(context, classRoom), child: const Text('Edit')),
        const SizedBox(width: 6),
        AdminClassMenu(
          classRoom: classRoom,
          onStudents: () => context.go(AdminRoutes.students(classId: classRoom.id)),
        ),
      ],
    );
  }
}
