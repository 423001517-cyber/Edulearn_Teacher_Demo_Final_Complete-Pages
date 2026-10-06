import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/classwork_providers.dart';
import '../../providers/stream_providers.dart';
import '../shell/top_bar.dart';
import '../stream/stream_page.dart' show PageClassSelector;
import 'classwork_details_popover.dart';
import 'classwork_dialogs.dart';
import 'classwork_rows.dart';

/// `/classwork?classId=&topic=&item=` — lessons, quests, activities, quizzes,
/// Friday Boss Assessments and materials, grouped by topic.
class ClassworkPage extends ConsumerWidget {
  const ClassworkPage({super.key, this.classId, this.topicId, this.itemId});

  final String? classId;
  final String? topicId;

  /// From a copied link: open this item's preview.
  final String? itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassRoom?>(
      value: ref.watch(streamClassProvider(classId)),
      data: (c) {
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Classwork'),
            children: [EmptyNote('No classes yet — classwork appears once a class is assigned to you.')],
          );
        }
        return PageScaffold(
          header: PageHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Classwork',
            subtitle: 'Create and manage lessons, quests, activities, quizzes, and materials.',
            actions: PageClassSelector(current: c, onChanged: (x) => goTo(Routes.classwork(classId: x.id))),
          ),
          children: [ClassworkBoard(key: ValueKey(c.id), classRoom: c, topicId: topicId, itemId: itemId)],
        );
      },
    );
  }
}

/// Toolbar + stats + topics + sections. Also the class page's Classwork tab.
class ClassworkBoard extends ConsumerStatefulWidget {
  const ClassworkBoard({super.key, required this.classRoom, this.topicId, this.itemId, this.showStats = true});

  final ClassRoom classRoom;
  final String? topicId;
  final String? itemId;
  final bool showStats;

  @override
  ConsumerState<ClassworkBoard> createState() => _ClassworkBoardState();
}

class _ClassworkBoardState extends ConsumerState<ClassworkBoard> {
  late ClassworkFilters _filters = ClassworkFilters(quarter: schoolQuarter(DateTime.now()));

  /// null = All classwork; '' = No topic.
  late String? _topic = widget.topicId;
  final Set<String> _collapsed = {};
  bool _openedItem = false;

  ClassRoom get _class => widget.classRoom;

