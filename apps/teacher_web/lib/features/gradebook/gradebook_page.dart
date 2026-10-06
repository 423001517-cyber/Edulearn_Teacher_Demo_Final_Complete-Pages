import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/gradebook_providers.dart';
import '../../providers/stream_providers.dart';
import '../classwork/classwork_details_popover.dart';
import '../classwork/classwork_dialogs.dart';
import '../shell/top_bar.dart';
import '../stream/stream_page.dart' show PageClassSelector;
import '../stream/stream_widgets.dart';
import '../submissions/submission_dialogs.dart';
import 'gradebook_dialogs.dart';

enum _StudentFilter {
  all('All status'),
  missing('Missing work'),
  needsGrading('Needs grading'),
  belowPassing('Below passing'),
  excluded('Excluded');

  const _StudentFilter(this.label);
  final String label;
}

/// `/gradebook?classId=` — view, manage and export student grades.
class GradebookPage extends ConsumerWidget {
  const GradebookPage({super.key, this.classId});

  final String? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassRoom?>(
      value: ref.watch(streamClassProvider(classId)),
      data: (c) {
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Gradebook'),
            children: [EmptyNote('No classes yet.')],
          );
        }
        return PageScaffold(
          header: PageHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Gradebook',
            subtitle: 'View, manage, and export student grades.',
            actions: PageClassSelector(current: c, onChanged: (x) => goTo(Routes.gradebook(classId: x.id))),
          ),
          children: [_Board(key: ValueKey(c.id), classRoom: c)],
        );
      },
    );
  }
}

