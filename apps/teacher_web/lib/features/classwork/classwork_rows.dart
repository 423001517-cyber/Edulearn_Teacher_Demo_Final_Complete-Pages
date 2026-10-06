import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/classwork_providers.dart';
import '../../providers/core_providers.dart';
import 'classwork_details_popover.dart';
import 'classwork_dialogs.dart';

/// Left column: All classwork · topics (with ⋮) · Create topic.
class TopicsCard extends ConsumerWidget {
  const TopicsCard({
    super.key,
    required this.classRoom,
    required this.topics,
    required this.selected,
    required this.hasLooseItems,
    required this.onSelect,
  });

  final ClassRoom classRoom;
  final List<ClassTopic> topics;

  /// null = All classwork; '' = No topic.
  final String? selected;
  final bool hasLooseItems;
  final ValueChanged<String?> onSelect;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(classworkRepositoryProvider);
    final name = await showTopicNameDialog(context);
    if (name == null) return;
    final last = topics.isEmpty ? 0.0 : topics.last.position;
    await repo.createTopic(classRoom.id, name, last + 1);
    showToast('Topic “$name” created');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(String? id, String label, IconData icon, {ClassTopic? topic, int? index}) {
      final on = selected == id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: on ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(children: [
                Icon(icon, size: 21, color: on ? AppColors.primary : AppColors.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on ? AppColors.primary : AppColors.ink,
                      )),
                ),
                if (topic != null && index != null) _TopicMenu(classRoom: classRoom, topics: topics, index: index),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Topics', style: AppText.sectionTitle),
          const SizedBox(height: 12),
          tile(null, 'All classwork', Icons.description_outlined),
          for (var i = 0; i < topics.length; i++)
            tile(topics[i].id, topics[i].name, Icons.format_list_bulleted_rounded, topic: topics[i], index: i),
          if (hasLooseItems) tile('', 'No topic', Icons.inbox_outlined),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add_circle_rounded, size: 24),
              label: const Text('Create topic', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⋮ on a topic: Rename · Move up · Move down · Copy link · Delete topic.
class _TopicMenu extends ConsumerWidget {
  const _TopicMenu({required this.classRoom, required this.topics, required this.index});

  final ClassRoom classRoom;
  final List<ClassTopic> topics;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = topics[index];
    return MoreMenu<String>(
      items: [
        menuItem('rename', Icons.edit_outlined, 'Rename topic'),
        if (index > 0) menuItem('up', Icons.arrow_upward_rounded, 'Move up'),
        if (index < topics.length - 1) menuItem('down', Icons.arrow_downward_rounded, 'Move down'),
        menuItem('link', Icons.link_rounded, 'Copy link'),
        const PopupMenuDivider(),
        menuItem('delete', Icons.delete_outline_rounded, 'Delete topic', destructive: true),
      ],
      onSelected: (v) async {
        final repo = ref.read(classworkRepositoryProvider);
        switch (v) {
          case 'rename':
            final name = await showTopicNameDialog(context, initial: t.name);
            if (name != null && name != t.name) await repo.renameTopic(classRoom.id, t.id, name);
          case 'up':
            await repo.swapTopics(classRoom.id, t, topics[index - 1]);
          case 'down':
            await repo.swapTopics(classRoom.id, t, topics[index + 1]);
          case 'link':
            await copyClassworkLink(classId: classRoom.id, topicId: t.id);
          case 'delete':
            final ok = await confirmAction(
              context,
              title: 'Delete “${t.name}”?',
              message: 'The topic is removed. Its classwork is kept and moves to “No topic”.',
              confirmLabel: 'Delete topic',
              destructive: true,
            );
            if (!ok) return;
            await repo.deleteTopic(classRoom.id, t.id);
            showToast('Topic deleted');
        }
      },
    );
  }
}

/// "▾ Week 1 — Mga Rehiyon ng Pilipinas  ⋮" with its rows (drag to reorder).
class TopicSectionView extends ConsumerWidget {
  const TopicSectionView({
    super.key,
    required this.classRoom,
    required this.section,
    required this.topics,
    required this.draggable,
    required this.collapsed,
    required this.onToggle,
    required this.onReordered,
  });

  final ClassRoom classRoom;
  final TopicSection section;
  final List<ClassTopic> topics;
  final bool draggable;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onReordered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = section.topic;
    final items = section.items;
    final index = t == null ? -1 : topics.indexWhere((x) => x.id == t.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                AnimatedRotation(
                  turns: collapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t == null ? 'No topic' : topicHeading(t.name),
                      style: AppText.sectionTitle.copyWith(fontSize: 17)),
                ),
                Text('${items.length}', style: AppText.meta),
                if (t != null && index >= 0) _TopicMenu(classRoom: classRoom, topics: topics, index: index),
              ]),
            ),
          ),
          if (!collapsed)
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 4, 0, 10),
                child: Text('No classwork in this topic yet.', style: AppText.meta),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (from, to) async {
                  if (to > from) to -= 1;
                  final list = [...items];
                  list.insert(to, list.removeAt(from));
                  onReordered();
                  await ref.read(classworkRepositoryProvider).reorder(list);
                },
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      key: ValueKey(items[i].id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClassworkRow(
                        item: items[i],
                        classRoom: classRoom,
                        topics: topics,
                        handle: draggable
                            ? ReorderableDragStartListener(
                                index: i,
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Icon(Icons.drag_indicator_rounded, color: AppColors.muted),
                                ),
                              )
                            : const SizedBox(width: 24),
                      ),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

