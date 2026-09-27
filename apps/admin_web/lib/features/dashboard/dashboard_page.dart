import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/admin_providers.dart';
import '../classes/class_dialogs.dart';
import '../common/admin_widgets.dart';
import '../requests/request_widgets.dart';
import '../shell/top_bar.dart';
import '../teachers/teacher_dialogs.dart';

/// `/` — the admin homepage: school at a glance and what needs a decision.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      header: _Header(),
      children: [
        _Stats(),
        TwoColumn(
          left: [_ClassesOverview(), _PerformanceByGrade()],
          right: [_PendingRequests(), _NeedsAttention(), _TeachersCard()],
          narrowOrder: [_PendingRequests(), _ClassesOverview(), _NeedsAttention(), _PerformanceByGrade(), _TeachersCard()],
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? const SchoolSettings();
    final now = DateTime.now();
    final greeting = Row(
      children: [
        Icon(now.hour < 18 ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
            color: const Color(0xFFF6B524), size: 36),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${greetingFor(now)}, ${admin?.firstName ?? 'Admin'}', style: AppText.greeting),
              Text(
                [settings.schoolName, if (settings.schoolYear.isNotEmpty) 'School Year ${settings.schoolYear}']
                    .join(' · '),
                style: AppText.meta.copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 560) return greeting;
      return Row(children: [Expanded(child: greeting), const AdminTopBarControls()]);
    });
  }
}

class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers = ref.watch(teachersProvider);
    final classes = ref.watch(activeClassesProvider);
    final students = ref.watch(studentsProvider);
    final activeIds = {for (final c in classes.valueOrNull ?? const <ClassRoom>[]) c.id};
    final pending = ref.watch(pendingRequestCountProvider);
    return ResponsiveGrid(
      children: [
        StatCard(
          icon: Icons.badge_outlined,
          tone: Tone.green,
          label: 'Teachers',
          value: teachers.whenData((l) => '${l.where((t) => !t.isDisabled).length}'),
          caption: 'Active accounts',
          watermark: Icons.badge_outlined,
          onTap: () => context.go(AdminRoutes.teachers()),
        ),
        StatCard(
          icon: Icons.groups_rounded,
          tone: Tone.blue,
          label: 'Students',
          value: students.whenData((l) => '${l.where((s) => activeIds.contains(s.classId)).length}'),
          caption: 'In active classes',
          watermark: Icons.groups_outlined,
          onTap: () => context.go(AdminRoutes.students()),
        ),
        StatCard(
          icon: Icons.menu_book_outlined,
          tone: Tone.amber,
          label: 'Active Classes',
          value: classes.whenData((l) => '${l.length}'),
          caption: 'With official codes',
          watermark: Icons.menu_book_outlined,
          onTap: () => context.go(AdminRoutes.classes()),
        ),
        StatCard(
          icon: Icons.move_to_inbox_outlined,
          tone: pending > 0 ? Tone.red : Tone.neutral,
          label: 'Class Requests',
          value: ref.watch(requestsProvider).whenData((_) => '$pending'),
          caption: pending == 1 ? 'Waiting for you' : 'Waiting for a decision',
          watermark: Icons.inbox_outlined,
          onTap: () => context.go(AdminRoutes.requests),
        ),
      ],
    );
  }
}

