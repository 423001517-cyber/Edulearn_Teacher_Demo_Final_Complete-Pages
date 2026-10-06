import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/classwork_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/stream_providers.dart';
import '../../providers/submissions_providers.dart';
import '../classwork/classwork_details_popover.dart';
import '../classwork/classwork_dialogs.dart';
import '../shell/top_bar.dart';
import '../stream/stream_page.dart' show PageClassSelector;
import '../stream/stream_widgets.dart';
import 'submission_dialogs.dart';

/// `/submissions?classId=&item=` — review, grade and return student work.
class SubmissionsPage extends ConsumerWidget {
  const SubmissionsPage({super.key, this.classId, this.itemId});

  final String? classId;
  final String? itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassRoom?>(
      value: ref.watch(streamClassProvider(classId)),
      data: (c) {
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Submissions'),
            children: [EmptyNote('No classes yet.')],
          );
        }
        return PageScaffold(
          header: PageHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Submissions',
            subtitle: 'Review, grade, and return student work.',
            actions: PageClassSelector(current: c, onChanged: (x) => goTo(Routes.submissions(classId: x.id))),
          ),
          children: [_Board(key: ValueKey(c.id), classRoom: c, itemId: itemId)],
        );
      },
    );
  }
}

class _Board extends ConsumerStatefulWidget {
  const _Board({super.key, required this.classRoom, this.itemId});

  final ClassRoom classRoom;
  final String? itemId;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  static const _pageSize = 8;
  late String? _itemId = widget.itemId;
  late bool _queueToReview = widget.itemId == null;
  ClassworkType? _type;
  WorkState? _state;
  RowTab _tab = RowTab.all;
  RowSort _sort = RowSort.newest;
  String _query = '';
  int _page = 0;
  final Set<String> _selected = {};

  ClassRoom get _class => widget.classRoom;

  void _select(String id) => setState(() {
        _itemId = id;
        _tab = RowTab.all;
        _page = 0;
        _selected.clear();
      });

