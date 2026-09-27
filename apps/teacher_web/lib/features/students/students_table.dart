import 'dart:math' as math;

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/data_providers.dart';
import '../classwork/classwork_form_dialog.dart';
import 'student_support_panel.dart';

enum _SortColumn { name, attendance, completion, score, missing, status }

/// Filters + table + pagination. Used on /students and in the class
/// page's Students tab. [classId] null = every active class.
class StudentsTable extends ConsumerStatefulWidget {
  const StudentsTable({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<StudentsTable> createState() => _StudentsTableState();
}

class _StudentsTableState extends ConsumerState<StudentsTable> {
  static const _pageSize = 10;

  String _query = '';
  Standing? _status;
  ScoreBand? _band;
  _SortColumn _sort = _SortColumn.name;
  bool _ascending = true;
  int _page = 0;

  @override
  void didUpdateWidget(StudentsTable old) {
    super.didUpdateWidget(old);
    if (old.classId != widget.classId) _page = 0;
  }

  void _setSort(_SortColumn column) => setState(() {
        if (_sort == column) {
          _ascending = !_ascending;
        } else {
          _sort = column;
          // Numbers read best high-to-low first; names A–Z.
          _ascending = column == _SortColumn.name;
        }
        _page = 0;
      });

  List<Student> _apply(List<Student> input, DateTime now) {
    final q = _query.trim().toLowerCase();
    final out = input.where((s) {
      if (q.isNotEmpty && !'${s.name} ${s.studentNumber}'.toLowerCase().contains(q)) return false;
      if (_status != null && s.standing(now) != _status) return false;
      if (_band != null && s.band != _band) return false;
      return true;
    }).toList();

    int cmp(Student a, Student b) => switch (_sort) {
          _SortColumn.name => a.name.compareTo(b.name),
          _SortColumn.attendance => (a.attendanceRate ?? -1).compareTo(b.attendanceRate ?? -1),
          _SortColumn.completion => a.questProgress.compareTo(b.questProgress),
          _SortColumn.score => (a.averageScore ?? -1).compareTo(b.averageScore ?? -1),
          _SortColumn.missing => a.missingCount.compareTo(b.missingCount),
          _SortColumn.status => a.standing(now).index.compareTo(b.standing(now).index),
        };
    out.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final classId = widget.classId;
    final active = ref.watch(activeClassesProvider).valueOrNull;
    final byId = ref.watch(classByIdProvider);
    final students = classId != null
        ? ref.watch(classStudentsProvider(classId))
        : ref.watch(studentsProvider).whenData((l) => active == null
            ? l
            : l.where((s) => active.any((c) => c.id == s.classId)).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: AppDecorations.card,
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(builder: (context, c) {
            final search = SearchField(
              hint: 'Search students...',
              initialValue: _query,
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
            );
            final filters = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterDropdown<Standing?>(
                  value: _status,
                  options: [null, ...Standing.values],
                  labelOf: (s) => s?.label ?? 'All Statuses',
                  minWidth: 150,
                  onChanged: (s) => setState(() {
                    _status = s;
                    _page = 0;
                  }),
                ),
                FilterDropdown<ScoreBand?>(
                  value: _band,
                  options: [null, ...ScoreBand.values],
                  labelOf: (b) => b?.label ?? 'All Performance Levels',
                  minWidth: 220,
                  onChanged: (b) => setState(() {
                    _band = b;
                    _page = 0;
                  }),
                ),
              ],
            );
            if (c.maxWidth < 760) {
              return Column(children: [search, const SizedBox(height: 10), filters]);
            }
            return Row(children: [Expanded(child: search), const SizedBox(width: 12), filters]);
          }),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: AppDecorations.card,
          clipBehavior: Clip.antiAlias,
          child: AsyncValueView<List<Student>>(
            value: students,
            loadingHeight: 240,
            data: (list) {
              final now = DateTime.now();
              final rows = _apply(list, now);
              if (rows.isEmpty) {
                return EmptyNote(
                  list.isEmpty ? 'No students yet.' : 'No students match these filters.',
                  icon: Icons.groups_outlined,
                );
              }
              final pages = (rows.length / _pageSize).ceil();
              final page = math.min(_page, pages - 1);
              final start = page * _pageSize;
              final shown = rows.sublist(start, math.min(start + _pageSize, rows.length));

              return LayoutBuilder(builder: (context, box) {
                final wide = box.maxWidth >= 900;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) _HeaderRow(sort: _sort, ascending: _ascending, onSort: _setSort),
                    for (final s in shown)
                      wide
                          ? _WideRow(
                              student: s,
                              now: now,
                              classRoom: classId == null ? byId[s.classId] : null,
                            )
                          : _CompactRow(
                              student: s,
                              now: now,
                              classRoom: classId == null ? byId[s.classId] : null,
                            ),
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
              });
            },
          ),
        ),
      ],
    );
  }
}