/// One classwork item: icon, title/type, status, due date, points, turned in,
/// View submissions, ⋮.
class ClassworkRow extends ConsumerWidget {
  const ClassworkRow({
    super.key,
    required this.item,
    required this.classRoom,
    required this.topics,
    required this.handle,
  });

  final ClassworkItem item;
  final ClassRoom classRoom;
  final List<ClassTopic> topics;
  final Widget handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = item;
    final live = w.status == ClassworkStatus.published || w.status == ClassworkStatus.closed;
    final assigned = w.isRemedial ? w.assignedStudentIds.length : classRoom.studentCount;
    final statusPill = Pill(
      w.status.label,
      tone: switch (w.status) {
        ClassworkStatus.published => Tone.green,
        ClassworkStatus.scheduled => Tone.purple,
        ClassworkStatus.draft || ClassworkStatus.closed => Tone.neutral,
      },
    );
    final facts = Wrap(
      spacing: 18,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        statusPill,
        _Fact(
          Icons.calendar_today_outlined,
          w.status == ClassworkStatus.scheduled && w.publishAt != null
              ? 'Posts ${fullDate(w.publishAt!)}'
              : w.type.isGraded
                  ? 'Due ${fullDate(w.dueDate)}'
                  : fullDate(w.dueDate),
        ),
        if (w.type.isGraded) _Fact(Icons.bar_chart_rounded, '${w.points} points'),
        if (w.type.isGraded && live) _Fact(Icons.groups_rounded, '${w.submittedCount}/$assigned'),
      ],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showClassworkPreview(context, w),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 760;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
                Text(w.isRemedial ? '${w.type.shortLabel} · Remedial' : w.type.shortLabel,
                    style: AppText.meta.copyWith(fontSize: 12.5)),
              ],
            );
            return Row(children: [
              handle,
              const SizedBox(width: 6),
              ToneIcon(w.type.icon, tone: w.type.tone, size: 46, circle: true),
              const SizedBox(width: 14),
              if (wide) ...[
                SizedBox(width: 260, child: title),
                const SizedBox(width: 12),
                Expanded(child: facts),
              ] else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 8), facts],
                  ),
                ),
              if (w.type.isGraded && live) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  onPressed: () => openSubmissions(context, w),
                  child: Text(wide ? 'View submissions' : 'Submissions'),
                ),
              ],
              ClassworkItemMenu(item: w, topics: topics),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: AppColors.inkSoft),
        const SizedBox(width: 6),
        Text(text, style: AppText.meta.copyWith(fontSize: 13)),
      ]);
}

/// "View submissions" → the Submissions page on this item.
void openSubmissions(BuildContext context, ClassworkItem item) =>
    goTo(Routes.submissions(classId: item.classId, item: item.id));

/// ⋮ on a classwork row: Edit · Duplicate · Move to topic · Copy link ·
/// Unpublish / Publish · Delete.
class ClassworkItemMenu extends ConsumerWidget {
  const ClassworkItemMenu({super.key, required this.item, required this.topics});

  final ClassworkItem item;
  final List<ClassTopic> topics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = item;
    final live = w.status == ClassworkStatus.published || w.status == ClassworkStatus.closed;
    return MoreMenu<String>(
      items: [
        menuItem('edit', Icons.edit_outlined, 'Edit'),
        menuItem('duplicate', Icons.copy_rounded, 'Duplicate'),
        menuItem('move', Icons.drive_file_move_outline, 'Move to topic'),
        menuItem('link', Icons.link_rounded, 'Copy link'),
        live
            ? menuItem('unpublish', Icons.visibility_off_outlined, 'Unpublish')
            : menuItem('publish', Icons.send_outlined, 'Publish now'),
        const PopupMenuDivider(),
        menuItem('delete', Icons.delete_outline_rounded, 'Delete', destructive: true),
      ],
      onSelected: (v) async {
        final repo = ref.read(classworkRepositoryProvider);
        switch (v) {
          case 'edit':
            await openClassworkEditor(context, type: w.type, existing: w);
          case 'duplicate':
            await repo.duplicate(w);
            showToast('Copy saved as a draft');
          case 'move':
            final to = await showMoveToTopicDialog(context, w, topics);
            if (to == null || to == (w.topicId ?? '')) return;
            await repo.moveToTopic(w, to.isEmpty ? null : to);
            showToast(to.isEmpty ? 'Moved to “No topic”' : 'Moved to ${topics.firstWhere((t) => t.id == to).name}');
          case 'link':
            await copyClassworkLink(classId: w.classId, itemId: w.id);
          case 'unpublish':
            await repo.setStatus(w, ClassworkStatus.draft);
            showToast('Unpublished — students no longer see “${w.title}”');
          case 'publish':
            await repo.setStatus(w, ClassworkStatus.published);
            showToast('Published');
          case 'delete':
            if (!await confirmDeleteClasswork(context, w)) return;
            await repo.delete(w);
            showToast('“${w.title}” deleted');
        }
      },
    );
  }
}