  @override
  Widget build(BuildContext context) {
    final work = ref.watch(gradableWorkProvider(_class.id));
    final items = work.valueOrNull ?? const <ClassworkItem>[];
    final toReview = ref.watch(toReviewByItemProvider(_class.id));
    final quarter = schoolQuarter(DateTime.now());
    final thisQuarter = items.where((w) => w.quarter == quarter);
    final q = _query.trim().toLowerCase();

    var queue = items.where((w) => (_type == null || w.type == _type)).toList();
    if (_queueToReview) queue = queue.where((w) => (toReview[w.id] ?? 0) > 0).toList();
    final matchingItems = q.isEmpty ? queue : queue.where((w) => w.title.toLowerCase().contains(q)).toList();
    final shownQueue = matchingItems.isEmpty ? queue : matchingItems;

    final selectedItem = items.where((w) => w.id == _itemId).firstOrNull ??
        (shownQueue.isNotEmpty ? shownQueue.first : (items.isNotEmpty ? items.first : null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(children: [
          StatCard(
            icon: Icons.description_rounded,
            tone: Tone.amber,
            label: 'To review',
            value: ref.watch(classNeedsReviewProvider(_class.id)).whenData((n) => '$n'),
            caption: 'New submissions',
          ),
          StatCard(
            icon: Icons.article_rounded,
            tone: Tone.blue,
            label: 'Turned in',
            value: work.whenData((_) => '${thisQuarter.fold<int>(0, (n, w) => n + w.submittedCount)}'),
            caption: 'This quarter',
          ),
          StatCard(
            icon: Icons.priority_high_rounded,
            tone: Tone.red,
            label: 'Missing',
            value: AsyncData('${ref.watch(missingByClassProvider)[_class.id] ?? 0}'),
            caption: 'Students behind',
          ),
          StatCard(
            icon: Icons.check_box_rounded,
            tone: Tone.green,
            label: 'Returned',
            value: work.whenData((_) => '${thisQuarter.fold<int>(0, (n, w) => n + w.scoredCount)}'),
            caption: 'This quarter',
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 300,
            child: SearchField(
              hint: 'Search students or classwork',
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
            ),
          ),
          if (selectedItem != null)
            FilterDropdown<String>(
              value: selectedItem.id,
              options: [for (final w in items) w.id],
              labelOf: (id) => items.where((w) => w.id == id).firstOrNull?.title ?? 'Classwork',
              minWidth: 220,
              onChanged: _select,
            ),
          FilterDropdown<ClassworkType?>(
            value: _type,
            options: const [null, ClassworkType.quest, ClassworkType.activity, ClassworkType.quiz, ClassworkType.boss],
            labelOf: (t) => t?.shortLabel ?? 'All types',
            minWidth: 140,
            onChanged: (t) => setState(() => _type = t),
          ),
          FilterDropdown<WorkState?>(
            value: _state,
            options: const [null, ...WorkState.values],
            labelOf: (s) => s?.label ?? 'All status',
            minWidth: 140,
            onChanged: (s) => setState(() {
              _state = s;
              _page = 0;
            }),
          ),
          FilterDropdown<RowSort>(
            value: _sort,
            options: RowSort.values,
            labelOf: (s) => s.label,
            minWidth: 150,
            onChanged: (s) => setState(() => _sort = s),
          ),
          if (selectedItem != null)
            OutlinedButton.icon(
              onPressed: () => _export(selectedItem),
              icon: const Icon(Icons.download_rounded, size: 19),
              label: const Text('Export grades'),
            ),
        ]),
        const SizedBox(height: 16),
        AsyncValueView<List<ClassworkItem>>(
          value: work,
          loadingHeight: 260,
          data: (_) => TwoColumn(
            leftFlex: 4,
            rightFlex: 9,
            left: [
              _Queue(
                items: shownQueue,
                toReview: toReview,
                selectedId: selectedItem?.id,
                classSize: _class.studentCount,
                toReviewTab: _queueToReview,
                onTab: (v) => setState(() => _queueToReview = v),
                onSelect: _select,
              ),
            ],
            right: [
              if (selectedItem == null)
                Container(
                  decoration: AppDecorations.card,
                  child: const EmptyNote('No graded classwork yet. Assign a quest, quiz or activity first.',
                      icon: Icons.inbox_outlined),
                )
              else
                _itemPanel(selectedItem),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemPanel(ClassworkItem item) {
    final rowsValue = ref.watch(itemRowsProvider((_class.id, item)));
    final rows = rowsValue.valueOrNull ?? const <SubmissionRow>[];
    var filtered = filterRows(rows, _tab, _query, _sort);
    if (_state != null) filtered = filtered.where((r) => r.state == _state).toList();
    final pages = (filtered.length / _pageSize).ceil().clamp(1, 1 << 20);
    final page = _page.clamp(0, pages - 1);
    final shown = filtered.skip(page * _pageSize).take(_pageSize).toList();
    int count(RowTab t) => rows.where((r) => t.shows(r.state)).length;
    final selectedSubs = [
      for (final r in rows)
        if (r.submission != null && _selected.contains(r.student.id)) r.submission!,
    ];

    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(item.title, style: AppText.sectionTitle.copyWith(fontSize: 18)),
                Text(
                  '${_class.name}  •  ${item.points} points  •  Due ${fullDate(item.dueDate)}',
                  style: AppText.meta,
                ),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                FilledButton.icon(
                  onPressed: selectedSubs.isEmpty
                      ? null
                      : () async {
                          final n = await ref.read(submissionsRepositoryProvider).returnMany(selectedSubs);
                          setState(_selected.clear);
                          showToast(n == 0 ? 'Nothing to return in the selection' : 'Returned $n submission${n == 1 ? '' : 's'}');
                        },
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Return selected'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _export(item, withFiles: true),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download all'),
                ),
                _ItemMenu(item: item, rows: rows, onExport: () => _export(item)),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in RowTab.values)
              ChoiceChip(
                selected: _tab == t,
                showCheckmark: false,
                label: Text('${t.label}  ${count(t)}'),
                onSelected: (_) => setState(() {
                  _tab = t;
                  _page = 0;
                }),
              ),
          ]),
          const SizedBox(height: 10),
          AsyncValueView<List<SubmissionRow>>(
            value: rowsValue,
            loadingHeight: 200,
            data: (_) => filtered.isEmpty
                ? const EmptyNote('No students here.', icon: Icons.people_outline_rounded)
                : _Table(
                    item: item,
                    className: _class.name,
                    rows: shown,
                    selected: _selected,
                    onToggle: (id, v) => setState(() => v ? _selected.add(id) : _selected.remove(id)),
                    onToggleAll: (v) => setState(() {
                      for (final r in shown) {
                        v ? _selected.add(r.student.id) : _selected.remove(r.student.id);
                      }
                    }),
                  ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(
              filtered.isEmpty ? '0 of 0' : '${page * _pageSize + 1}–${page * _pageSize + shown.length} of ${filtered.length}',
              style: AppText.meta,
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
          ]),
        ],
      ),
    );
  }

