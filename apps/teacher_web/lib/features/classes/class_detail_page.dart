import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/data_providers.dart';
import '../classwork/quick_create_dialog.dart';
import '../shell/top_bar.dart';
import '../students/students_table.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/classwork_tab.dart';
import 'tabs/gradebook_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/stream_tab.dart';
import 'widgets/class_actions.dart';

/// `/classes/:classId?tab=…` — the "Open Class" page.
class ClassDetailPage extends ConsumerWidget {
  const ClassDetailPage({super.key, required this.classId, required this.tab});

  final String classId;
  final ClassTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cls = ref.watch(classProvider(classId));
    return cls.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: ErrorNote(error: e)),
      data: (c) {
        if (c == null) return const _NotFound();
        return PageScaffold(
          header: _Breadcrumb(classRoom: c),
          children: [
            if (c.isArchived) _ArchivedBanner(classRoom: c),
            _Hero(classRoom: c),
            _TabBar(classId: c.id, current: tab),
            switch (tab) {
              ClassTab.overview => OverviewTab(classRoom: c),
              ClassTab.stream => StreamTab(classRoom: c),
              ClassTab.classwork => ClassworkTab(classRoom: c),
              ClassTab.students => StudentsTable(classId: c.id),
              ClassTab.gradebook => GradebookTab(classRoom: c),
              ClassTab.analytics => AnalyticsTab(classRoom: c),
            },
          ],
        );
      },
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) {
    final crumbs = Row(
      children: [
        TextButton.icon(
          onPressed: () => context.go(Routes.classes),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Classes'),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(classRoom.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.meta.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 560) return crumbs;
      return Row(children: [Expanded(child: crumbs), const TopBarControls()]);
    });
  }
}

class _ArchivedBanner extends ConsumerWidget {
  const _ArchivedBanner({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.archive_outlined, color: AppColors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'This class is archived. Lessons, submissions, grades and reports are preserved.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: () => runClassAction(context, ref, classRoom, ClassAction.restore),
            child: const Text('Restore Class'),
          ),
        ],
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(c.name, style: AppText.greeting.copyWith(fontSize: 28)),
            ClassStatusBadge(classRoom: c),
          ],
        ),
        Text(c.subject, style: AppText.meta.copyWith(fontSize: 16)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.groups_rounded, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Text('${c.studentCount} students', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            ClassCodeChip(classRoom: c),
          ],
        ),
      ],
    );
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (!c.isArchived)
          FilledButton.icon(
            onPressed: () => showQuickCreate(context, classId: c.id),
            icon: const Icon(Icons.post_add_rounded, size: 20),
            label: const Text('Create Classwork'),
          ),
        OutlinedButton.icon(
          onPressed: () => context.go(Routes.classSettings(c.id)),
          icon: const Icon(Icons.settings_outlined, size: 20),
          label: const Text('Class Settings'),
        ),
        ClassActionsMenu(classRoom: c, includeOpen: false),
      ],
    );

    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClassThumbnail(classRoom: c, width: double.infinity, height: 170, radius: 0),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 16), actions],
                ),
              ),
            ],
          );
        }
        final medium = box.maxWidth < 1150;
        return Row(
          children: [
            ClassThumbnail(
              classRoom: c,
              width: box.maxWidth * (medium ? 0.3 : 0.34),
              height: medium ? 230 : 200,
              radius: 0,
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 16, bottom: 16),
                child: medium
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [details, const SizedBox(height: 16), actions],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [Expanded(child: details), const SizedBox(width: 12), actions],
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.classId, required this.current});

  final String classId;
  final ClassTab current;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in ClassTab.values)
              InkWell(
                onTap: () => context.go(Routes.classDetail(classId, t)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t == current ? AppColors.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(t.icon,
                          size: 20, color: t == current ? AppColors.primary : AppColors.inkSoft),
                      const SizedBox(width: 8),
                      Text(t.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t == current ? AppColors.primary : AppColors.ink,
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 44, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text("This class doesn't exist or isn't assigned to you.",
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go(Routes.classes), child: const Text('Back to Classes')),
        ],
      ),
    );
  }
}
