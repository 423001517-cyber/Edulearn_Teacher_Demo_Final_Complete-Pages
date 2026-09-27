import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../providers/classes_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/data_providers.dart';
import '../../announcements/announcement_widgets.dart';
import '../../classwork/classwork_details_popover.dart';
import '../../dashboard/widgets/class_performance_card.dart';
import '../../students/student_support_panel.dart';

/// Overview tab. Stat cards open the matching Class Reports panel.
class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    final missing = ref.watch(missingByClassProvider)[c.id] ?? 0;
    String report(String panel) => Routes.reports(classId: c.id, panel: panel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          children: [
            StatCard(
              icon: Icons.bar_chart_rounded,
              tone: Tone.green,
              label: 'Completion',
              value: AsyncData(percent(c.completionRate)),
              caption: 'of all classwork completed',
              watermark: Icons.bar_chart_rounded,
              onTap: () => context.go(report('completion')),
            ),
            StatCard(
              icon: Icons.star_rounded,
              tone: Tone.blue,
              label: 'Class Average',
              value: AsyncData(percent(c.averageScore)),
              caption: 'average score across all work',
              watermark: Icons.bar_chart_rounded,
              onTap: () => context.go(report('score')),
            ),
            StatCard(
              icon: Icons.description_outlined,
              tone: Tone.amber,
              label: 'Active Quests',
              value: AsyncData('${c.questCount}'),
              caption: 'currently assigned',
              watermark: Icons.bar_chart_rounded,
              onTap: () => context.go(Routes.classDetail(c.id, ClassTab.classwork)),
            ),
            StatCard(
              icon: Icons.priority_high_rounded,
              tone: Tone.red,
              label: 'Missing Work',
              value: AsyncData('$missing'),
              caption: 'students behind',
              watermark: Icons.bar_chart_rounded,
              onTap: () => context.go(report('missing')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TwoColumn(
          leftFlex: 11,
          rightFlex: 10,
          left: [_UpcomingClasswork(classRoom: c), ClassPerformanceCard(classId: c.id)],
          right: [
            _RecentActivity(classId: c.id),
            _SupportCard(classId: c.id),
            _ClassAnnouncements(classId: c.id),
          ],
        ),
      ],
    );
  }
}

class _UpcomingClasswork extends ConsumerWidget {
  const _UpcomingClasswork({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = startOfDay(DateTime.now());
    final upcoming = ref.watch(classClassworkProvider(classRoom.id)).whenData((l) =>
        l.where((w) => !w.dueDate.isBefore(today)).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate)));
    return SectionCard(
      title: 'Upcoming Classwork',
      actionLabel: 'View all',
      onAction: () => context.go(Routes.classDetail(classRoom.id, ClassTab.classwork)),
      child: AsyncValueView<List<ClassworkItem>>(
        value: upcoming,
        data: (items) {
          if (items.isEmpty) return const EmptyNote('Nothing upcoming for this class.');
          return Column(
            children: [for (final w in items.take(4)) _UpcomingRow(item: w)],
          );
        },
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});

  final ClassworkItem item;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (anchor) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showAnchoredPopover<void>(
            context: anchor,
            builder: (_) => ClassworkDetailsPopover(item: item),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ToneIcon(item.type.icon, tone: item.type.tone, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
                      Text(item.headline, style: AppText.meta),
                      if (item.description.isNotEmpty)
                        Text(item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.meta.copyWith(color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Pill(item.status.displayLabel, tone: item.status.tone, dot: true),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 16, color: AppColors.inkSoft),
                        const SizedBox(width: 6),
                        Text(shortDate(item.dueDate), style: AppText.meta.copyWith(fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Recent Class Activity',
      actionLabel: 'View all',
      onAction: () => showSidePanel<void>(
        context: context,
        builder: (_) => _ActivityPanel(classId: classId),
      ),
      child: AsyncValueView<List<ActivityEntry>>(
        value: ref.watch(classActivityProvider(classId)),
        data: (items) {
          if (items.isEmpty) return const EmptyNote('No activity in this class yet.');
          return Column(children: [for (final a in items.take(5)) ActivityRow(entry: a)]);
        },
      ),
    );
  }
}

class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          ToneIcon(entry.kind.icon, tone: entry.kind.tone, size: 36, circle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                if (entry.subtitle.isNotEmpty)
                  Text(entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(timeAgo(entry.createdAt), style: AppText.meta.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActivityPanel extends ConsumerWidget {
  const _ActivityPanel({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(title: 'Class Activity'),
          const SizedBox(height: 10),
          Expanded(
            child: AsyncValueView<List<ActivityEntry>>(
              value: ref.watch(classActivityProvider(classId)),
              data: (items) => items.isEmpty
                  ? const EmptyNote('No activity yet.')
                  : ListView(children: [for (final a in items) ActivityRow(entry: a)]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends ConsumerWidget {
  const _SupportCard({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged = ref
        .watch(classStudentsProvider(classId))
        .whenData((l) => flagStudents(l, DateTime.now()));
    return SectionCard(
      title: 'Students Needing Support',
      actionLabel: 'View all',
      onAction: () => context.go(Routes.students(classId: classId)),
      child: AsyncValueView<List<FlaggedStudent>>(
        value: flagged,
        data: (items) {
          if (items.isEmpty) return const EmptyNote('Everyone in this class is on track.');
          return Column(
            children: [
              for (final f in items.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      InitialsAvatar(
                          initials: f.student.initials, tone: toneForName(f.student.name), size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.student.name, style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                            Text(
                              '${f.student.missingCount} missing works • '
                              '${percent(f.student.averageScore)} average score',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.meta.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Pill('Needs Support', tone: f.flag.level.tone, dot: true),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => showStudentPanel(context, f.student),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ClassAnnouncements extends ConsumerWidget {
  const _ClassAnnouncements({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Recent Announcements',
      actionLabel: 'View all',
      onAction: () => context.go(Routes.classDetail(classId, ClassTab.stream)),
      child: AsyncValueView<List<Announcement>>(
        value: ref.watch(classAnnouncementsProvider(classId)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyNote('No announcements yet.',
                actionLabel: 'Post one',
                onAction: () => showAnnouncementForm(context, classId: classId));
          }
          return Column(
            children: [
              for (final a in items.take(3)) AnnouncementTile(announcement: a, compact: true),
            ],
          );
        },
      ),
    );
  }
}
