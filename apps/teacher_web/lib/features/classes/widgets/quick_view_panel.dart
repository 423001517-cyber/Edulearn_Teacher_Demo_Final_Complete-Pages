import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/navigation.dart';
import '../../../providers/classes_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/data_providers.dart';
import '../../students/student_support_panel.dart';
import 'class_actions.dart';

Future<void> showQuickView(BuildContext context, ClassRoom c) => showSidePanel<void>(
      context: context,
      width: 440,
      builder: (_) => QuickViewPanel(classId: c.id, fallback: c),
    );

class QuickViewPanel extends ConsumerWidget {
  const QuickViewPanel({super.key, required this.classId, required this.fallback});

  final String classId;
  final ClassRoom fallback;

  void _go(BuildContext context, String location) {
    Navigator.pop(context);
    goTo(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(classProvider(classId)).valueOrNull ?? fallback;
    final missing = ref.watch(missingByClassProvider)[classId] ?? 0;
    final today = startOfDay(DateTime.now());
    final upcoming = ref.watch(classClassworkProvider(classId)).whenData((l) =>
        (l.where((w) => !w.dueDate.isBefore(today)).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate)))
            .take(3)
            .toList());
    final activity = ref.watch(classActivityProvider(classId));
    final support = ref.watch(classStudentsProvider(classId)).whenData(
        (l) => flagStudents(l, DateTime.now()).take(2).toList());

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClassThumbnail(classRoom: c, width: 110, height: 92, radius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(c.name, style: AppText.dialogTitle.copyWith(fontSize: 19)),
                            ClassStatusBadge(classRoom: c),
                          ],
                        ),
                        Text(c.subject, style: AppText.meta.copyWith(fontSize: 13.5)),
                        const SizedBox(height: 8),
                        ClassCodeChip(classRoom: c, dense: true),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              Row(
                children: [
                  _MiniStat(Icons.groups_rounded, Tone.neutral, '${c.studentCount}', 'Students'),
                  _MiniStat(Icons.description_outlined, Tone.neutral, '${c.questCount}', 'Active Quests'),
                  _MiniStat(Icons.bar_chart_rounded, Tone.green, percent(c.completionRate), 'Completion'),
                  _MiniStat(Icons.priority_high_rounded, Tone.red, '$missing', 'Missing'),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              _Header('Upcoming',
                  onViewAll: () => _go(context, Routes.classDetail(classId, ClassTab.classwork))),
              AsyncValueView<List<ClassworkItem>>(
                value: upcoming,
                loadingHeight: 60,
                data: (items) => items.isEmpty
                    ? const EmptyNote('Nothing due soon.')
                    : Column(
                        children: [
                          for (final w in items)
                            _Line(
                              icon: w.type.icon,
                              text: w.title,
                              trailing: 'Due ${dayMonth(w.dueDate)}',
                            ),
                        ],
                      ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
              _Header('Recent Activity', onViewAll: () => _go(context, Routes.classDetail(classId))),
              AsyncValueView<List<ActivityEntry>>(
                value: activity,
                loadingHeight: 60,
                data: (items) => items.isEmpty
                    ? const EmptyNote('No activity yet.')
                    : Column(
                        children: [
                          for (final a in items.take(3))
                            _Line(
                              icon: a.kind.icon,
                              iconColor: a.kind.tone.fg,
                              text: a.title,
                              trailing: timeAgo(a.createdAt),
                            ),
                        ],
                      ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
              _Header('Students Needing Support',
                  onViewAll: () => _go(context, Routes.students(classId: classId))),
              AsyncValueView<List<FlaggedStudent>>(
                value: support,
                loadingHeight: 60,
                data: (items) => items.isEmpty
                    ? const EmptyNote('Everyone in this class is on track.')
                    : Column(
                        children: [
                          for (final f in items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const ToneIcon(Icons.groups_rounded, tone: Tone.red, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f.student.name, style: AppText.itemTitle),
                                        Text(f.flag.label, style: AppText.meta),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showStudentPanel(rootContext, f.student);
                                    },
                                    child: const Text('View'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _go(context, Routes.classDetail(classId)),
                  child: ArrowLabel('Open Class'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _go(context, Routes.students(classId: classId)),
                  child: const Text('View Students'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.icon, this.tone, this.value, this.label);

  final IconData icon;
  final Tone tone;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: tone == Tone.neutral ? AppColors.ink : tone.fg, size: 24),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppText.sectionTitle.copyWith(fontSize: 15.5))),
            LinkButton(label: 'View all', onTap: onViewAll, showArrow: false),
          ],
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.trailing, this.iconColor});

  final IconData icon;
  final String text;
  final String trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 19, color: iconColor ?? AppColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
            ),
            const SizedBox(width: 8),
            Text(trailing, style: AppText.meta.copyWith(fontSize: 12.5)),
          ],
        ),
      );
}
