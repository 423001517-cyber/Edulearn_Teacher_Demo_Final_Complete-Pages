import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../providers/dashboard_providers.dart';

class DashboardStats extends ConsumerWidget {
  const DashboardStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(visibleStudentsProvider);
    final classCount = ref.watch(visibleClassesProvider).valueOrNull?.length ?? 0;
    final selected = ref.watch(selectedClassIdProvider);

    return ResponsiveGrid(
      children: [
        StatCard(
          icon: Icons.groups_rounded,
          tone: Tone.green,
          label: 'Students',
          value: students.whenData((l) => '${l.length}'),
          caption: 'Across $classCount ${classCount == 1 ? 'class' : 'classes'}',
          watermark: Icons.groups_outlined,
          onTap: () => context.go(Routes.students(classId: selected)),
        ),
        StatCard(
          icon: Icons.bolt_rounded,
          tone: Tone.blue,
          label: 'Active Quests',
          value: ref.watch(activeQuestCountProvider).whenData((n) => '$n'),
          caption: 'Ongoing this week',
          watermark: Icons.assignment_turned_in_outlined,
          onTap: () => context.go(Routes.section(NavSection.classwork, classId: selected)),
        ),
        StatCard(
          icon: Icons.description_outlined,
          tone: Tone.amber,
          label: 'To Review',
          value: ref.watch(visiblePendingSubmissionsProvider).whenData((l) => '${l.length}'),
          caption: 'Student submissions',
          watermark: Icons.description_outlined,
          onTap: () => context.go(Routes.section(NavSection.submissions, classId: selected)),
        ),
        StatCard(
          icon: Icons.priority_high_rounded,
          tone: Tone.red,
          label: 'Missing Work',
          value: ref.watch(missingWorkCountProvider).whenData((n) => '$n'),
          caption: 'Students behind',
          watermark: Icons.person_outline_rounded,
          onTap: () => context.go(selected == null
              ? Routes.students()
              : Routes.reports(classId: selected, panel: 'missing')),
        ),
      ],
    );
  }
}
