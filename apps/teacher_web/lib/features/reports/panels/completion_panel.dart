import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/navigation.dart';
import '../../../providers/classes_providers.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/reports_providers.dart';
import '../../students/student_support_panel.dart';
import '../report_actions.dart';
import 'panel_frame.dart';

class CompletionPanel extends ConsumerWidget {
  const CompletionPanel({super.key, required this.classRoom, required this.period});

  final ClassRoom classRoom;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    final now = DateTime.now();
    final metric = ref.watch(reportSummaryProvider((c.id, period))).valueOrNull?.completion;
    final items = ref.watch(classClassworkProvider(c.id)).valueOrNull ?? const [];
    final b = completionBreakdown(items, c.studentCount, period.range(now), now);
    final behind = (ref.watch(classStudentsProvider(c.id)).valueOrNull ?? const <Student>[])
        .where((s) => s.missingCount > 0)
        .toList()
      ..sort((x, y) => y.missingCount.compareTo(x.missingCount));

    return ReportPanelFrame(
      title: 'Completion Details',
      icon: Icons.bar_chart_rounded,
      tone: Tone.green,
      value: percent(metric?.value ?? c.completionRate),
      deltaText: deltaLabel(metric?.delta, period.comparisonLabel),
      deltaColor: deltaColor(metric?.delta),
      primaryLabel: 'View Classwork',
      onPrimary: () {
        Navigator.pop(context);
        goTo(Routes.classDetail(c.id, ClassTab.classwork));
      },
      onDownload: () => exportPanelPdf(ref, c, period, 'Completion', [
        ReportSection('Status', lines: [
          'Completed: ${b.completed}',
          'Ongoing: ${b.ongoing}',
          'Overdue: ${b.overdue}',
        ]),
        ReportSection('Completion by activity',
            lines: [for (final a in b.byActivity) '${a.label}: ${percent(a.rate)}']),
        ReportSection('Students behind',
            table: ReportTable(['Student', 'No.', 'Missing activities'], [
              for (final s in behind) [s.name, s.studentNumber, '${s.missingCount}'],
            ])),
      ]),
      children: [
        Row(
          children: [
            CountBox(icon: Icons.check_circle_rounded, tone: Tone.green, count: b.completed, label: 'Completed'),
            const SizedBox(width: 10),
            CountBox(icon: Icons.schedule_rounded, tone: Tone.amber, count: b.ongoing, label: 'Ongoing'),
            const SizedBox(width: 10),
            CountBox(icon: Icons.error_rounded, tone: Tone.red, count: b.overdue, label: 'Overdue'),
          ],
        ),
        const PanelSectionTitle('Completion by Activity'),
        if (b.byActivity.isEmpty)
          const EmptyNote('No graded work in this period yet.')
        else
          PanelBox(children: [for (final a in b.byActivity) RateRow(label: a.label, rate: a.rate)]),
        const PanelSectionTitle('Students Behind'),
        if (behind.isEmpty)
          const EmptyNote('No one is behind. 🎉')
        else
          PanelBox(children: [for (final s in behind.take(6)) _BehindRow(student: s)]),
      ],
    );
  }
}

class _BehindRow extends StatelessWidget {
  const _BehindRow({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          InitialsAvatar(initials: s.firstName.isEmpty ? '?' : s.firstName[0], tone: toneForName(s.name), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                Text(s.numberLabel, style: AppText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Pill('${s.missingCount} ${s.missingCount == 1 ? 'activity' : 'activities'}',
              tone: s.missingCount >= 3 ? Tone.red : Tone.amber),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => showStudentPanel(context, s), child: const Text('View')),
        ],
      ),
    );
  }
}