  /// CSV of the item's grades (and file links for "Download all").
  Future<void> _export(ClassworkItem item, {bool withFiles = false}) async {
    final rows = ref.read(itemRowsProvider((_class.id, item))).valueOrNull ?? const <SubmissionRow>[];
    final table = ReportTable(
      ['Student', 'Status', 'Submitted', 'Score', 'Max', 'Feedback', if (withFiles) 'File'],
      [
        for (final r in rows)
          [
            r.student.name,
            r.state.label,
            r.submission == null ? '' : postTime(r.submission!.submittedAt),
            '${r.submission?.score ?? ''}',
            '${item.points}',
            r.submission?.privateFeedback ?? '',
            if (withFiles) r.submission?.attachmentUrl ?? '',
          ],
      ],
    );
    showToast('Preparing CSV…');
    try {
      final url = await ref.read(reportExporterProvider).exportCsv(
            table: table,
            fileName: fileSlug('${_class.name} ${item.title} ${withFiles ? 'submissions' : 'grades'}'),
          );
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
}

// ------------------------------------------------------------------ queue
class _Queue extends StatelessWidget {
  const _Queue({
    required this.items,
    required this.toReview,
    required this.selectedId,
    required this.classSize,
    required this.toReviewTab,
    required this.onTab,
    required this.onSelect,
  });

  final List<ClassworkItem> items;
  final Map<String, int> toReview;
  final String? selectedId;
  final int classSize;
  final bool toReviewTab;
  final ValueChanged<bool> onTab;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Classwork queue', style: AppText.sectionTitle),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            ChoiceChip(selected: toReviewTab, showCheckmark: false, label: const Text('To review'), onSelected: (_) => onTab(true)),
            ChoiceChip(selected: !toReviewTab, showCheckmark: false, label: const Text('All'), onSelected: (_) => onTab(false)),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty)
            EmptyNote(toReviewTab ? 'Nothing waiting for review. 🎉' : 'No graded classwork yet.')
          else
            for (final w in items.take(30))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: w.id == selectedId ? AppColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(w.id),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ToneIcon(w.type.icon, tone: w.type.tone, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                              ),
                              Pill(w.type.shortLabel, tone: w.type.tone),
                            ]),
                            const SizedBox(height: 6),
                            ProgressBar(value: w.completionRate(classSize), color: w.type.tone.fg, height: 6),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(
                                child: Text('${toReview[w.id] ?? 0} to review',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ),
                              Text('Due ${dayMonth(w.dueDate)}', style: AppText.meta.copyWith(fontSize: 12)),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ table
class _Table extends ConsumerWidget {
  const _Table({
    required this.item,
    required this.className,
    required this.rows,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  final ClassworkItem item;
  final String className;
  final List<SubmissionRow> rows;
  final Set<String> selected;
  final void Function(String id, bool value) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allOn = rows.every((r) => selected.contains(r.student.id));
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > 760;
      return Column(children: [
        if (wide)
          Container(
            color: AppColors.chip.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Checkbox(value: allOn, onChanged: (v) => onToggleAll(v ?? false)),
              Expanded(flex: 22, child: Text('Student', style: AppText.label)),
              Expanded(flex: 14, child: Text('Status', style: AppText.label)),
              Expanded(flex: 16, child: Text('Submitted', style: AppText.label)),
              Expanded(flex: 8, child: Text('Score', style: AppText.label)),
              Expanded(flex: 18, child: Text('Feedback', style: AppText.label)),
              Expanded(flex: 14, child: Text('Actions', style: AppText.label)),
            ]),
          ),
        for (final r in rows)
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Checkbox(value: selected.contains(r.student.id), onChanged: (v) => onToggle(r.student.id, v ?? false)),
              Expanded(
                flex: 22,
                child: Row(children: [
                  PersonAvatar(name: r.student.name, size: 34),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.student.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle.copyWith(fontSize: 13.5))),
                ]),
              ),
              if (wide) ...[
                Expanded(flex: 14, child: Align(alignment: Alignment.centerLeft, child: StatePill(r.state))),
                Expanded(
                  flex: 16,
                  child: Text(r.submission == null ? '—' : postTime(r.submission!.submittedAt), style: AppText.meta.copyWith(fontSize: 12.5)),
                ),
                Expanded(flex: 8, child: Text(r.submission?.score == null ? '—' : '${r.submission!.score}/${item.points}')),
                Expanded(
                  flex: 18,
                  child: Text(r.submission?.privateFeedback.isNotEmpty ?? false ? r.submission!.privateFeedback : '—',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 12.5)),
                ),
              ] else
                StatePill(r.state),
              Expanded(
                flex: wide ? 14 : 10,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _RowButton(row: r, item: item, className: className),
                  _RowMenu(row: r, item: item, className: className),
                ]),
              ),
            ]),
          ),
      ]);
    });
  }
}

