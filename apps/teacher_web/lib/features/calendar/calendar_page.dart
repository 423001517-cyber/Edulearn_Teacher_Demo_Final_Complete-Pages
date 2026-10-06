import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/calendar_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../classwork/classwork_details_popover.dart';
import '../shell/top_bar.dart';
import 'event_dialog.dart';

enum CalendarView { month, week, agenda }

/// `/calendar` — class schedules, deadlines and school events.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focus = DateTime.now();
  CalendarView _view = CalendarView.month;
  String? _classId;
  EntryKind? _type;
  final Set<EntryKind> _visible = {...EntryKind.values};

  Set<EntryKind> get _shown => _type == null ? _visible : {_type!}.intersection(_visible);

  void _move(int by) => setState(() {
        _focus = switch (_view) {
          CalendarView.month => DateTime(_focus.year, _focus.month + by, 1),
          CalendarView.week => _focus.add(Duration(days: 7 * by)),
          CalendarView.agenda => DateTime(_focus.year, _focus.month + by, 1),
        };
      });

  String get _title => switch (_view) {
        CalendarView.month || CalendarView.agenda => DateFormat('MMMM y').format(_focus),
        CalendarView.week => () {
            final d = weekDays(_focus);
            return '${DateFormat('MMM d').format(d.first)} – ${DateFormat('MMM d, y').format(d.last)}';
          }(),
      };

  void _open(CalendarEntry e) {
    if (e.item != null) {
      showClassworkPreview(context, e.item!);
    } else if (e.event != null) {
      showEventDialog(context, existing: e.event);
    }
  }

  Future<void> _export(List<CalendarEntry> entries) async {
    final ics = buildIcs('EduLearn calendar', [
      for (final e in entries)
        if (_shown.contains(e.kind))
          IcsEntry(
            uid: e.id,
            title: e.item != null ? '${e.title} (${e.item!.type.shortLabel})' : e.title,
            start: e.event?.start ?? e.date,
            end: e.event?.end,
            allDay: e.event?.allDay ?? true,
            description: e.className,
          ),
    ]);
    showToast('Preparing calendar file…');
    try {
      final url = await ref.read(reportExporterProvider).exportIcs(ics: ics, fileName: fileSlug('EduLearn calendar $_title'));
      final uri = Uri.parse(url);
      if (kIsWeb) {
        showToast('Calendar file is ready — open it to add to Google Calendar or Outlook',
            actionLabel: 'Open', onAction: () => launchUrl(uri));
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      showToast('Couldn’t export: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesValue = ref.watch(calendarEntriesProvider(_classId));
    final entries = entriesValue.valueOrNull ?? const <CalendarEntry>[];
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];

    return PageScaffold(
      header: const PageHeader(
        icon: Icons.wb_sunny_rounded,
        title: 'Calendar',
        subtitle: 'View class schedules, deadlines, and school events.',
      ),
      children: [
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(150, 48)),
            onPressed: () => showEventDialog(context, date: _view == CalendarView.month ? null : _focus, classId: _classId),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add event'),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton.outlined(tooltip: 'Previous', onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left_rounded)),
            const SizedBox(width: 6),
            OutlinedButton(onPressed: () => setState(() => _focus = DateTime.now()), child: const Text('Today')),
            const SizedBox(width: 6),
            IconButton.outlined(tooltip: 'Next', onPressed: () => _move(1), icon: const Icon(Icons.chevron_right_rounded)),
          ]),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 170),
            child: Text(_title, style: AppText.sectionTitle.copyWith(fontSize: 22)),
          ),
          SegmentedButton<CalendarView>(
            segments: const [
              ButtonSegment(value: CalendarView.month, label: Text('Month')),
              ButtonSegment(value: CalendarView.week, label: Text('Week')),
              ButtonSegment(value: CalendarView.agenda, label: Text('Agenda')),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          FilterDropdown<String?>(
            value: _classId,
            options: [null, for (final c in classes) c.id],
            labelOf: (id) => id == null ? 'All classes' : classes.firstWhere((c) => c.id == id).name,
            icon: Icons.groups_rounded,
            minWidth: 170,
            onChanged: (id) => setState(() => _classId = id),
          ),
          FilterDropdown<EntryKind?>(
            value: _type,
            options: const [null, ...EntryKind.values],
            labelOf: (k) => k?.legend ?? 'All event types',
            minWidth: 170,
            onChanged: (k) => setState(() => _type = k),
          ),
          OutlinedButton.icon(
            onPressed: entries.isEmpty ? null : () => _export(entries),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
            label: const Text('Export calendar'),
          ),
        ]),
        TwoColumn(
          leftFlex: 7,
          rightFlex: 3,
          left: [
            Container(
              decoration: AppDecorations.card,
              clipBehavior: Clip.antiAlias,
              child: AsyncValueView<List<CalendarEntry>>(
                value: entriesValue,
                loadingHeight: 420,
                data: (all) => switch (_view) {
                  CalendarView.month => _MonthGrid(
                      month: _focus, entries: all, visible: _shown, onOpen: _open,
                      onDay: (d) => showEventDialog(context, date: d, classId: _classId)),
                  CalendarView.week => _WeekView(day: _focus, entries: all, visible: _shown, onOpen: _open),
                  CalendarView.agenda => _AgendaView(month: _focus, entries: all, visible: _shown, onOpen: _open),
                },
              ),
            ),
          ],
          right: [
            _UpcomingCard(entries: entries, visible: _shown, onOpen: _open, onViewAll: () => setState(() {
                  _view = CalendarView.agenda;
                  _focus = DateTime.now();
                })),
            _Legend(visible: _visible, onToggle: (k, on) => setState(() => on ? _visible.add(k) : _visible.remove(k))),
            _MissingDeadlines(classId: _classId),
          ],
        ),
      ],
    );
  }
}

