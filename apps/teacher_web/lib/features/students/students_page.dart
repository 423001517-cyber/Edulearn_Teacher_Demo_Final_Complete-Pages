import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/data_providers.dart';
import '../shell/class_scope_selector.dart';
import '../shell/top_bar.dart';
import 'student_support_panel.dart';
import 'students_table.dart';

/// `/students?classId=&student=` — learners, progress, performance and
/// support needs. "View Students" from Classes lands here filtered to that
/// class; `student` opens that student's panel.
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
    final active = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final all = ref.watch(studentsProvider);
    _maybeOpenStudent(all.valueOrNull ?? const <Student>[]);
    final inScope = all.whenData((l) => l
        .where((s) => classId == null ? active.any((c) => c.id == s.classId) : s.classId == classId)
        .toList());
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    return PageScaffold(
      header: PageHeader(
        icon: Icons.wb_sunny_rounded,
        title: 'Students',
        subtitle: 'View learners, progress, performance, and support needs.',
        actions: ClassScopeSelector(
          classId: classId,
          onChanged: (id) => goTo(Routes.students(classId: id)),
        ),
      ),
      children: [
        ResponsiveGrid(
          maxColumns: 4,
          children: [
            StatCard(
              icon: Icons.groups_rounded,
              tone: Tone.green,
              label: 'Total Students',
              value: inScope.whenData((l) => '${l.length}'),
              caption: classId == null ? 'In your active classes' : 'In this class',
            ),
            StatCard(
              icon: Icons.bar_chart_rounded,
              tone: Tone.green,
              label: 'Active This Week',
              value: inScope.whenData(
                  (l) => '${l.where((s) => s.lastActiveAt != null && s.lastActiveAt!.isAfter(weekAgo)).length}'),
              caption: 'Opened EduLearn in the last 7 days',
            ),
            StatCard(
              icon: Icons.description_rounded,
              tone: Tone.red,
              label: 'Missing Work',
              value: inScope.whenData((l) => '${l.where((s) => s.missingCount > 0).length}'),
              caption: 'Students with work not turned in',
              onTap: () => goTo(Routes.reports(classId: classId, panel: 'missing')),
            ),
            StatCard(
              icon: Icons.warning_amber_rounded,
              tone: Tone.amber,
              label: 'Needs Support',
              value: inScope.whenData((l) => '${l.where((s) => s.standing(now) == Standing.needsSupport).length}'),
              caption: 'Missing work or inactive',
            ),
          ],
        ),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 1,
          breakpoint: 1180,
          left: [StudentsTable(classId: classId)],
          right: [_NeedingSupportCard(classId: classId, students: inScope.valueOrNull ?? const [])],
        ),
      ],
    );
  }
}

/// Why a student was flagged, in one line ("2 missing works • Average score below 75%").
String supportReasons(Student s, DateTime now) {
  final parts = <String>[
    if (s.missingCount > 0) '${s.missingCount} missing ${s.missingCount == 1 ? 'work' : 'works'}',
    if ((s.averageScore ?? 1) < 0.75) 'Average score below 75%',
    if ((s.recentScore ?? 1) < Student.lowScoreThreshold) 'Low recent scores',
    if (s.inactiveDays(now) >= Student.inactiveDaysThreshold) 'Inactive ${s.inactiveDays(now)} days',
    if (s.absences >= 2) '${s.absences} absences',
  ];
  return parts.take(2).join(' • ');
}

class _NeedingSupportCard extends ConsumerWidget {
  const _NeedingSupportCard({required this.classId, required this.students});

  final String? classId;
  final List<Student> students;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final byId = ref.watch(classByIdProvider);
    final flagged = flagStudents(students, now);
    return SectionCard(
      title: 'Students Needing Support',
      showDivider: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (flagged.isEmpty)
            const EmptyNote('Everyone is on track right now.', icon: Icons.verified_outlined)
          else
            for (var i = 0; i < flagged.length && i < 5; i++) ...[
              if (i > 0) const Divider(),
              _SupportRow(
                student: flagged[i].student,
                standing: flagged[i].student.standing(now),
                className: byId[flagged[i].student.classId]?.name ?? flagged[i].student.gradeLabel,
                reason: supportReasons(flagged[i].student, now),
              ),
            ],
          if (flagged.length > 5) ...[
            const SizedBox(height: 4),
            Text('+${flagged.length - 5} more — filter the directory by status to see everyone.',
                style: AppText.meta.copyWith(fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: LinkButton(
              label: 'View support report',
              onTap: () => goTo(Routes.reports(classId: classId, panel: 'missing')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.student, required this.standing, required this.className, required this.reason});

  final Student student;
  final Standing standing;
  final String className;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showStudentPanel(context, student),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(initials: student.initials, tone: standing.tone, size: 48, imageUrl: student.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: AppText.itemTitle.copyWith(fontSize: 14.5)),
                  Text(className, style: AppText.meta),
                  const SizedBox(height: 8),
                  Pill(standing.label, tone: standing.tone, dot: true),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(reason, style: AppText.meta.copyWith(fontSize: 12.5, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
