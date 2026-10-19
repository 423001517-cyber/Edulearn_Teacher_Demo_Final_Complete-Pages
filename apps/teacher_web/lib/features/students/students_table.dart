import 'dart:math' as math;

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/data_providers.dart';
import '../classwork/classwork_form_dialog.dart';
import '../reports/report_actions.dart' show runExport;
import 'student_support_panel.dart';

enum _SortColumn { name, grade, completion, score, attendance, missing, status }

/// The "Students Directory" card: search, filters, export, the table and
/// pagination. Used on /students and in the class page's Students tab.
/// [classId] null = every active class.
class StudentsTable extends ConsumerStatefulWidget {
  const StudentsTable({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<StudentsTable> createState() => _StudentsTableState();
}

class _StudentsTableState extends ConsumerState<StudentsTable> {
  static const _pageSize = 10;

  String _query = '';
  int? _grade;
  String? _sectionClassId;
  Standing? _status;
  _SortColumn _sort = _SortColumn.name;
  bool _ascending = true;
  int _page = 0;

  @override
  void didUpdateWidget(StudentsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _page = 0;
      _grade = null;
      _sectionClassId = null;
    }
  }

  void _setSort(_SortColumn column) => setState(() {
        if (_sort == column) {
          _ascending = !_ascending;
        } else {
          _sort = column;
          // Numbers read best high-to-low first; names A–Z.
          _ascending = column == _SortColumn.name || column == _SortColumn.grade;
        }
        _page = 0;
      });

  List<Student> _apply(List<Student> input, Map<String, ClassRoom> classes, DateTime now) {
    final q = _query.trim().toLowerCase();
    final out = input.where((s) {
      if (q.isNotEmpty && !'${s.name} ${s.studentNumber}'.toLowerCase().contains(q)) return false;
      if (_grade != null && s.gradeLevel != _grade) return false;
      if (_sectionClassId != null && s.classId != _sectionClassId) return false;
      if (_status != null && s.standing(now) != _status) return false;
      return true;
    }).toList();

    String section(Student s) => classes[s.classId]?.name ?? '';
    int cmp(Student a, Student b) => switch (_sort) {
          _SortColumn.name => a.name.compareTo(b.name),
          _SortColumn.grade => section(a).compareTo(section(b)),
          _SortColumn.completion => a.questProgress.compareTo(b.questProgress),
          _SortColumn.score => (a.averageScore ?? -1).compareTo(b.averageScore ?? -1),
          _SortColumn.attendance => (a.attendanceRate ?? -1).compareTo(b.attendanceRate ?? -1),
          _SortColumn.missing => a.missingCount.compareTo(b.missingCount),
          _SortColumn.status => a.standing(now).index.compareTo(b.standing(now).index),
        };
    out.sort((a, b) {
      final c = _ascending ? cmp(a, b) : cmp(b, a);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }

  Future<void> _export(List<Student> rows, Map<String, ClassRoom> classes) {
    final now = DateTime.now();
    final scope = widget.classId == null ? 'all classes' : (classes[widget.classId]?.name ?? 'class');
    return runExport(
      ref,
      'student list',
      (x) => x.exportCsv(
        fileName: fileSlug('students $scope'),
        table: ReportTable(
          ['Student', 'Number', 'Grade & Section', 'Completion', 'Average score', 'Attendance', 'Missing work', 'Status'],
          [
            for (final s in rows)
              [
                s.name,
                s.studentNumber,
                classes[s.classId]?.name ?? s.gradeLabel,
                percent(s.questProgress),
                percent(s.averageScore),
                percent(s.attendanceRate),
                '${s.missingCount}',
                s.standing(now).label,
              ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classId = widget.classId;
    final active = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final byId = ref.watch(classByIdProvider);
    final students = classId != null
        ? ref.watch(classStudentsProvider(classId))
        : ref.watch(studentsProvider).whenData((l) => l.where((s) => active.any((c) => c.id == s.classId)).toList());
    final allClasses = classId == null;
    final grades = {for (final c in active) c.gradeLevel}.toList()..sort();
    final sections = active.where((c) => _grade == null || c.gradeLevel == _grade).toList();
    ClassRoom? sectionValue;
    for (final c in sections) {
      if (c.id == _sectionClassId) sectionValue = c;
    }

    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: AsyncValueView<List<Student>>(
        value: students,
        loadingHeight: 280,
        data: (list) {
          final now = DateTime.now();
          final rows = _apply(list, byId, now);
          final pages = math.max(1, (rows.length / _pageSize).ceil());
          final page = math.min(_page, pages - 1);
          final start = page * _pageSize;
          final shown = rows.sublist(start, math.min(start + _pageSize, rows.length));

          final filters = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: SearchField(
                  hint: 'Search student…',
                  initialValue: _query,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _page = 0;
                  }),
                ),
              ),
              if (allClasses) ...[
                FilterDropdown<int?>(
                  value: _grade,
                  options: [null, ...grades],
                  labelOf: (g) => g == null ? 'All Grades' : 'Grade $g',
                  minWidth: 140,
                  onChanged: (g) => setState(() {
                    _grade = g;
                    _sectionClassId = null;
                    _page = 0;
                  }),
                ),
                FilterDropdown<ClassRoom?>(
                  value: sectionValue,
                  options: [null, ...sections],
                  labelOf: (c) => c == null ? 'All Sections' : c.section,
                  minWidth: 150,
                  onChanged: (c) => setState(() {
                    _sectionClassId = c?.id;
                    _page = 0;
                  }),
                ),
              ],
              FilterDropdown<Standing?>(
                value: _status,
                options: const [null, ...Standing.values],
                labelOf: (s) => s?.label ?? 'All Status',
                minWidth: 140,
                onChanged: (s) => setState(() {
                  _status = s;
                  _page = 0;
                }),
              ),
              OutlinedButton.icon(
                onPressed: rows.isEmpty ? null : () => _export(rows, byId),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export List'),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Students Directory', style: AppText.sectionTitle.copyWith(fontSize: 18)),
                    const SizedBox(height: 14),
                    filters,
                  ],
                ),
              ),
              if (rows.isEmpty)
                EmptyNote(
                  list.isEmpty ? 'No students yet.' : 'No students match these filters.',
                  icon: Icons.groups_outlined,
                )
              else
                LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth >= 860;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide) _HeaderRow(sort: _sort, ascending: _ascending, onSort: _setSort, showClass: allClasses),
                      for (final s in shown)
                        wide
                            ? _WideRow(student: s, now: now, classRoom: byId[s.classId], showClass: allClasses)
                            : _CompactRow(student: s, now: now, classRoom: byId[s.classId], showClass: allClasses),
                    ],
                  );
                }),
              _Pagination(
                start: start,
                end: start + shown.length,
                total: rows.length,
                page: page,
                pages: pages,
                onPage: (p) => setState(() => _page = p),
              ),
            ],
          );
        },
      ),
    );
  }
}