Future<void> _exportCsv(WidgetRef ref, ReportTable table, String name) async {
  showToast('Preparing CSV…');
  try {
    final url = await ref.read(reportExporterProvider).exportCsv(table: table, fileName: fileSlug(name));
    final uri = Uri.parse(url);
    if (kIsWeb) {
      showToast('CSV is ready', actionLabel: 'Open', onAction: () => launchUrl(uri));
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    showToast('Couldn’t export: $e');
  }
}

String _pct(double? v) => v == null ? '—' : '${v.round()}%';

class _Board extends ConsumerStatefulWidget {
  const _Board({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  static const _pageSize = 8;
  int? _quarter = schoolQuarter(DateTime.now());
  String? _topic;
  _StudentFilter _filter = _StudentFilter.all;
  String _query = '';
  int _page = 0;

  ClassRoom get _class => widget.classRoom;

  @override
  Widget build(BuildContext context) {
    final dataValue = ref.watch(gradebookProvider((_class.id, _quarter, _topic)));
    final settings = ref.watch(gradebookSettingsProvider(_class.id)).valueOrNull ?? const GradebookSettings();
    final topics = ref.watch(gradebookTopicsProvider(_class.id));
    final data = dataValue.valueOrNull;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(children: [
        StatCard(
          icon: Icons.bar_chart_rounded,
          tone: Tone.blue,
          label: 'Class average',
          value: dataValue.whenData((d) => _pct(d.classAverage)),
          caption: 'Overall grade',
        ),
        StatCard(
          icon: Icons.emoji_events_rounded,
          tone: Tone.green,
          label: 'Highest score',
          value: dataValue.whenData((d) => _pct(d.highest)),
          caption: 'Top overall grade',
        ),
        StatCard(
          icon: Icons.priority_high_rounded,
          tone: Tone.red,
          label: 'Missing grades',
          value: dataValue.whenData((d) => '${d.missing}'),
          caption: 'Past due, nothing turned in',
        ),
        StatCard(
          icon: Icons.description_rounded,
          tone: Tone.amber,
          label: 'Needs grading',
          value: dataValue.whenData((d) => '${d.needsGrading}'),
          caption: 'Turned in, not scored',
        ),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: SearchField(hint: 'Search student', onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              })),
        ),
        FilterDropdown<int?>(
          value: _quarter,
          options: const [null, 1, 2, 3, 4],
          labelOf: (q) => q == null ? 'All quarters' : 'Quarter $q',
          minWidth: 140,
          onChanged: (q) => setState(() => _quarter = q),
        ),
        FilterDropdown<String?>(
          value: _topic,
          options: [null, for (final t in topics) t.id],
          labelOf: (id) => id == null ? 'All topics' : topics.firstWhere((t) => t.id == id).name,
          minWidth: 160,
          onChanged: (t) => setState(() => _topic = t),
        ),
        FilterDropdown<_StudentFilter>(
          value: _filter,
          options: _StudentFilter.values,
          labelOf: (f) => f.label,
          minWidth: 150,
          onChanged: (f) => setState(() {
            _filter = f;
            _page = 0;
          }),
        ),
        OutlinedButton.icon(
          onPressed: () => showGradeSettingsDialog(context, _class, settings),
          icon: const Icon(Icons.settings_outlined, size: 19),
          label: const Text('Grade settings'),
        ),
        OutlinedButton.icon(
          onPressed: data == null ? null : () => _exportAll(data, settings),
          icon: const Icon(Icons.download_rounded, size: 19),
          label: const Text('Export gradebook'),
        ),
      ]),
      const SizedBox(height: 16),
      TwoColumn(
        leftFlex: 8,
        rightFlex: 3,
        left: [
          Container(
            decoration: AppDecorations.card,
            padding: const EdgeInsets.all(18),
            child: AsyncValueView<GradebookData>(
              value: dataValue,
              loadingHeight: 320,
              data: (d) => _grid(d, settings),
            ),
          ),
        ],
        right: [_Distribution(data: data, settings: settings), _Scale(settings: settings, classId: _class.id)],
      ),
    ]);
  }

  List<Student> _filtered(GradebookData d, GradebookSettings s) {
    final q = _query.trim().toLowerCase();
    final now = DateTime.now();
    return d.students.where((st) {
      if (q.isNotEmpty && !st.name.toLowerCase().contains(q)) return false;
      final mine = d.cells[st.id] ?? const <String, Submission>{};
      return switch (_filter) {
        _StudentFilter.all => true,
        _StudentFilter.missing => d.columns.any((w) => mine[w.id] == null && w.dueDate.isBefore(now) &&
            (w.assignedStudentIds.isEmpty || w.assignedStudentIds.contains(st.id))),
        _StudentFilter.needsGrading => mine.values.any((x) => x.score == null),
        _StudentFilter.belowPassing => (d.overall[st.id] ?? 100) < s.passingGrade,
        _StudentFilter.excluded => s.excludedStudents.contains(st.id),
      };
    }).toList();
  }

  Widget _grid(GradebookData d, GradebookSettings s) {
    final students = _filtered(d, s);
    final pages = (students.length / _pageSize).ceil().clamp(1, 1 << 20);
    final page = _page.clamp(0, pages - 1);
    final shown = students.skip(page * _pageSize).take(_pageSize).toList();
    const studentW = 220.0;
    const overallW = 96.0;
    const colW = 124.0;
    final width = studentW + overallW + colW * d.columns.length;
    final now = DateTime.now();

    Widget headerCell(ClassworkItem w) => SizedBox(
          width: colW,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                _ColumnMenu(item: w, classRoom: _class, settings: s, data: d),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(w.type.icon, size: 16, color: w.type.tone.fg),
                const SizedBox(width: 4),
                Text('${w.points} pts', style: AppText.meta.copyWith(fontSize: 11.5)),
                if (s.hiddenColumns.contains(w.id)) ...[
                  const SizedBox(width: 4),
                  const Tooltip(message: 'Hidden from overall grade', child: Icon(Icons.visibility_off_outlined, size: 15)),
                ],
              ]),
              Text('Due ${dayMonth(w.dueDate)}', style: AppText.meta.copyWith(fontSize: 11)),
            ]),
          ),
        );

    Widget cell(ClassworkItem w, Student st) {
      final sub = d.cells[st.id]?[w.id];
      final assigned = w.assignedStudentIds.isEmpty || w.assignedStudentIds.contains(st.id);
      Widget content;
      if (!assigned) {
        content = Text('n/a', style: AppText.meta);
      } else if (sub == null) {
        content = w.dueDate.isBefore(now) ? const Pill('Missing', tone: Tone.red) : Text('–', style: AppText.meta);
      } else if (sub.score == null) {
        content = const Pill('To grade', tone: Tone.amber);
      } else if (sub.status == SubmissionStatus.pending) {
        content = Pill('${sub.score}/${w.points} draft', tone: Tone.blue);
      } else {
        content = Text('${sub.score}/${w.points}', style: const TextStyle(fontWeight: FontWeight.w600));
      }
      return SizedBox(
        width: colW,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: assigned ? () => showGradeCellDialog(context, item: w, student: st, existing: sub) : null,
          child: Container(height: 46, alignment: Alignment.center, child: content),
        ),
      );
    }

    Widget overall(Student st) {
      if (s.excludedStudents.contains(st.id)) return const Pill('Excluded', tone: Tone.neutral);
      final p = d.overall[st.id];
      if (p == null) return Text('—', style: AppText.meta);
      final g = s.letterFor(p);
      final color = g == null ? AppColors.muted : Color(g.color);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(
          s.showLetters && g != null ? '${_pct(p)} ${g.letter}' : _pct(p),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: color),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: '${_class.name} – ${_class.subject}', style: AppText.sectionTitle.copyWith(fontSize: 18)),
        TextSpan(text: '  •  ${d.students.length} students', style: AppText.meta),
      ])),
      Text('Click a grade to edit. Changes save automatically.', style: AppText.meta.copyWith(fontSize: 12.5)),
      const SizedBox(height: 12),
      if (d.columns.isEmpty)
        const EmptyNote('No graded classwork in this quarter yet.', icon: Icons.grid_view_rounded)
      else
        Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: width,
              child: Column(children: [
                Container(
                  color: AppColors.chip.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: studentW, child: Padding(padding: const EdgeInsets.only(left: 10, top: 6), child: Text('Student', style: AppText.label))),
                    SizedBox(width: overallW, child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Overall\nGrade', style: AppText.label))),
                    for (final w in d.columns) headerCell(w),
                  ]),
                ),
                for (final st in shown)
                  Container(
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                    child: Row(children: [
                      SizedBox(
                        width: studentW,
                        child: Row(children: [
                          const SizedBox(width: 8),
                          PersonAvatar(name: st.name, size: 32),
                          const SizedBox(width: 8),
                          Expanded(child: Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          if (s.notes.containsKey(st.id))
                            Tooltip(message: s.notes[st.id]!, child: const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.amber)),
                          _StudentMenu(student: st, classRoom: _class, settings: s, data: d),
                        ]),
                      ),
                      SizedBox(width: overallW, child: Align(alignment: Alignment.centerLeft, child: overall(st))),
                      for (final w in d.columns) cell(w, st),
                    ]),
                  ),
                Container(
                  color: AppColors.primarySoft.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    const SizedBox(width: studentW, child: Padding(padding: EdgeInsets.only(left: 10), child: Text('Class average', style: TextStyle(fontWeight: FontWeight.w700)))),
                    SizedBox(width: overallW, child: Text(_pct(d.classAverage), style: const TextStyle(fontWeight: FontWeight.w700))),
                    for (final w in d.columns)
                      SizedBox(
                        width: colW,
                        child: Text(
                          d.columnAverage[w.id] == null ? '—' : '${d.columnAverage[w.id]!.toStringAsFixed(1)}/${w.points}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(students.isEmpty ? '0 of 0' : '${page * _pageSize + 1}–${page * _pageSize + shown.length} of ${students.length}',
            style: AppText.meta),
        IconButton(
          tooltip: 'Previous page',
          onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: page < pages - 1 ? () => setState(() => _page = page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
    ]);
  }

  void _exportAll(GradebookData d, GradebookSettings s) => _exportCsv(
        ref,
        ReportTable(
          ['Student', 'Overall', if (s.showLetters) 'Letter', for (final w in d.columns) '${w.title} (${w.points})'],
          [
            for (final st in d.students)
              [
                st.name,
                _pct(d.overall[st.id]),
                if (s.showLetters) d.overall[st.id] == null ? '' : (s.letterFor(d.overall[st.id]!)?.letter ?? ''),
                for (final w in d.columns) '${d.cells[st.id]?[w.id]?.score ?? ''}',
              ],
          ],
        ),
        '${_class.name} gradebook',
      );
}