/// Coloured status pill: Turned in · Late · Draft grade · Graded · Missing · Assigned.
class StatePill extends StatelessWidget {
  const StatePill(this.state, {super.key});

  final WorkState state;

  @override
  Widget build(BuildContext context) => Pill(
        state.label,
        tone: switch (state) {
          WorkState.turnedIn => Tone.green,
          WorkState.late => Tone.amber,
          WorkState.draft => Tone.purple,
          WorkState.graded => Tone.blue,
          WorkState.missing => Tone.red,
          WorkState.assigned => Tone.neutral,
        },
        icon: switch (state) {
          WorkState.turnedIn => Icons.check_circle_rounded,
          WorkState.late => Icons.schedule_rounded,
          WorkState.draft => Icons.edit_note_rounded,
          WorkState.graded => Icons.verified_rounded,
          WorkState.missing => Icons.error_rounded,
          WorkState.assigned => Icons.hourglass_empty_rounded,
        },
      );
}

class _RowButton extends StatelessWidget {
  const _RowButton({required this.row, required this.item, required this.className});

  final SubmissionRow row;
  final ClassworkItem item;
  final String className;

  @override
  Widget build(BuildContext context) {
    if (row.submission == null) {
      return TextButton(
        onPressed: () => showReminderPanel(context, student: row.student, item: item, className: className),
        child: const Text('Remind'),
      );
    }
    return FilledButton.tonal(
      style: FilledButton.styleFrom(minimumSize: const Size(72, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
      onPressed: () => goTo(Routes.reviewSubmission(item.id, row.student.id)),
      child: Text(row.state == WorkState.graded ? 'View' : 'Review'),
    );
  }
}

/// ⋮ on a student row.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.row, required this.item, required this.className});

  final SubmissionRow row;
  final ClassworkItem item;
  final String className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = row.submission;
    return MoreMenu<String>(
      items: [
        if (s != null) menuItem('view', Icons.visibility_outlined, 'View submission'),
        if (s?.attachmentUrl != null) menuItem('download', Icons.download_rounded, 'Download file'),
        menuItem('remind', Icons.notifications_none_rounded, 'Send reminder notification'),
        if (s != null && s.status == SubmissionStatus.pending)
          menuItem('reviewed', Icons.task_alt_rounded, 'Mark as reviewed'),
        if (s != null) menuItem('score', Icons.edit_outlined, 'Edit score'),
        menuItem('history', Icons.history_rounded, 'View submission history'),
        if (s != null) ...[
          const PopupMenuDivider(),
          menuItem('remove', Icons.delete_outline_rounded, 'Remove submission', destructive: true),
        ],
      ],
      onSelected: (v) async {
        final repo = ref.read(submissionsRepositoryProvider);
        switch (v) {
          case 'view':
            goTo(Routes.reviewSubmission(item.id, row.student.id));
          case 'download':
            await openUrl(s!.attachmentUrl);
          case 'remind':
            await showReminderPanel(context, student: row.student, item: item, className: className);
          case 'reviewed':
            await repo.returnMany([s!]);
            showToast('${row.student.name}’s work marked as reviewed');
          case 'score':
            final n = await showEditScoreDialog(context, s!, item.points);
            if (n != null) {
              await repo.editScore(s, n);
              showToast('Score saved');
            }
          case 'history':
            await showHistoryDialog(context, item, row);
          case 'remove':
            final ok = await confirmAction(
              context,
              title: 'Remove ${row.student.name}’s submission?',
              message: 'Their work and grade for “${item.title}” are removed. They’ll need to turn it in again '
                  '(it counts as missing if the due date has passed).',
              confirmLabel: 'Remove submission',
              destructive: true,
            );
            if (!ok) return;
            await repo.remove(s!);
            showToast('Submission removed');
        }
      },
    );
  }
}