List<int> _flexFor(bool showClass) => showClass ? [24, 15, 14, 10, 10, 9, 13, 7] : [27, 0, 16, 11, 11, 10, 15, 8];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.sort, required this.ascending, required this.onSort, required this.showClass});

  final _SortColumn sort;
  final bool ascending;
  final ValueChanged<_SortColumn> onSort;
  final bool showClass;

  @override
  Widget build(BuildContext context) {
    final flex = _flexFor(showClass);
    Widget cell(int i, String label, [_SortColumn? column]) => Expanded(
          flex: flex[i],
          child: column == null
              ? Text(label, style: AppText.label.copyWith(fontSize: 13))
              : InkWell(
                  onTap: () => onSort(column),
                  child: Row(
                    children: [
                      Flexible(child: Text(label, style: AppText.label.copyWith(fontSize: 13))),
                      const SizedBox(width: 4),
                      Icon(
                        sort != column
                            ? Icons.unfold_more_rounded
                            : (ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                        size: 15,
                        color: sort == column ? AppColors.primary : AppColors.muted,
                      ),
                    ],
                  ),
                ),
        );

    return Container(
      color: AppColors.chip.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          cell(0, 'Student', _SortColumn.name),
          if (showClass) cell(1, 'Grade & Section', _SortColumn.grade),
          cell(2, 'Completion', _SortColumn.completion),
          cell(3, 'Average Score', _SortColumn.score),
          cell(4, 'Attendance', _SortColumn.attendance),
          cell(5, 'Missing Work', _SortColumn.missing),
          cell(6, 'Status', _SortColumn.status),
          cell(7, 'Actions'),
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showStudentPanel(context, student),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          InitialsAvatar(
            initials: student.initials,
            tone: toneForName(student.name),
            size: 40,
            imageUrl: student.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
                if (student.numberLabel.isNotEmpty)
                  Text(student.numberLabel, style: AppText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.standing});

  final Standing standing;

  @override
  Widget build(BuildContext context) => Pill(standing.label, tone: standing.tone, dot: true);
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return MoreMenu<String>(
      items: [
        menuItem('profile', Icons.person_outline_rounded, 'View profile'),
        menuItem('message', Icons.chat_bubble_outline_rounded, 'Send message'),
        menuItem('remind', Icons.send_outlined, 'Send reminder'),
        menuItem('remedial', Icons.assignment_outlined, 'Assign remedial quest'),
        menuItem('attendance', Icons.fact_check_outlined, 'Attendance'),
        menuItem('class', Icons.menu_book_outlined, 'Open class'),
      ],
      onSelected: (v) {
        switch (v) {
          case 'profile':
            showStudentPanel(context, student);
          case 'message':
            context.go(Routes.messages(studentId: student.id));
          case 'remind':
            showSendReminder(context, student);
          case 'remedial':
            showClassworkForm(context, type: ClassworkType.quest, assignTo: student);
          case 'attendance':
            context.go(Routes.attendance(classId: student.classId));
          case 'class':
            context.go(Routes.classDetail(student.classId));
        }
      },
    );
  }
}

class _WideRow extends StatelessWidget {
  const _WideRow({required this.student, required this.now, required this.classRoom, required this.showClass});

  final Student student;
  final DateTime now;
  final ClassRoom? classRoom;
  final bool showClass;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final flex = _flexFor(showClass);
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: flex[0], child: Padding(padding: const EdgeInsets.only(right: 10), child: _NameCell(student: s))),
          if (showClass)
            Expanded(
              flex: flex[1],
              child: Text(classRoom?.name ?? s.gradeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
            ),
          Expanded(
            flex: flex[2],
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(percent(s.questProgress), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  ProgressBar(value: s.questProgress, height: 7),
                ],
              ),
            ),
          ),
          Expanded(flex: flex[3], child: Text(percent(s.averageScore), style: AppText.body)),
          Expanded(flex: flex[4], child: Text(percent(s.attendanceRate), style: AppText.body)),
          Expanded(
            flex: flex[5],
            child: Text('${s.missingCount}',
                style: TextStyle(fontWeight: FontWeight.w700, color: s.missingCount > 0 ? AppColors.red : AppColors.ink)),
          ),
          Expanded(
            flex: flex[6],
            child: Align(alignment: Alignment.centerLeft, child: _StatusPill(standing: s.standing(now))),
          ),
          Expanded(flex: flex[7], child: Align(alignment: Alignment.centerLeft, child: _RowActions(student: s))),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.student, required this.now, required this.classRoom, required this.showClass});

  final Student student;
  final DateTime now;
  final ClassRoom? classRoom;
  final bool showClass;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _NameCell(student: s)),
              _StatusPill(standing: s.standing(now)),
              const SizedBox(width: 8),
              _RowActions(student: s),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              if (showClass) Text(classRoom?.name ?? s.gradeLabel, style: AppText.meta),
              Text('Completion ${percent(s.questProgress)}', style: AppText.meta),
              Text('Average ${percent(s.averageScore)}', style: AppText.meta),
              Text('Attendance ${percent(s.attendanceRate)}', style: AppText.meta),
              Text('Missing ${s.missingCount}',
                  style: AppText.meta.copyWith(color: s.missingCount > 0 ? AppColors.red : null)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.start,
    required this.end,
    required this.total,
    required this.page,
    required this.pages,
    required this.onPage,
  });

  final int start;
  final int end;
  final int total;
  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    Widget box(Widget child, {VoidCallback? onTap, bool selected = false, double width = 38}) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: selected ? AppColors.primary : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: selected ? AppColors.primary : AppColors.buttonBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: SizedBox(width: width, height: 38, child: Center(child: child)),
            ),
          ),
        );

    // 1 2 3 … 14 style page list.
    final numbers = <int?>[];
    for (var p = 0; p < pages; p++) {
      final edge = p == 0 || p == pages - 1;
      final near = (p - page).abs() <= 1 || (page <= 1 && p <= 2) || (page >= pages - 2 && p >= pages - 3);
      if (edge || near) {
        numbers.add(p);
      } else if (numbers.isNotEmpty && numbers.last != null) {
        numbers.add(null);
      }
    }

    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: [
          Text(total == 0 ? 'No students' : 'Showing ${start + 1}–$end of $total students', style: AppText.meta),
          if (pages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                box(
                  Text('Previous',
                      style: TextStyle(fontWeight: FontWeight.w600, color: page > 0 ? AppColors.ink : AppColors.muted)),
                  onTap: page > 0 ? () => onPage(page - 1) : null,
                  width: 84,
                ),
                for (final p in numbers)
                  p == null
                      ? const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('…', style: AppText.meta))
                      : box(
                          Text('${p + 1}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p == page ? Colors.white : AppColors.ink)),
                          selected: p == page,
                          onTap: () => onPage(p),
                        ),
                box(
                  Text('Next',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: page < pages - 1 ? AppColors.ink : AppColors.muted)),
                  onTap: page < pages - 1 ? () => onPage(page + 1) : null,
                  width: 64,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