class _ClassesOverview extends ConsumerWidget {
  const _ClassesOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers = ref.watch(teacherByIdProvider);
    return SectionCard(
      icon: Icons.menu_book_outlined,
      title: 'Classes Overview',
      actionLabel: 'View all classes',
      onAction: () => context.go(AdminRoutes.classes()),
      child: AsyncValueView<List<ClassRoom>>(
        value: ref.watch(activeClassesProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyNote('No classes yet.',
                actionLabel: 'Create a class', onAction: () => showCreateClassDialog(context));
          }
          return Column(
            children: [
              for (var i = 0; i < list.length && i < 6; i++) ...[
                if (i > 0) const Divider(),
                InkWell(
                  onTap: () => context.go(AdminRoutes.students(classId: list[i].id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: LayoutBuilder(builder: (context, box) {
                      final c = list[i];
                      final info = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: AppText.itemTitle),
                          Text('${teachers[c.teacherId]?.displayName ?? 'Unassigned'} · ${c.studentCount} students',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
                        ],
                      );
                      return Row(
                        children: [
                          ClassThumbnail(classRoom: c, width: 72, height: 50),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: info),
                          if (box.maxWidth > 480) ...[
                            Expanded(flex: 4, child: RateCell(c.completionRate)),
                            CodeChip(c.classCode),
                          ],
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PerformanceByGrade extends ConsumerWidget {
  const _PerformanceByGrade();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      icon: Icons.bar_chart_rounded,
      title: 'Performance by Grade',
      actionLabel: 'School reports',
      onAction: () => context.go(AdminRoutes.reports()),
      child: AsyncValueView<List<ClassRoom>>(
        value: ref.watch(activeClassesProvider),
        data: (list) {
          final grades = <int, List<ClassRoom>>{};
          for (final c in list) {
            grades.putIfAbsent(c.gradeLevel, () => []).add(c);
          }
          if (grades.isEmpty) return const EmptyNote('Results appear once classes have work.');
          final keys = grades.keys.toList()..sort();
          double avg(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
          return Column(
            children: [
              for (final g in keys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'Grade $g', style: AppText.itemTitle),
                        TextSpan(
                          text: '  ·  ${grades[g]!.length} ${grades[g]!.length == 1 ? 'class' : 'classes'} · '
                              '${grades[g]!.fold<int>(0, (n, c) => n + c.studentCount)} students',
                          style: AppText.meta,
                        ),
                      ])),
                      const SizedBox(height: 8),
                      _Bar('Completion', avg(grades[g]!.map((c) => c.completionRate)), AppColors.primary),
                      const SizedBox(height: 6),
                      _Bar('Average score', avg(grades[g]!.map((c) => c.averageScore)), AppColors.blue),
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

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.meta)),
          Expanded(child: ProgressBar(value: value, color: color)),
          SizedBox(
            width: 48,
            child: Text(percent(value),
                textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
}

class _PendingRequests extends ConsumerWidget {
  const _PendingRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      icon: Icons.move_to_inbox_outlined,
      title: 'Class Requests',
      actionLabel: 'View all',
      onAction: () => context.go(AdminRoutes.requests),
      child: AsyncValueView<List<ClassRequest>>(
        value: ref.watch(requestsProvider),
        data: (all) {
          final pending = all.where((r) => r.isPending).toList();
          if (pending.isEmpty) return const EmptyNote('No pending requests.');
          return Column(
            children: [
              for (var i = 0; i < pending.length && i < 3; i++) ...[
                if (i > 0) const Divider(),
                RequestCard(request: pending[i], dense: true),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Classes with low completion or several students behind.
class _NeedsAttention extends ConsumerWidget {
  const _NeedsAttention();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byClass = ref.watch(studentsByClassProvider);
    final teachers = ref.watch(teacherByIdProvider);
    return SectionCard(
      icon: Icons.flag_outlined,
      title: 'Needs Attention',
      child: AsyncValueView<List<ClassRoom>>(
        value: ref.watch(activeClassesProvider),
        data: (list) {
          final flagged = <({ClassRoom c, String reason, Tone tone})>[];
          for (final c in list) {
            final behind = (byClass[c.id] ?? const <Student>[]).where((s) => s.missingCount > 0).length;
            if (teachers[c.teacherId]?.isDisabled ?? true) {
              flagged.add((c: c, reason: 'Teacher account disabled', tone: Tone.red));
            } else if (c.studentCount > 0 && c.completionRate < 0.6) {
              flagged.add((c: c, reason: '${percent(c.completionRate)} completion', tone: Tone.amber));
            } else if (behind >= 3) {
              flagged.add((c: c, reason: '$behind students behind', tone: Tone.amber));
            }
          }
          if (flagged.isEmpty) return const EmptyNote('All classes are on track.');
          return Column(
            children: [
              for (final f in flagged.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.go(AdminRoutes.students(classId: f.c.id)),
                  title: Text(f.c.name, style: AppText.itemTitle),
                  subtitle: Text(teachers[f.c.teacherId]?.displayName ?? 'Unassigned', style: AppText.meta),
                  trailing: Pill(f.reason, tone: f.tone),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TeachersCard extends ConsumerWidget {
  const _TeachersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesBy = ref.watch(classesByTeacherProvider);
    return SectionCard(
      icon: Icons.badge_outlined,
      title: 'Teachers',
      trailing: LinkButton(label: 'Add teacher', showArrow: false, onTap: () => showAddTeacherDialog(context)),
      child: AsyncValueView<List<Teacher>>(
        value: ref.watch(teachersProvider),
        data: (list) {
          if (list.isEmpty) return const EmptyNote('No teachers yet.');
          return Column(
            children: [
              for (final t in list.take(5))
                InkWell(
                  onTap: () => showTeacherPanel(context, t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: PersonCell(name: t.displayName, subtitle: t.email ?? '', size: 36)),
                        if (t.isDisabled)
                          const Pill('Disabled', tone: Tone.red)
                        else
                          Pill('${classesBy[t.uid]?.length ?? 0} classes', tone: Tone.blue),
                      ],
                    ),
                  ),
                ),
              if (list.length > 5)
                Align(
                  alignment: Alignment.centerLeft,
                  child: LinkButton(label: 'All ${list.length} teachers', onTap: () => context.go(AdminRoutes.teachers())),
                ),
            ],
          );
        },
      ),
    );
  }
}
