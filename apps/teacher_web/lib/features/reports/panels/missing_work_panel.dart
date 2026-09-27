import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/navigation.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/reports_providers.dart';
import '../report_actions.dart';
import 'panel_frame.dart';

enum _StatusFilter {
  all('All'),
  overdue('Overdue'),
  dueSoon('Due soon');

  const _StatusFilter(this.label);
  final String label;
}

class MissingWorkPanel extends ConsumerStatefulWidget {
  const MissingWorkPanel({super.key, required this.classRoom, required this.period});

  final ClassRoom classRoom;
  final ReportPeriod period;

  @override
  ConsumerState<MissingWorkPanel> createState() => _MissingWorkPanelState();
}

class _MissingWorkPanelState extends ConsumerState<MissingWorkPanel> {
  String? _studentId; // null = All Students
  _StatusFilter _status = _StatusFilter.overdue;
  final _selected = <String>{};
  bool _sending = false;

  String _message(MissingWork m) {
    final first = m.studentName.split(' ').first;
    return 'Hi $first! "${m.classworkTitle}" was due ${dayMonth(m.dueDate)}. '
        'Please submit it as soon as you can.';
  }

  Future<void> _remind(List<MissingWork> rows) async {
    if (rows.isEmpty) return;
    setState(() => _sending = true);
    final repo = ref.read(dashboardRepositoryProvider);
    try {
      await Future.wait(rows.map((m) => repo.sendReminder(
            studentId: m.studentId,
            classId: m.classId,
            classworkId: m.classworkId,
            message: _message(m),
          )));
      showToast(rows.length == 1
          ? 'Reminder sent to ${rows.first.studentName}'
          : 'Reminders sent to ${rows.map((m) => m.studentId).toSet().length} students');
      setState(_selected.clear);
    } catch (e) {
      showToast("Couldn't send reminders: $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classRoom;
    final now = DateTime.now();
    final metric = ref.watch(reportSummaryProvider((c.id, widget.period))).valueOrNull?.missingWork;
    final all = ref.watch(missingWorkProvider(c.id)).valueOrNull ?? const <MissingWork>[];
    final students = <String, String>{for (final m in all) m.studentId: m.studentName};
    final rows = all.where((m) {
      if (_studentId != null && m.studentId != _studentId) return false;
      return switch (_status) {
        _StatusFilter.all => true,
        _StatusFilter.overdue => m.isOverdue(now),
        _StatusFilter.dueSoon => !m.isOverdue(now),
      };
    }).toList();
    final studentsBehind = all.map((m) => m.studentId).toSet().length;

    return ReportPanelFrame(
      title: 'Missing Work Details',
      icon: Icons.priority_high_rounded,
      tone: Tone.red,
      value: '${metric?.value?.round() ?? studentsBehind}',
      deltaText: deltaLabel(metric?.delta, widget.period.comparisonLabel, asPercent: false),
      deltaColor: deltaColor(metric?.delta, lowerIsBetter: true),
      primaryLabel: 'Open Submissions',
      onPrimary: () {
        Navigator.pop(context);
        goTo(Routes.section(NavSection.submissions, classId: c.id));
      },
      onDownload: () => exportPanelPdf(ref, c, widget.period, 'Missing Work', [
        ReportSection('Incomplete or overdue',
            table: ReportTable(['Student', 'Activity', 'Due date', 'Status'], [
              for (final m in all)
                [m.studentName, m.classworkTitle, fullDate(m.dueDate), m.statusLabel(now)],
            ])),
      ]),
      children: [
        Row(
          children: [
            Expanded(
              child: FilterDropdown<String?>(
                value: _studentId,
                options: [null, ...students.keys],
                labelOf: (id) => id == null ? 'All Students' : students[id] ?? 'Student',
                onChanged: (id) => setState(() => _studentId = id),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilterDropdown<_StatusFilter>(
                value: _status,
                options: _StatusFilter.values,
                labelOf: (s) => s.label,
                onChanged: (s) => setState(() => _status = s),
              ),
            ),
          ],
        ),
        PanelSectionTitle(
          'Incomplete or Overdue',
          trailing: OutlinedButton.icon(
            onPressed: _selected.isEmpty || _sending
                ? null
                : () => _remind(all.where((m) => _selected.contains(m.id)).toList()),
            icon: const Icon(Icons.send_outlined, size: 18),
            label: Text(_selected.isEmpty
                ? 'Send reminder to selected'
                : 'Send reminder to selected (${_selected.length})'),
          ),
        ),
        if (rows.isEmpty)
          const EmptyNote('Nothing missing here.')
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: AppColors.chip.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: rows.every((m) => _selected.contains(m.id))
                            ? true
                            : (rows.any((m) => _selected.contains(m.id)) ? null : false),
                        tristate: true,
                        onChanged: (_) => setState(() {
                          final allOn = rows.every((m) => _selected.contains(m.id));
                          for (final m in rows) {
                            allOn ? _selected.remove(m.id) : _selected.add(m.id);
                          }
                        }),
                      ),
                      const Expanded(flex: 5, child: Text('Student / Activity', style: AppText.label)),
                      const Expanded(flex: 3, child: Text('Due Date', style: AppText.label)),
                      const Expanded(flex: 4, child: Text('Status', style: AppText.label)),
                      const SizedBox(width: 150, child: Text('Actions', style: AppText.label)),
                    ],
                  ),
                ),
                for (final m in rows)
                  Container(
                    decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.divider))),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selected.contains(m.id),
                          onChanged: (v) => setState(
                              () => v == true ? _selected.add(m.id) : _selected.remove(m.id)),
                        ),
                        Expanded(
                          flex: 5,
                          child: Row(
                            children: [
                              InitialsAvatar(
                                initials: m.studentName.isEmpty ? '?' : m.studentName[0],
                                tone: toneForName(m.studentName),
                                size: 34,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.studentName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text(m.classworkTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.meta.copyWith(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(fullDate(m.dueDate), style: AppText.meta.copyWith(fontSize: 12.5)),
                        ),
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Pill(
                              m.statusLabel(now),
                              tone: m.daysOverdue(now) >= 3
                                  ? Tone.red
                                  : (m.isOverdue(now) ? Tone.amber : Tone.blue),
                              icon: Icons.error_rounded,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: _sending ? null : () => _remind([m]),
                                  child: const Text('Send Reminder'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              MoreMenu<String>(
                                items: [
                                  menuItem('student', Icons.person_outline_rounded, 'View student'),
                                  menuItem('work', Icons.description_outlined, 'Open classwork'),
                                ],
                                onSelected: (v) {
                                  Navigator.pop(context);
                                  goTo(v == 'student'
                                      ? Routes.students(classId: c.id, studentId: m.studentId)
                                      : Routes.classDetail(c.id, ClassTab.classwork));
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