/// ⋮ on a column header.
class _ColumnMenu extends ConsumerWidget {
  const _ColumnMenu({required this.item, required this.classRoom, required this.settings, required this.data});

  final ClassworkItem item;
  final ClassRoom classRoom;
  final GradebookSettings settings;
  final GradebookData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = settings.hiddenColumns.contains(item.id);
    return MoreMenu<String>(
        items: [
          menuItem('view', Icons.visibility_outlined, 'View classwork'),
          menuItem('subs', Icons.inbox_outlined, 'View submissions'),
          menuItem('edit', Icons.edit_outlined, 'Edit points and due date'),
          menuItem('graded', Icons.task_alt_rounded, 'Mark all as graded'),
          menuItem('download', Icons.download_rounded, 'Download scores'),
          menuItem('link', Icons.link_rounded, 'Copy classwork link'),
          menuItem('hide', hidden ? Icons.visibility_rounded : Icons.visibility_off_outlined,
              hidden ? 'Include in overall grade' : 'Hide from overall grade'),
          const PopupMenuDivider(),
          menuItem('delete', Icons.delete_outline_rounded, 'Delete grade column', destructive: true),
        ],
        onSelected: (v) async {
          final repo = ref.read(gradebookRepositoryProvider);
          switch (v) {
            case 'view':
              await showClassworkPreview(context, item);
            case 'subs':
              goTo(Routes.submissions(classId: item.classId, item: item.id));
            case 'edit':
              await showPointsDueDialog(context, item);
            case 'graded':
              final subs = [for (final st in data.students) if (data.cells[st.id]?[item.id] != null) data.cells[st.id]![item.id]!];
              final n = await ref.read(submissionsRepositoryProvider).returnMany(subs);
              showToast(n == 0 ? 'Everything is already graded' : '$n grade${n == 1 ? '' : 's'} returned');
            case 'download':
              await _exportCsv(
                ref,
                ReportTable(['Student', 'Score', 'Max', 'Feedback'], [
                  for (final st in data.students)
                    [st.name, '${data.cells[st.id]?[item.id]?.score ?? ''}', '${item.points}', data.cells[st.id]?[item.id]?.privateFeedback ?? ''],
                ]),
                '${classRoom.name} ${item.title} scores',
              );
            case 'link':
              await copyClassworkLink(classId: item.classId, itemId: item.id);
            case 'hide':
              final list = [...settings.hiddenColumns];
              if (hidden) {
                list.remove(item.id);
              } else {
                list.add(item.id);
              }
              await repo.saveSettings(classRoom.id, settings.copyWith(hiddenColumns: list));
              showToast(hidden ? 'Included in the overall grade' : 'Hidden from the overall grade');
            case 'delete':
              final ok = await confirmAction(
                context,
                title: 'Delete grade column?',
                message: 'This will remove grades for “${item.title}” from this view. Student submissions will remain '
                    'in Classwork and are not deleted.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (!ok) return;
              await repo.saveSettings(classRoom.id, settings.copyWith(removedColumns: [...settings.removedColumns, item.id]));
              showToast('Column removed from the gradebook');
          }
        },
    );
  }
}

