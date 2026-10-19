import 'dart:math' as math;

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/stream_providers.dart';
import '../reports/report_actions.dart' show runExport;
import '../shell/top_bar.dart';
import '../stream/stream_page.dart' show PageClassSelector;
import 'attendance_widgets.dart';

/// `/attendance?classId=&date=` — take daily attendance and see patterns.
class AttendancePage extends ConsumerWidget {
  const AttendancePage({super.key, this.classId, this.date});

  final String? classId;
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassRoom?>(
      value: ref.watch(streamClassProvider(classId)),
      data: (c) {
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Attendance'),
            children: [EmptyNote('No classes yet — attendance opens once a class is assigned to you.')],
          );
        }
        final today = startOfDay(DateTime.now());
        final day = startOfDay(date ?? (isWeekend(today) ? nextSchoolDay(today, -1) : today));
        return PageScaffold(
          header: PageHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Attendance',
            subtitle: 'Take daily attendance and see attendance patterns for each class.',
            actions: PageClassSelector(
              current: c,
              onChanged: (x) => goTo(Routes.attendance(classId: x.id, date: date)),
            ),
          ),
          children: [_Board(key: ValueKey('${c.id}_${dateKey(day)}'), classRoom: c, date: day)],
        );
      },
    );
  }
}

class _Board extends ConsumerStatefulWidget {
  const _Board({super.key, required this.classRoom, required this.date});

  final ClassRoom classRoom;
  final DateTime date;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  static const _pageSize = 10;

  /// Marks and notes changed since the last save.
  final Map<String, AttendanceMark> _edits = {};
  final Map<String, String> _noteEdits = {};
  final Map<String, DateTime> _timeEdits = {};
  bool _saving = false;
  bool _justSaved = false;
  String _query = '';
  AttendanceMark? _filter;
  int _page = 0;
  late DateTime _calendarMonth = DateTime(widget.date.year, widget.date.month);

  ClassRoom get _class => widget.classRoom;
  DateTime get _date => widget.date;
  bool get _dirty => _edits.isNotEmpty || _noteEdits.isNotEmpty;
  bool get _isFuture => _date.isAfter(startOfDay(DateTime.now()));
  bool get _editable => !_isFuture && !isWeekend(_date);

  AttendanceDay? _savedDay(List<AttendanceDay> days) {
    for (final d in days) {
      if (sameDay(d.date, _date)) return d;
    }
    return null;
  }

  AttendanceMark _markOf(String id, AttendanceDay? saved) =>
      _edits[id] ?? saved?.marks[id] ?? AttendanceMark.present;

  String _noteOf(String id, AttendanceDay? saved) => _noteEdits[id] ?? saved?.notes[id] ?? '';

  DateTime? _timeOf(String id, AttendanceDay? saved) {
    final m = _markOf(id, saved);
    if (!m.attended) return null;
    return _timeEdits[id] ?? saved?.times[id];
  }

