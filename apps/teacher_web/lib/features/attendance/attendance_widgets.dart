import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/settings_providers.dart';
import '../students/student_support_panel.dart';

/// A soft grey note above a section.
class InfoStrip extends StatelessWidget {
  const InfoStrip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blueSoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft))),
        ],
      ),
    );
  }
}

/// P / L / A / E with their colors.
class MarkLegend extends StatelessWidget {
  const MarkLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final m in AttendanceMark.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LetterChip(mark: m, size: 22),
              const SizedBox(width: 6),
              Text(m.label, style: AppText.meta.copyWith(fontSize: 12.5)),
            ],
          ),
      ],
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({required this.mark, required this.size});

  final AttendanceMark mark;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: mark.tone.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: mark.tone.fg, width: 1.5),
        ),
        child: Text(mark.letter, style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w800, color: mark.tone.fg)),
      );
}

const _flex = [26, 22, 10, 22, 14];

class AttendanceHeaderRow extends StatelessWidget {
  const AttendanceHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(int i, String label) =>
        Expanded(flex: _flex[i], child: Text(label, style: AppText.label.copyWith(fontSize: 12.5)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        cell(0, 'Student'),
        cell(1, 'Status'),
        cell(2, 'Time in'),
        cell(3, 'Note'),
        cell(4, 'This month'),
      ]),
    );
  }
}

/// One student: the four status buttons, time, note and this month's rate.
class AttendanceRow extends StatelessWidget {
  const AttendanceRow({
    super.key,
    required this.student,
    required this.mark,
    required this.changed,
    required this.time,
    required this.note,
    required this.month,
    required this.wide,
    required this.enabled,
    required this.onMark,
    required this.onNote,
  });

  final Student student;
  final AttendanceMark mark;

