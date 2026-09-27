import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/navigation.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/reports_providers.dart';
import '../../students/student_support_panel.dart';
import '../report_actions.dart';
import 'panel_frame.dart';

class AttendancePanel extends ConsumerWidget {
  const AttendancePanel({super.key, required this.classRoom, required this.period});

  final ClassRoom classRoom;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    final metric = ref.watch(reportSummaryProvider((c.id, period))).valueOrNull?.attendance;
    final days = ref.watch(attendanceProvider(c.id)).valueOrNull ?? const <AttendanceDay>[];
    final latest = latestAttendance(days);
    final trend = weekTrend(days);
    final concerns = (ref.watch(classStudentsProvider(c.id)).valueOrNull ?? const <Student>[])
        .where((s) => s.hasAttendanceConcern)
        .toList()
      ..sort((x, y) => (y.absences * 2 + y.lateCount).compareTo(x.absences * 2 + x.lateCount));

    String concernLabel(Student s) => [
          if (s.absences >= 2) '${s.absences} absences',
          if (s.lateCount >= 3) '${s.lateCount} late records',
        ].join(' · ');

    return ReportPanelFrame(
      title: 'Attendance Details',
      icon: Icons.groups_rounded,
      tone: Tone.purple,
      value: percent(metric?.value),
      deltaText: deltaLabel(metric?.delta, period.comparisonLabel),
      deltaColor: deltaColor(metric?.delta),
      headerTrailing: Pill(period.label, tone: Tone.neutral),
      primaryLabel: 'View Attendance',
      onPrimary: () {
        Navigator.pop(context);
        goTo(Routes.section(NavSection.attendance, classId: c.id));
      },
      onDownload: () => exportPanelPdf(ref, c, period, 'Attendance', [
        if (latest != null)
          ReportSection('Latest school day (${fullDate(latest.date)})', lines: [
            'Present: ${latest.count(AttendanceMark.present)}',
            'Late: ${latest.count(AttendanceMark.late)}',
            'Absent: ${latest.count(AttendanceMark.absent)}',
          ]),
        ReportSection('Students with attendance concerns',
            table: ReportTable(['Student', 'Absences', 'Late records', 'Attendance rate'], [
              for (final s in concerns)
                [s.name, '${s.absences}', '${s.lateCount}', percent(s.attendanceRate)],
            ])),
      ]),
      children: [
        if (latest != null) ...[
          Text('Latest: ${shortDate(latest.date)}', style: AppText.meta),
          const SizedBox(height: 8),
          Row(
            children: [
              CountBox(
                  icon: Icons.how_to_reg_rounded,
                  tone: Tone.green,
                  count: latest.count(AttendanceMark.present),
                  label: 'Present'),
              const SizedBox(width: 10),
              CountBox(
                  icon: Icons.schedule_rounded,
                  tone: Tone.amber,
                  count: latest.count(AttendanceMark.late),
                  label: 'Late'),
              const SizedBox(width: 10),
              CountBox(
                  icon: Icons.error_rounded,
                  tone: Tone.red,
                  count: latest.count(AttendanceMark.absent),
                  label: 'Absent'),
            ],
          ),
        ] else
          const EmptyNote('No attendance taken yet.'),
        const PanelSectionTitle('Attendance Trend'),
        if (trend.rates.every((r) => r == null))
          const EmptyNote('No attendance this week.')
        else
          TrendLineChart(
            height: 180,
            showLegend: false,
            labels: trend.labels,
            lines: [ChartLine(name: 'Attendance', color: AppColors.chartGreen, values: trend.rates)],
          ),
        const PanelSectionTitle('Students with Attendance Concerns'),
        if (concerns.isEmpty)
          const EmptyNote('No attendance concerns right now.')
        else
          PanelBox(children: [
            for (final s in concerns.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    InitialsAvatar(
                        initials: s.firstName.isEmpty ? '?' : s.firstName[0],
                        tone: s.absences >= 2 ? Tone.red : Tone.purple,
                        size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                          Text(concernLabel(s), style: AppText.meta.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                        onPressed: () => showStudentPanel(context, s), child: const Text('View')),
                    const SizedBox(width: 6),
                    MoreMenu<String>(
                      items: [menuItem('remind', Icons.send_outlined, 'Send reminder')],
                      onSelected: (_) => showSendReminder(
                        context,
                        s,
                        message: 'Hi ${s.firstName}! We missed you in class. '
                            'Please make sure to attend on time this week.',
                      ),
                    ),
                  ],
                ),
              ),
          ]),
      ],
    );
  }
}