/// ⋮ next to Download all: actions on the whole classwork item.
class _ItemMenu extends ConsumerWidget {
  const _ItemMenu({required this.item, required this.rows, required this.onExport});

  final ClassworkItem item;
  final List<SubmissionRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MoreMenu<String>(
      items: [
        menuItem('edit', Icons.edit_outlined, 'Edit classwork'),
        menuItem('instructions', Icons.info_outline_rounded, 'View instructions'),
        menuItem('remind', Icons.notifications_none_rounded, 'Send reminder to missing students'),
        menuItem('reviewed', Icons.task_alt_rounded, 'Mark all as reviewed'),
        menuItem('summary', Icons.download_rounded, 'Download submission summary'),
        menuItem('link', Icons.link_rounded, 'Copy classwork link'),
        const PopupMenuDivider(),
        menuItem('delete', Icons.delete_outline_rounded, 'Delete classwork', destructive: true),
      ],
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            await openClassworkEditor(context, type: item.type, existing: item);
          case 'instructions':
            await showClassworkPreview(context, item);
          case 'remind':
            await remindAllMissing(context, ref, item, rows);
          case 'reviewed':
            final n = await ref.read(submissionsRepositoryProvider).returnMany([
              for (final r in rows)
                if (r.submission != null) r.submission!,
            ]);
            showToast(n == 0 ? 'Everything is already reviewed' : '$n submission${n == 1 ? '' : 's'} marked as reviewed');
          case 'summary':
            onExport();
          case 'link':
            await copyClassworkLink(classId: item.classId, itemId: item.id);
          case 'delete':
            final repo = ref.read(classworkRepositoryProvider);
            if (!await confirmDeleteClasswork(context, item)) return;
            await repo.delete(item);
            showToast('“${item.title}” deleted');
            goTo(Routes.submissions(classId: item.classId));
        }
      },
    );
  }
}
