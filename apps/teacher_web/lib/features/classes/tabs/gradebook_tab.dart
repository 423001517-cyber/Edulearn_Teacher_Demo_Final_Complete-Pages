import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../providers/classes_providers.dart';

/// Per-assessment results for the class (the full gradebook module links
/// from here).
class GradebookTab extends ConsumerWidget {
  const GradebookTab({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    return SectionCard(
      icon: Icons.table_chart_outlined,
      title: 'Assessment Results',
      trailing: LinkButton(
        label: 'Open Gradebook',
        onTap: () => context.go(Routes.section(NavSection.gradebook, classId: c.id)),
      ),
      child: AsyncValueView<List<ClassworkItem>>(
        value: ref.watch(classClassworkProvider(c.id)),
        data: (all) {
          final graded = all.where((w) => w.type.isGraded && w.scoredCount > 0).toList();
          if (graded.isEmpty) return const EmptyNote('No graded work returned yet.');
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: AppText.label,
              columns: const [
                DataColumn(label: Text('Classwork')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Due')),
                DataColumn(label: Text('Submitted'), numeric: true),
                DataColumn(label: Text('Graded'), numeric: true),
                DataColumn(label: Text('Average'), numeric: true),
              ],
              rows: [
                for (final w in graded)
                  DataRow(cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(w.type.icon, size: 18, color: w.type.tone.fg),
                      const SizedBox(width: 8),
                      Text(w.title),
                    ])),
                    DataCell(Text(w.type.label)),
                    DataCell(Text(dayMonth(w.dueDate))),
                    DataCell(Text('${w.submittedCount}/${c.studentCount}')),
                    DataCell(Text('${w.scoredCount}')),
                    DataCell(Text(percent(w.averageScore),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (w.averageScore ?? 1) < 0.75 ? AppColors.red : AppColors.ink,
                        ))),
                  ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
