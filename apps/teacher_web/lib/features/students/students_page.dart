import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/data_providers.dart';
import '../shell/top_bar.dart';
import 'student_support_panel.dart';
import 'students_table.dart';

/// `/students?classId=&student=` — "View Students" from Classes lands here
/// filtered to that class; `student` opens that student's panel.
class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key, this.classId, this.studentId});

  final String? classId;
  final String? studentId;

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  String? _openedFor;

  void _maybeOpenStudent(List<Student> students) {
    final id = widget.studentId;
    if (id == null || _openedFor == id) return;
    for (final s in students) {
      if (s.id == id) {
        _openedFor = id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showStudentPanel(context, s);
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classId = widget.classId;
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final cls = classId == null ? null : ref.watch(classByIdProvider)[classId];
    final students = ref.watch(studentsProvider).valueOrNull ?? const <Student>[];
    _maybeOpenStudent(students);

    final count = classId == null
        ? students.where((s) => classes.any((c) => c.id == s.classId)).length
        : students.where((s) => s.classId == classId).length;

    return PageScaffold(
      header: PageHeader(
        icon: Icons.groups_outlined,
        title: 'Students',
        subtitle: '${cls?.name ?? 'All classes'} • $count students',
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilterDropdown<ClassRoom?>(
            value: cls,
            options: [null, ...classes, if (cls != null && cls.isArchived) cls],
            icon: Icons.menu_book_outlined,
            labelOf: (c) => c?.name ?? 'All Classes',
            onChanged: (c) => context.go(Routes.students(classId: c?.id)),
          ),
        ),
        StudentsTable(classId: classId),
      ],
    );
  }
}