/// Tinted chip for one entry.
class EntryChip extends StatelessWidget {
  const EntryChip({super.key, required this.entry, required this.onTap, this.dense = true});

  final CalendarEntry entry;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final k = entry.kind;
    final time = entry.event != null && !entry.event!.allDay ? '${DateFormat('h:mm a').format(entry.event!.start)} ' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: k.tone.bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Tooltip(
            message: '${entry.title} · ${entry.className}',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 5 : 8),
              child: Row(children: [
                Icon(k.icon, size: dense ? 16 : 19, color: k.tone.fg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('$time${entry.title}',
                      maxLines: dense ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: dense ? 12 : 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.entries, required this.visible, required this.onOpen, required this.onDay});

  final DateTime month;
  final List<CalendarEntry> entries;
  final Set<EntryKind> visible;
  final ValueChanged<CalendarEntry> onOpen;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final days = monthGrid(month);
    final today = DateTime.now();
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Column(children: [
      Row(children: [
        for (final n in names)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Text(n, style: AppText.itemTitle),
            ),
          ),
      ]),
      for (var r = 0; r < days.length; r += 7)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final d in days.sublist(r, r + 7))
              Expanded(child: _DayCell(day: d, inMonth: d.month == month.month, today: sameDay(d, today),
                  entries: entriesOn(entries, d, visible), onOpen: onOpen, onTap: () => onDay(d))),
          ]),
        ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.inMonth, required this.today, required this.entries, required this.onOpen, required this.onTap});

  final DateTime day;
  final bool inMonth;
  final bool today;
  final List<CalendarEntry> entries;
  final ValueChanged<CalendarEntry> onOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const maxShown = 3;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: today ? AppColors.primarySoft.withValues(alpha: 0.6) : null,
          border: const Border(right: BorderSide(color: AppColors.divider), bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: today ? const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle) : null,
              child: Text('${day.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: today ? Colors.white : (inMonth ? AppColors.ink : AppColors.muted),
                  )),
            ),
          ),
          const SizedBox(height: 4),
          for (final e in entries.take(maxShown)) EntryChip(entry: e, onTap: () => onOpen(e)),
          if (entries.length > maxShown)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24), alignment: Alignment.centerLeft),
              onPressed: () => _showDay(context, day, entries, onOpen),
              child: Text('+${entries.length - maxShown} more', style: const TextStyle(fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

Future<void> _showDay(BuildContext context, DateTime day, List<CalendarEntry> entries, ValueChanged<CalendarEntry> onOpen) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        maxWidth: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PanelHeader(title: DateFormat('EEEE, MMMM d').format(day), subtitle: '${entries.length} items'),
          const SizedBox(height: 10),
          for (final e in entries)
            EntryChip(entry: e, dense: false, onTap: () {
              Navigator.pop(ctx);
              onOpen(e);
            }),
        ]),
      ),
    );

class _WeekView extends StatelessWidget {
  const _WeekView({required this.day, required this.entries, required this.visible, required this.onOpen});

