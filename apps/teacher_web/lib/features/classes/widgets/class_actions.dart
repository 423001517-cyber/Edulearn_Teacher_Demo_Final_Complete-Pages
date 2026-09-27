import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/navigation.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import 'class_dialogs.dart';
import 'quick_view_panel.dart';

/// The "Class Actions" popover: Open Class, Quick View, Copy Class Code,
/// View Students, View Reports, Archive Class.
enum ClassAction { open, quickView, copyCode, viewStudents, viewReports, settings, archive, restore }

List<PopupMenuEntry<ClassAction>> classActionItems(ClassRoom c, {bool includeOpen = true}) => [
      if (includeOpen) menuItem(ClassAction.open, Icons.open_in_new_rounded, 'Open Class'),
      if (includeOpen) menuItem(ClassAction.quickView, Icons.visibility_outlined, 'Quick View'),
      menuItem(ClassAction.copyCode, Icons.content_copy_outlined, 'Copy Class Code'),
      menuItem(ClassAction.viewStudents, Icons.groups_outlined, 'View Students'),
      menuItem(ClassAction.viewReports, Icons.bar_chart_rounded, 'View Reports'),
      menuItem(ClassAction.settings, Icons.tune_rounded, 'Class Settings'),
      const PopupMenuDivider(),
      if (c.isArchived)
        menuItem(ClassAction.restore, Icons.unarchive_outlined, 'Restore Class')
      else
        menuItem(ClassAction.archive, Icons.archive_outlined, 'Archive Class', destructive: true),
    ];

Future<void> runClassAction(BuildContext context, WidgetRef ref, ClassRoom c, ClassAction action) async {
  switch (action) {
    case ClassAction.open:
      goTo(Routes.classDetail(c.id));
    case ClassAction.quickView:
      showQuickView(context, c);
    case ClassAction.copyCode:
      await copyClassCode(c);
    case ClassAction.viewStudents:
      goTo(Routes.students(classId: c.id));
    case ClassAction.viewReports:
      goTo(Routes.reports(classId: c.id));
    case ClassAction.settings:
      showClassSettings(context, c);
    case ClassAction.archive:
      final repo = ref.read(classesRepositoryProvider);
      final selected = ref.read(selectedClassIdProvider.notifier);
      final ok = await showArchiveClassDialog(context, c);
      if (!ok) return;
      await repo.archiveClass(c.id);
      // The dashboard only shows active classes; drop the filter if it
      // pointed at this one.
      if (selected.state == c.id) selected.state = null;
      showToast('${c.name} archived', actionLabel: 'Undo', onAction: () => repo.restoreClass(c.id));
    case ClassAction.restore:
      await ref.read(classesRepositoryProvider).restoreClass(c.id);
      showToast('${c.name} is active again');
  }
}

Future<void> copyClassCode(ClassRoom c) async {
  await Clipboard.setData(ClipboardData(text: c.classCode));
  showToast('Class code copied — ${c.classCode} is ready to paste.');
}

/// The bordered ⋮ square on class cards.
class ClassActionsMenu extends ConsumerWidget {
  const ClassActionsMenu({super.key, required this.classRoom, this.includeOpen = true});

  final ClassRoom classRoom;
  final bool includeOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<ClassAction>(
      tooltip: 'Class actions',
      position: PopupMenuPosition.under,
      itemBuilder: (_) => classActionItems(classRoom, includeOpen: includeOpen),
      onSelected: (a) => runClassAction(context, ref, classRoom, a),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.buttonBorder),
        ),
        child: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
      ),
    );
  }
}

/// "Class code RIZAL-4A [copy]"
class ClassCodeChip extends StatelessWidget {
  const ClassCodeChip({super.key, required this.classRoom, this.dense = false});

  final ClassRoom classRoom;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, dense ? 6 : 8, 6, dense ? 6 : 8),
      decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.key_rounded, size: 18, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Class code', style: AppText.meta.copyWith(fontSize: 11)),
                Text(classRoom.classCode.isEmpty ? 'Pending' : classRoom.classCode,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Copy class code',
            onPressed: classRoom.classCode.isEmpty ? null : () => copyClassCode(classRoom),
            icon: const Icon(Icons.content_copy_outlined, size: 18, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Green "● Active" / grey "Archived" badge.
class ClassStatusBadge extends StatelessWidget {
  const ClassStatusBadge({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) => classRoom.isArchived
      ? const Pill('Archived', tone: Tone.neutral, dot: true)
      : const Pill('Active', tone: Tone.green, dot: true);
}