const _flex = [26, 11, 15, 12, 11, 15, 20];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.sort, required this.ascending, required this.onSort});

  final _SortColumn sort;
  final bool ascending;
  final ValueChanged<_SortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    Widget cell(int i, String label, [_SortColumn? column]) => Expanded(
          flex: _flex[i],
          child: column == null
              ? Text(label, style: AppText.label)
              : InkWell(
                  onTap: () => onSort(column),
                  child: Row(
                    children: [
                      Flexible(child: Text(label, style: AppText.label)),
                      const SizedBox(width: 4),
                      Icon(
                        sort != column
                            ? Icons.unfold_more_rounded
                            : (ascending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded),
                        size: 15,
                        color: sort == column ? AppColors.primary : AppColors.muted,
                      ),
                    ],
                  ),
                ),
        );

    return Container(
      color: AppColors.chip.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          cell(0, 'Student', _SortColumn.name),
          cell(1, 'Attendance', _SortColumn.attendance),
          cell(2, 'Quest Completion', _SortColumn.completion),
          cell(3, 'Average Score', _SortColumn.score),
          cell(4, 'Missing Work', _SortColumn.missing),
          cell(5, 'Status', _SortColumn.status),
          cell(6, 'Actions'),
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.student, this.classRoom});

  final Student student;
  final ClassRoom? classRoom;

  @override
  Widget build(BuildContext context) {
    final sub = [student.numberLabel, if (classRoom != null) classRoom!.name]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return Row(
      children: [
        InitialsAvatar(
          initials: student.firstName.isEmpty ? '?' : student.firstName[0],
          tone: toneForName(student.name),
          size: 42,
          imageUrl: student.photoUrl,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
              if (sub.isNotEmpty)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () => showStudentPanel(context, student),
          child: const Text('View Profile'),
        ),
        const SizedBox(width: 8),
        MoreMenu<String>(
          items: [
            menuItem('remind', Icons.send_outlined, 'Send reminder'),
            menuItem('remedial', Icons.assignment_outlined, 'Assign remedial quest'),
            menuItem('class', Icons.menu_book_outlined, 'Open class'),
          ],
          onSelected: (v) {
            switch (v) {
              case 'remind':
                showSendReminder(context, student);
              case 'remedial':
                showClassworkForm(context, type: ClassworkType.quest, assignTo: student);
              case 'class':
                context.go(Routes.classDetail(student.classId));
            }
          },
        ),
      ],
    );
  }
}

class _WideRow extends StatelessWidget {
  const _WideRow({required this.student, required this.now, this.classRoom});

  final Student student;
  final DateTime now;
  final ClassRoom? classRoom;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final standing = s.standing(now);
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: _flex[0], child: _NameCell(student: s, classRoom: classRoom)),
          Expanded(flex: _flex[1], child: Text(percent(s.attendanceRate), style: AppText.body)),
          Expanded(
            flex: _flex[2],
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(percent(s.questProgress),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  ProgressBar(value: s.questProgress, height: 7),
                ],
              ),
            ),
          ),
          Expanded(flex: _flex[3], child: Text(percent(s.averageScore), style: AppText.body)),
          Expanded(
            flex: _flex[4],
            child: Text('${s.missingCount}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: s.missingCount > 0 ? AppColors.red : AppColors.ink,
                )),
          ),
          Expanded(
            flex: _flex[5],
            child: Align(
              alignment: Alignment.centerLeft,
              child: Pill(standing.label, tone: standing.tone, icon: standing.icon),
            ),
          ),
          Expanded(
            flex: _flex[6],
            child: Align(alignment: Alignment.centerLeft, child: _RowActions(student: s)),
          ),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.student, required this.now, this.classRoom});

  final Student student;
  final DateTime now;
  final ClassRoom? classRoom;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final standing = s.standing(now);
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _NameCell(student: s, classRoom: classRoom)),
              Pill(standing.label, tone: standing.tone, icon: standing.icon),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              Text('Attendance ${percent(s.attendanceRate)}', style: AppText.meta),
              Text('Quests ${percent(s.questProgress)}', style: AppText.meta),
              Text('Avg ${percent(s.averageScore)}', style: AppText.meta),
              Text('Missing ${s.missingCount}',
                  style: AppText.meta.copyWith(color: s.missingCount > 0 ? AppColors.red : null)),
            ],
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: _RowActions(student: s)),
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
    Widget box(Widget child, {VoidCallback? onTap, bool selected = false}) => Padding(
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
              child: SizedBox(width: 36, height: 36, child: Center(child: child)),
            ),
          ),
        );

    final first = math.max(0, math.min(page - 2, pages - 5));
    final last = math.min(pages, first + 5);

    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: [
          Text('Showing ${start + 1}–$end of $total students', style: AppText.meta),
          if (pages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                box(const Icon(Icons.chevron_left_rounded, size: 20),
                    onTap: page > 0 ? () => onPage(page - 1) : null),
                for (var p = first; p < last; p++)
                  box(
                    Text('${p + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p == page ? Colors.white : AppColors.ink)),
                    selected: p == page,
                    onTap: () => onPage(p),
                  ),
                box(const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: page < pages - 1 ? () => onPage(page + 1) : null),
              ],
            ),
        ],
      ),
    );
  }
}