  final DateTime day;
  final List<CalendarEntry> entries;
  final Set<EntryKind> visible;
  final ValueChanged<CalendarEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final d in weekDays(day))
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 460),
              decoration: BoxDecoration(
                color: sameDay(d, today) ? AppColors.primarySoft.withValues(alpha: 0.6) : null,
                border: const Border(right: BorderSide(color: AppColors.divider)),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(DateFormat('EEE').format(d), textAlign: TextAlign.center, style: AppText.meta),
                Text('${d.day}', textAlign: TextAlign.center, style: AppText.sectionTitle),
                const Divider(),
                for (final e in entriesOn(entries, d, visible)) EntryChip(entry: e, dense: false, onTap: () => onOpen(e)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _AgendaView extends StatelessWidget {
  const _AgendaView({required this.month, required this.entries, required this.visible, required this.onOpen});

  final DateTime month;
  final List<CalendarEntry> entries;
  final Set<EntryKind> visible;
  final ValueChanged<CalendarEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final list = [for (final e in entries) if (visible.contains(e.kind) && !e.date.isBefore(start) && e.date.isBefore(end)) e];
    if (list.isEmpty) return const EmptyNote('Nothing scheduled this month.', icon: Icons.event_available_rounded);
    final days = <DateTime, List<CalendarEntry>>{};
    for (final e in list) {
      days.putIfAbsent(DateTime(e.date.year, e.date.month, e.date.day), () => []).add(e);
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final d in days.keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(DateFormat('EEEE, MMMM d').format(d), style: AppText.itemTitle),
          ),
          for (final e in days[d]!)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: ToneIcon(e.kind.icon, tone: e.kind.tone, size: 40, circle: true),
              title: Text(e.title, style: AppText.itemTitle.copyWith(fontSize: 14)),
              subtitle: Text(e.className),
              trailing: Pill(e.kind.label, tone: e.kind.tone),
              onTap: () => onOpen(e),
            ),
          const Divider(),
        ],
      ]),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.entries, required this.visible, required this.onOpen, required this.onViewAll});

  final List<CalendarEntry> entries;
  final Set<EntryKind> visible;
  final ValueChanged<CalendarEntry> onOpen;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final from = startOfDay(DateTime.now());
    final next = [for (final e in entries) if (visible.contains(e.kind) && !e.date.isBefore(from)) e].take(5).toList();
    return SectionCard(
      title: 'Upcoming',
      actionLabel: 'View all',
      onAction: onViewAll,
      child: next.isEmpty
          ? const EmptyNote('Nothing coming up.')
          : Column(children: [
              for (final e in next)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onOpen(e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: e.kind.tone.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: e.kind.tone.fg.withValues(alpha: 0.25)),
                        ),
                        child: Column(children: [
                          Text(DateFormat('MMM').format(e.date).toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: e.kind.tone.fg)),
                          Text('${e.date.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: e.kind.tone.fg)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                          Text(e.className, style: AppText.meta.copyWith(fontSize: 12)),
                        ]),
                      ),
                      Pill(e.kind.label, tone: e.kind.tone),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.visible, required this.onToggle});

  final Set<EntryKind> visible;
  final void Function(EntryKind kind, bool on) onToggle;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Calendar legend',
        child: Wrap(children: [
          for (final k in EntryKind.values)
            SizedBox(
              width: 190,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: k.tone.fg,
                value: visible.contains(k),
                onChanged: (v) => onToggle(k, v ?? false),
                title: Row(children: [
                  Icon(k.icon, size: 19, color: k.tone.fg),
                  const SizedBox(width: 8),
                  Text(k.legend),
                ]),
              ),
            ),
        ]),
      );
}

class _MissingDeadlines extends ConsumerWidget {
  const _MissingDeadlines({required this.classId});

  final String? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(missingDeadlinesProvider(classId));
    final total = items.fold<int>(0, (n, i) => n + i.missing);
    final now = DateTime.now();
    return Container(
      decoration: AppDecorations.card.copyWith(color: AppColors.redSoft.withValues(alpha: 0.45)),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.error_rounded, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(child: Text('Missing deadlines', style: AppText.sectionTitle)),
          TextButton(onPressed: () => goTo(Routes.submissions(classId: classId)), child: const Text('View all')),
        ]),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('No overdue submissions. 🎉')
        else ...[
          Row(children: [
            Text('$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.red)),
            const SizedBox(width: 10),
            const Expanded(child: Text('overdue submissions', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600))),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
              onPressed: () => goTo(Routes.submissions(classId: items.first.classId, item: items.first.classworkId)),
              child: const Text('Review'),
            ),
          ]),
          const SizedBox(height: 8),
          for (final i in items.take(4))
            InkWell(
              onTap: () => goTo(Routes.submissions(classId: i.classId, item: i.classworkId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(i.type.icon, size: 19, color: i.type.tone.fg),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(
                    '${now.difference(i.dueDate).inDays.clamp(1, 999)} day${now.difference(i.dueDate).inDays > 1 ? 's' : ''} overdue',
                    style: const TextStyle(color: AppColors.red, fontSize: 12.5),
                  ),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}