/// ⋮ next to a student's name.
class _StudentMenu extends ConsumerWidget {
  const _StudentMenu({required this.student, required this.classRoom, required this.settings, required this.data});

  final Student student;
  final ClassRoom classRoom;
  final GradebookSettings settings;
  final GradebookData data;

  List<List<String>> _rows() => [
        for (final w in data.columns)
          [
            w.title,
            w.type.shortLabel,
            fullDate(w.dueDate),
            '${data.cells[student.id]?[w.id]?.score ?? ''}',
            '${w.points}',
            data.cells[student.id]?[w.id] == null
                ? (w.dueDate.isBefore(DateTime.now()) ? 'Missing' : 'Not due')
                : (data.cells[student.id]![w.id]!.status == SubmissionStatus.returned ? 'Graded' : 'Turned in'),
          ],
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excluded = settings.excludedStudents.contains(student.id);
    return MoreMenu<String>(
      items: [
        menuItem('details', Icons.person_outline_rounded, 'View student details'),
        menuItem('subs', Icons.list_alt_rounded, 'View all submissions'),
        menuItem('report', Icons.download_rounded, 'Download grade report'),
        menuItem('remind', Icons.notifications_none_rounded, 'Send reminder notification'),
        menuItem('note', Icons.sticky_note_2_outlined, 'Add private teacher note'),
        menuItem('exclude', excluded ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
            excluded ? 'Include in overall calculation' : 'Exclude from overall calculation'),
      ],
      onSelected: (v) async {
        switch (v) {
          case 'details':
            goTo(Routes.students(classId: classRoom.id, studentId: student.id));
          case 'subs':
            await showDialog<void>(
              context: context,
              builder: (ctx) => AppDialog(
                maxWidth: 560,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PanelHeader(title: student.name, subtitle: 'All graded classwork · overall ${_pct(data.overall[student.id])}'),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final r in _rows())
                        ListTile(dense: true, title: Text(r[0]), subtitle: Text('${r[1]} · Due ${r[2]}'),
                            trailing: Text(r[3].isEmpty ? r[5] : '${r[3]}/${r[4]}')),
                    ]),
                  ),
                ]),
              ),
            );
          case 'report':
            await _exportCsv(ref, ReportTable(['Classwork', 'Type', 'Due', 'Score', 'Max', 'Status'], _rows()),
                '${student.name} grade report');
          case 'remind':
            final now = DateTime.now();
            final missing = data.columns.where((w) => data.cells[student.id]?[w.id] == null && w.dueDate.isBefore(now)).toList();
            if (missing.isEmpty) {
              showToast('${student.name} has no missing work. 🎉');
              return;
            }
            await showReminderPanel(context, student: student, item: missing.last, className: classRoom.name);
          case 'note':
            await showNoteDialog(context, classRoom.id, student, settings);
          case 'exclude':
            final list = [...settings.excludedStudents];
            if (excluded) {
              list.remove(student.id);
            } else {
              list.add(student.id);
            }
            await ref.read(gradebookRepositoryProvider).saveSettings(classRoom.id, settings.copyWith(excludedStudents: list));
            showToast(excluded ? '${student.name} counts toward averages again' : '${student.name} left out of class averages');
        }
      },
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.data, required this.settings});

  final GradebookData? data;
  final GradebookSettings settings;

  @override
  Widget build(BuildContext context) {
    final dist = data?.distribution ?? const <String, int>{};
    final most = dist.values.fold<int>(1, (m, v) => v > m ? v : m);
    return SectionCard(
      title: 'Grade distribution',
      child: Column(children: [
        for (final g in settings.scale)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              _LetterBox(g),
              const SizedBox(width: 10),
              Expanded(child: ProgressBar(value: (dist[g.letter] ?? 0) / most, color: Color(g.color), height: 9)),
              const SizedBox(width: 10),
              SizedBox(width: 24, child: Text('${dist[g.letter] ?? 0}', textAlign: TextAlign.right)),
            ]),
          ),
      ]),
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale({required this.settings, required this.classId});

  final GradebookSettings settings;
  final String classId;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Grading scale',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final g in settings.scale)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                _LetterBox(g),
                const SizedBox(width: 12),
                Text(g.min == 0 && g != settings.scale.first ? 'Below ${g.max + 1}' : '${g.min} – ${g.max}'),
              ]),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showScaleDialog(context, classId, settings),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Edit scale'),
          ),
        ]),
      );
}

class _LetterBox extends StatelessWidget {
  const _LetterBox(this.level);

  final GradeLevel level;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Color(level.color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(level.letter, style: TextStyle(fontWeight: FontWeight.w800, color: Color(level.color))),
      );
}