  void _setMark(String id, AttendanceMark m, AttendanceDay? saved) {
    setState(() {
      _justSaved = false;
      if ((saved?.marks[id] ?? AttendanceMark.present) == m) {
        _edits.remove(id);
      } else {
        _edits[id] = m;
      }
      final today = sameDay(_date, DateTime.now());
      if (m.attended && today && saved?.times[id] == null) {
        _timeEdits[id] = DateTime.now();
      } else if (!m.attended) {
        _timeEdits.remove(id);
      }
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirmAction(
      context,
      title: 'Discard changes?',
      message: 'You changed attendance for ${shortDate(_date)} but didn’t save it.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  Future<void> _goToDate(DateTime d) async {
    if (!await _confirmDiscard()) return;
    goTo(Routes.attendance(classId: _class.id, date: d));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = startOfDay(now);
    var initial = _date.isAfter(today) ? today : _date;
    if (isWeekend(initial)) initial = nextSchoolDay(initial, -1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 6, 1),
      lastDate: today,
      selectableDayPredicate: (d) => !isWeekend(d),
      helpText: 'Choose a school day',
    );
    if (picked != null && !sameDay(picked, _date)) await _goToDate(picked);
  }

  Future<void> _save(List<Student> roster, AttendanceDay? saved) async {
    setState(() => _saving = true);
    final marks = {for (final s in roster) s.id: _markOf(s.id, saved)};
    final notes = <String, String>{
      for (final s in roster)
        if (_noteOf(s.id, saved).trim().isNotEmpty) s.id: _noteOf(s.id, saved).trim(),
    };
    final times = <String, DateTime>{
      for (final s in roster)
        if (_timeOf(s.id, saved) case final t?) s.id: t,
    };
    try {
      await ref.read(attendanceRepositoryProvider).saveDay(
            AttendanceDay(classId: _class.id, date: _date, marks: marks, notes: notes, times: times),
          );
      if (!mounted) return;
      setState(() {
        _edits.clear();
        _noteEdits.clear();
        _timeEdits.clear();
        _saving = false;
        _justSaved = true;
      });
      showToast('Attendance saved for ${shortDate(_date)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast('Couldn’t save attendance: $e');
    }
  }

  void _markAllPresent(List<Student> roster, AttendanceDay? saved) {
    for (final s in roster) {
      if (_markOf(s.id, saved) != AttendanceMark.present) _setMark(s.id, AttendanceMark.present, saved);
    }
  }

  Future<void> _editNote(Student s, AttendanceDay? saved) async {
    final result = await showNoteDialog(context, student: s, date: _date, initial: _noteOf(s.id, saved));
    if (result == null || !mounted) return;
    setState(() {
      _justSaved = false;
      if (result == (saved?.notes[s.id] ?? '')) {
        _noteEdits.remove(s.id);
      } else {
        _noteEdits[s.id] = result;
      }
    });
  }

  Future<void> _export(List<Student> roster, List<AttendanceDay> days) {
    final month = daysInMonth(days, _date)..sort((a, b) => a.date.compareTo(b.date));
    final tally = tallyByStudent(month);
    final label = '${monthAbbr(_date)} ${_date.year}';
    return runExport(
      ref,
      'attendance CSV',
      (x) => x.exportCsv(
        fileName: fileSlug('${_class.name} attendance $label'),
        table: ReportTable(
          ['Student', for (final d in month) dayMonth(d.date), 'Present', 'Late', 'Absent', 'Excused', 'Rate'],
          [
            for (final s in roster)
              [
                s.name,
                for (final d in month) d.marks[s.id]?.letter ?? '',
                '${tally[s.id]?.presentDays ?? 0}',
                '${tally[s.id]?.lateDays ?? 0}',
                '${tally[s.id]?.absentDays ?? 0}',
                '${tally[s.id]?.excusedDays ?? 0}',
                percent(tally[s.id]?.rate),
              ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysValue = ref.watch(attendanceMonthProvider((_class.id, DateTime(_date.year, _date.month))));
    final rosterValue = ref.watch(classStudentsProvider(_class.id));

    return AsyncValueView<List<Student>>(
      value: rosterValue,
      loadingHeight: 320,
      data: (rosterRaw) {
        final roster = [...rosterRaw]..sort((a, b) => a.name.compareTo(b.name));
        final days = daysValue.valueOrNull ?? const <AttendanceDay>[];
        final saved = _savedDay(days);
        final counts = {for (final m in AttendanceMark.values) m: 0};
        for (final s in roster) {
          final m = _markOf(s.id, saved);
          counts[m] = counts[m]! + 1;
        }
        final monthTally = tallyByStudent(daysInMonth(days, _date));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(roster, saved, days),
            if (_editable && saved == null && daysValue.hasValue) ...[
              const SizedBox(height: 14),
              const InfoStrip(
                icon: Icons.info_outline_rounded,
                text: 'Attendance for this day hasn’t been saved yet. Everyone starts as Present — '
                    'mark who is late or absent, then press Save attendance.',
              ),
            ],
            if (!_editable) ...[
              const SizedBox(height: 14),
              InfoStrip(
                icon: Icons.event_busy_rounded,
                text: isWeekend(_date) ? 'No classes on weekends.' : 'You can’t take attendance for a future date.',
              ),
            ],
            const SizedBox(height: 20),
            ResponsiveGrid(
              maxColumns: 4,
              minItemWidth: 200,
              children: [
                for (final m in AttendanceMark.values)
                  StatCard(
                    icon: m.icon,
                    tone: m.tone,
                    label: m.label,
                    value: AsyncData('${counts[m]}'),
                    caption: switch (m) {
                      AttendanceMark.present => 'of ${roster.length} students',
                      AttendanceMark.late => 'Arrived after the bell',
                      AttendanceMark.absent => 'Without a parent’s note',
                      AttendanceMark.excused => 'With a parent’s note',
                    },
                    onTap: () => setState(() {
                      _filter = _filter == m ? null : m;
                      _page = 0;
                    }),
                    selected: _filter == m,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TwoColumn(
              leftFlex: 2,
              rightFlex: 1,
              left: [_classList(roster, saved, monthTally, counts)],
              right: [
                AttendanceMonthCard(
                  classId: _class.id,
                  month: _calendarMonth,
                  selected: _date,
                  onMonth: (m) => setState(() => _calendarMonth = m),
                  onDay: _goToDate,
                ),
                FollowUpCard(roster: roster, tally: monthTally, month: _date),
                WeeklyAttendanceCard(days: days, date: _date),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(List<Student> roster, AttendanceDay? saved, List<AttendanceDay> days) {
    final today = startOfDay(DateTime.now());
    final isToday = sameDay(_date, today);
    final next = nextSchoolDay(_date, 1);
    Widget square(IconData icon, String tip, VoidCallback? onTap) => Tooltip(
          message: tip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: Colors.white),
              child: Icon(icon, size: 20),
            ),
          ),
        );

    final status = _saving
        ? 'Saving…'
        : _dirty
            ? 'Unsaved changes'
            : _justSaved
                ? 'Saved'
                : saved?.savedAt != null
                    ? 'Saved ${timeAgo(saved!.savedAt!)}'
                    : null;

    return Wrap(
      spacing: 10,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            square(Icons.chevron_left_rounded, 'Previous school day', () => _goToDate(nextSchoolDay(_date, -1))),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                label: Text(longDate(_date), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            square(Icons.chevron_right_rounded, 'Next school day',
                next.isAfter(today) ? null : () => _goToDate(next)),
            if (isToday)
              const Pill('Today', tone: Tone.green)
            else
              TextButton(onPressed: () => _goToDate(isWeekend(today) ? nextSchoolDay(today, -1) : today), child: const Text('Go to today')),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (status != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_dirty ? Icons.edit_note_rounded : Icons.check_circle_rounded,
                      size: 18, color: _dirty ? AppColors.amber : AppColors.primary),
                  const SizedBox(width: 6),
                  Text(status,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _dirty ? const Color(0xFF8A5700) : AppColors.primary)),
                ],
              ),
            OutlinedButton.icon(
              onPressed: _editable ? () => _markAllPresent(roster, saved) : null,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all present'),
            ),
            OutlinedButton.icon(
              onPressed: () => _export(roster, days),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export month'),
            ),
            FilledButton(
              onPressed: _editable && !_saving && (_dirty || saved == null) ? () => _save(roster, saved) : null,
              child: Text(_saving ? 'Saving…' : 'Save attendance'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _classList(
    List<Student> roster,
    AttendanceDay? saved,
    Map<String, AttendanceTally> monthTally,
    Map<AttendanceMark, int> counts,
  ) {
    final q = _query.trim().toLowerCase();
    final rows = roster.where((s) {
      if (q.isNotEmpty && !'${s.name} ${s.studentNumber}'.toLowerCase().contains(q)) return false;
      if (_filter != null && _markOf(s.id, saved) != _filter) return false;
      return true;
    }).toList();
    final pages = math.max(1, (rows.length / _pageSize).ceil());
    final page = math.min(_page, pages - 1);
    final start = page * _pageSize;
    final shown = rows.sublist(start, math.min(start + _pageSize, rows.length));
    final inClass = counts[AttendanceMark.present]! + counts[AttendanceMark.late]!;
    final counted = roster.length - counts[AttendanceMark.excused]!;

    return SectionCard(
      title: '${_class.name} · Class list',
      icon: Icons.fact_check_outlined,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$inClass of ${roster.length} in class${counted > 0 ? ' (${percent(inClass / counted)})' : ''}'
              '${_editable ? ' · tap a letter to change a status' : ''}',
              style: AppText.meta,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: SearchField(
                    hint: 'Search student',
                    initialValue: _query,
                    onChanged: (v) => setState(() {
                      _query = v;
                      _page = 0;
                    }),
                  ),
                ),
                FilterDropdown<AttendanceMark?>(
                  value: _filter,
                  options: const [null, ...AttendanceMark.values],
                  labelOf: (m) => m?.label ?? 'All statuses',
                  minWidth: 150,
                  onChanged: (m) => setState(() {
                    _filter = m;
                    _page = 0;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const MarkLegend(),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              EmptyNote(roster.isEmpty ? 'No students in this class yet.' : 'No students match these filters.',
                  icon: Icons.groups_outlined)
            else
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 700;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) const AttendanceHeaderRow(),
                    for (final s in shown)
                      AttendanceRow(
                        student: s,
                        mark: _markOf(s.id, saved),
                        changed: _edits.containsKey(s.id) || _noteEdits.containsKey(s.id),
                        time: _timeOf(s.id, saved),
                        note: _noteOf(s.id, saved),
                        month: monthTally[s.id],
                        wide: wide,
                        enabled: _editable,
                        onMark: (m) => _setMark(s.id, m, saved),
                        onNote: () => _editNote(s, saved),
                      ),
                  ],
                );
              }),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows.isEmpty ? '0 students' : '${start + 1}–${start + shown.length} of ${rows.length} students',
                      style: AppText.meta,
                    ),
                  ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