  /// Edited since the last save (shows a small dot).
  final bool changed;
  final DateTime? time;
  final String note;
  final AttendanceTally? month;
  final bool wide;
  final bool enabled;
  final ValueChanged<AttendanceMark> onMark;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final name = InkWell(
      onTap: () => showStudentPanel(context, student),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          InitialsAvatar(initials: student.initials, tone: toneForName(student.name), size: 36, imageUrl: student.photoUrl),
          const SizedBox(width: 10),
          Flexible(
            child: Text(student.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
          if (changed) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Not saved yet',
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
              ),
            ),
          ],
        ],
      ),
    );
    final buttons = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in AttendanceMark.values)
          _MarkButton(mark: m, selected: m == mark, onTap: enabled ? () => onMark(m) : null),
      ],
    );
    final timeText = Text(time == null ? '—' : clockText(time!), style: AppText.body.copyWith(fontSize: 13));
    final noteLink = InkWell(
      onTap: enabled ? onNote : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          note.isEmpty ? (enabled ? '+ Add note' : '—') : note,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: note.isEmpty ? AppColors.link : AppColors.inkSoft,
            fontWeight: note.isEmpty ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
    final m = month;
    final monthCell = Row(
      children: [
        Text(percent(m?.rate), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        if (m != null && m.needsFollowUp) ...[
          const SizedBox(width: 6),
          Flexible(child: Pill(m.absentDays >= 2 ? '${m.absentDays} absences' : '${m.lateDays} lates', tone: Tone.amber)),
        ],
      ],
    );

    if (!wide) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Expanded(child: name), monthCell]),
            const SizedBox(height: 8),
            buttons,
            Row(children: [
              timeText,
              const SizedBox(width: 12),
              Expanded(child: noteLink),
            ]),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Expanded(flex: _flex[0], child: Padding(padding: const EdgeInsets.only(right: 8), child: name)),
          Expanded(flex: _flex[1], child: buttons),
          Expanded(flex: _flex[2], child: timeText),
          Expanded(flex: _flex[3], child: Padding(padding: const EdgeInsets.only(right: 8), child: noteLink)),
          Expanded(flex: _flex[4], child: monthCell),
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({required this.mark, required this.selected, required this.onTap});

  final AttendanceMark mark;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: mark.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: mark.label,
        child: Material(
          color: selected ? mark.tone.bg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: selected ? mark.tone.fg : AppColors.buttonBorder, width: 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  mark.letter,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: selected ? mark.tone.fg : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Add or change a note for one student on one day. Returns the new text
/// ('' removes the note), or null when cancelled.
Future<String?> showNoteDialog(
  BuildContext context, {
  required Student student,
  required DateTime date,
  required String initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(student: student, date: date, initial: initial),
  );
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.student, required this.date, required this.initial});

  final Student student;
  final DateTime date;
  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: 'Attendance note', subtitle: '${widget.student.name} · ${shortDate(widget.date)}'),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 200,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'e.g. Medical check-up, note received'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.initial.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  child: const Text('Remove note'),
                ),
              const Spacer(),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(onPressed: () => Navigator.pop(context, _text.text.trim()), child: const Text('Done')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Month heatmap: each school day colored by how many students attended.
class AttendanceMonthCard extends ConsumerWidget {
  const AttendanceMonthCard({
    super.key,
    required this.classId,
    required this.month,
    required this.selected,
    required this.onMonth,
    required this.onDay,
  });

  final String classId;
  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;

  static const _shades = [Color(0xFFE3F4E9), Color(0xFFB3E0C4), Color(0xFF6DBA8C), AppColors.primary];

  static int _level(double rate) => rate >= 0.98
      ? 3
      : rate >= 0.93
          ? 2
          : rate >= 0.88
              ? 1
              : 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(attendanceMonthProvider((classId, month))).valueOrNull ?? const <AttendanceDay>[];
    final inMonth = daysInMonth(days, month);
    final byDay = {for (final d in inMonth) d.date.day: d};
    final avg = pooledRate(inMonth);
    final today = startOfDay(DateTime.now());
    final mondayFirst = ref.watch(preferencesProvider).weekStartsMonday;
    final first = DateTime(month.year, month.month, 1);
    final lead = mondayFirst ? first.weekday - 1 : first.weekday % 7;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final canNext = DateTime(month.year, month.month + 1, 1).isBefore(addDays(today, 1));

    return SectionCard(
      title: '${monthName(month)} ${month.year}',
      icon: Icons.calendar_month_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avg != null) Text('${percent(avg)} avg', style: AppText.meta),
          IconButton(
            tooltip: 'Previous month',
            visualDensity: VisualDensity.compact,
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next month',
            visualDensity: VisualDensity.compact,
            onPressed: canNext ? () => onMonth(DateTime(month.year, month.month + 1)) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1.15,
              children: [
                for (final n in weekdayNames(mondayFirst: mondayFirst))
                  Center(child: Text(n, style: AppText.meta.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700))),
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var d = 1; d <= count; d++)
                  () {
                    final date = DateTime(month.year, month.month, d);
                    final rec = byDay[d];
                    final rate = rec?.rateOrNull;
                    final weekend = isWeekend(date);
                    final future = date.isAfter(today);
                    final isSelected = sameDay(date, selected);
                    final fill = rate == null ? null : _shades[_level(rate)];
                    final dark = rate != null && _level(rate) == 3;
                    return Tooltip(
                      message: rate == null
                          ? (weekend ? 'Weekend' : (future ? shortDate(date) : '${shortDate(date)} · not taken'))
                          : '${shortDate(date)} · ${percent(rate)} present',
                      child: Material(
                        color: fill ?? Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isSelected
                              ? const BorderSide(color: AppColors.ink, width: 2)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: weekend || future || isSelected ? null : () => onDay(date),
                          child: Center(
                            child: Text(
                              '$d',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: rate != null || isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: dark
                                    ? Colors.white
                                    : weekend
                                        ? AppColors.muted.withValues(alpha: 0.6)
                                        : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Under 88%', style: AppText.meta.copyWith(fontSize: 11.5)),
                for (final c in _shades)
                  Container(width: 18, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
                Text('All present', style: AppText.meta.copyWith(fontSize: 11.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Students with 2+ absences or 3+ lates this month.
class FollowUpCard extends StatelessWidget {
  const FollowUpCard({super.key, required this.roster, required this.tally, required this.month});

  final List<Student> roster;
  final Map<String, AttendanceTally> tally;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final s in roster)
        if (tally[s.id] case final t? when t.needsFollowUp) (student: s, tally: t),
    ]..sort((a, b) {
        final c = (b.tally.absentDays * 2 + b.tally.lateDays).compareTo(a.tally.absentDays * 2 + a.tally.lateDays);
        return c != 0 ? c : a.student.name.compareTo(b.student.name);
      });
    return SectionCard(
      title: 'Needs follow-up',
      icon: Icons.flag_outlined,
      child: rows.isEmpty
          ? EmptyNote('No attendance concerns in ${monthName(month)}.', icon: Icons.verified_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length && i < 6; i++) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        InitialsAvatar(
                          initials: rows[i].student.initials,
                          tone: rows[i].tally.absentDays >= 2 ? Tone.red : Tone.amber,
                          size: 36,
                          imageUrl: rows[i].student.photoUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rows[i].student.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              Text('${rows[i].tally.summary} this month',
                                  style: AppText.meta.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        LinkButton(
                          label: 'Message',
                          showArrow: false,
                          onTap: () => goTo(Routes.messages(studentId: rows[i].student.id)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Present-or-late share for the last four school weeks.
class WeeklyAttendanceCard extends StatelessWidget {
  const WeeklyAttendanceCard({super.key, required this.days, required this.date});

  final List<AttendanceDay> days;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final weeks = weeklyRates(days, date);
    return SectionCard(
      title: 'Weekly attendance',
      icon: Icons.insights_rounded,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Present or late, share of school days', style: AppText.meta),
            const SizedBox(height: 12),
            for (final w in weeks) ...[
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(sameDay(w.monday, startOfWeek(DateTime.now())) ? 'This week' : w.label,
                        style: AppText.meta.copyWith(fontSize: 12.5, color: AppColors.inkSoft)),
                  ),
                  Expanded(child: ProgressBar(value: w.rate ?? 0, height: 12)),
                  SizedBox(
                    width: 44,
                    child: Text(percent(w.rate),
                        textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