  void _maybeOpenItem(List<ClassworkItem> items) {
    if (_openedItem || widget.itemId == null) return;
    for (final w in items) {
      if (w.id == widget.itemId) {
        _openedItem = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showClassworkPreview(context, w);
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsValue = ref.watch(classworkListProvider(_class.id));
    final topicsValue = ref.watch(classTopicsProvider(_class.id));
    final all = itemsValue.valueOrNull ?? const <ClassworkItem>[];
    final topics = topicsValue.valueOrNull ?? const <ClassTopic>[];
    final quarterItems = all.where((w) => _filters.quarter == null || w.quarter == _filters.quarter).toList();
    final counts = classworkCounts(quarterItems);
    final needsReview = ref.watch(classNeedsReviewProvider(_class.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          classRoom: _class,
          filters: _filters,
          onChanged: (f) => setState(() => _filters = f),
        ),
        if (widget.showStats) ...[
          const SizedBox(height: 18),
          ResponsiveGrid(
            children: [
              StatCard(
                icon: Icons.description_rounded,
                tone: Tone.green,
                label: 'Published',
                value: itemsValue.whenData((_) => '${counts.published}'),
                caption: 'Visible to students',
                selected: _filters.status == ClassworkStatus.published,
                onTap: () => _toggleStatus(ClassworkStatus.published),
              ),
              StatCard(
                icon: Icons.article_rounded,
                tone: Tone.blue,
                label: 'Drafts',
                value: itemsValue.whenData((_) => '${counts.drafts}'),
                caption: 'Not posted yet',
                selected: _filters.status == ClassworkStatus.draft,
                onTap: () => _toggleStatus(ClassworkStatus.draft),
              ),
              StatCard(
                icon: Icons.schedule_rounded,
                tone: Tone.purple,
                label: 'Scheduled',
                value: itemsValue.whenData((_) => '${counts.scheduled}'),
                caption: 'Posts automatically',
                selected: _filters.status == ClassworkStatus.scheduled,
                onTap: () => _toggleStatus(ClassworkStatus.scheduled),
              ),
              StatCard(
                icon: Icons.priority_high_rounded,
                tone: Tone.red,
                label: 'Needs review',
                value: needsReview.whenData((n) => '$n'),
                caption: 'Submissions to grade',
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        AsyncValueView<List<ClassworkItem>>(
          value: itemsValue,
          loadingHeight: 260,
          data: (_) {
            _maybeOpenItem(all);
            final filtered = applyClassworkFilters(all, _filters);
            var sections = groupByTopic(filtered, topics, keepEmpty: !_filters.narrowsItems);
            if (_topic != null) {
              sections = sections.where((s) => (s.topic?.id ?? '') == _topic).toList();
            }
            return TwoColumn(
              leftFlex: 3,
              rightFlex: 9,
              left: [
                TopicsCard(
                  classRoom: _class,
                  topics: topics,
                  selected: _topic,
                  hasLooseItems: all.any((w) => w.topicId == null || !topics.any((t) => t.id == w.topicId)),
                  onSelect: (id) => setState(() => _topic = id),
                ),
              ],
              right: [
                Container(
                  decoration: AppDecorations.card,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sections.isEmpty)
                        EmptyNote(
                          all.isEmpty
                              ? 'No classwork yet. Use Create classwork to add the first lesson or quest.'
                              : 'Nothing matches these filters.',
                          icon: Icons.assignment_outlined,
                        )
                      else
                        for (final s in sections)
                          TopicSectionView(
                            key: ValueKey('section-${s.topic?.id}'),
                            classRoom: _class,
                            section: s,
                            topics: topics,
                            draggable: _filters.sort == ClassworkSort.custom || !_filters.narrowsItems,
                            collapsed: _collapsed.contains(s.topic?.id ?? ''),
                            onToggle: () => setState(() {
                              final k = s.topic?.id ?? '';
                              _collapsed.contains(k) ? _collapsed.remove(k) : _collapsed.add(k);
                            }),
                            onReordered: () {
                              if (_filters.sort != ClassworkSort.custom) {
                                setState(() => _filters = _filters.copyWith(sort: ClassworkSort.custom));
                                showToast('Sorted by “My order” — drag items to arrange them.');
                              }
                            },
                          ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          onPressed: () => showReuseDialog(context, target: _class),
                          icon: const Icon(Icons.copy_all_rounded, size: 19),
                          label: const Text('Reuse post'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _toggleStatus(ClassworkStatus s) => setState(() {
        _filters = _filters.status == s ? _filters.copyWith(allStatuses: true) : _filters.copyWith(status: s);
      });
}

// ------------------------------------------------------------------ toolbar
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.classRoom, required this.filters, required this.onChanged});

  final ClassRoom classRoom;
  final ClassworkFilters filters;
  final ValueChanged<ClassworkFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final create = CreateClassworkButton(classRoom: classRoom);
    final search = SizedBox(
      width: 300,
      child: SearchField(hint: 'Search classwork', onChanged: (v) => onChanged(filters.copyWith(query: v))),
    );
    final dropdowns = [
      FilterDropdown<int?>(
        value: filters.quarter,
        options: const [null, 1, 2, 3, 4],
        labelOf: (q) => q == null ? 'All quarters' : 'Quarter $q',
        minWidth: 140,
        onChanged: (q) => onChanged(q == null ? filters.copyWith(allQuarters: true) : filters.copyWith(quarter: q)),
      ),
      FilterDropdown<ClassworkType?>(
        value: filters.type,
        options: const [
          null,
          ClassworkType.lesson,
          ClassworkType.quest,
          ClassworkType.activity,
          ClassworkType.quiz,
          ClassworkType.boss,
          ClassworkType.material,
        ],
        labelOf: (t) => switch (t) {
          null => 'All types',
          ClassworkType.quiz => 'Quizzes',
          ClassworkType.activity => 'Activities',
          ClassworkType.boss => 'Friday Boss',
          _ => '${t.label}s',
        },
        minWidth: 140,
        onChanged: (t) => onChanged(t == null ? filters.copyWith(allTypes: true) : filters.copyWith(type: t)),
      ),
      FilterDropdown<ClassworkStatus?>(
        value: filters.status,
        options: const [null, ClassworkStatus.published, ClassworkStatus.draft, ClassworkStatus.scheduled, ClassworkStatus.closed],
        labelOf: (s) => s?.label ?? 'All status',
        minWidth: 140,
        onChanged: (s) => onChanged(s == null ? filters.copyWith(allStatuses: true) : filters.copyWith(status: s)),
      ),
      FilterDropdown<ClassworkSort>(
        value: filters.sort,
        options: ClassworkSort.values,
        labelOf: (s) => s.label,
        icon: Icons.swap_vert_rounded,
        minWidth: 150,
        onChanged: (s) => onChanged(filters.copyWith(sort: s)),
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [create, search, ...dropdowns],
    );
  }
}

/// [ + Create classwork | ▾ ] → Lesson · Quest · Activity · Quiz ·
/// Friday Boss Assessment · Material · Reuse post.
class CreateClassworkButton extends StatelessWidget {
  const CreateClassworkButton({super.key, required this.classRoom});

  final ClassRoom classRoom;

  static const _order = [
    ClassworkType.lesson,
    ClassworkType.quest,
    ClassworkType.activity,
    ClassworkType.quiz,
    ClassworkType.boss,
    ClassworkType.material,
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ClassworkType?>(
      tooltip: 'Create classwork',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (t) {
        if (t == null) {
          showReuseDialog(context, target: classRoom);
        } else {
          openClassworkEditor(context, type: t, classId: classRoom.id);
        }
      },
      itemBuilder: (_) => [
        for (final t in _order)
          PopupMenuItem<ClassworkType?>(
            value: t,
            child: Row(children: [
              ToneIcon(t.icon, tone: t.tone, size: 32),
              const SizedBox(width: 12),
              Text(t.label),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<ClassworkType?>(
          value: null,
          child: Row(children: [
            ToneIcon(Icons.copy_all_rounded, tone: Tone.neutral, size: 32),
            SizedBox(width: 12),
            Text('Reuse post'),
          ]),
        ),
      ],
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 18),
            Icon(Icons.add_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Create classwork', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            SizedBox(width: 14),
            VerticalDivider(color: Colors.white38, width: 1, indent: 10, endIndent: 10),
            SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
            SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
