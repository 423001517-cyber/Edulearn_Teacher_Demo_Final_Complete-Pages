import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation.dart';
import '../../providers/classes_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/reports_providers.dart';
import 'panels/attendance_panel.dart';
import 'panels/completion_panel.dart';
import 'panels/missing_work_panel.dart';
import 'panels/score_panel.dart';

/// The four stat-card detail panels. The enum name is the `?panel=` value.
enum ReportPanel {
  completion('Completion'),
  score('Average Score'),
  attendance('Attendance'),
  missing('Missing Work');

  const ReportPanel(this.label);
  final String label;

  static ReportPanel? parse(String? v) {
    for (final p in values) {
      if (p.name == v) return p;
    }
    return null;
  }
}

Future<void> openReportPanel(
  BuildContext context,
  ReportPanel panel,
  ClassRoom classRoom,
  ReportPeriod period,
) {
  return showSidePanel<void>(
    context: context,
    width: panel == ReportPanel.missing ? 560 : 440,
    builder: (_) => switch (panel) {
      ReportPanel.completion => CompletionPanel(classRoom: classRoom, period: period),
      ReportPanel.score => ScorePanel(classRoom: classRoom, period: period),
      ReportPanel.attendance => AttendancePanel(classRoom: classRoom, period: period),
      ReportPanel.missing => MissingWorkPanel(classRoom: classRoom, period: period),
    },
  );
}

/// Builds a file, uploads it to Cloud Storage, then opens it. On the web the
/// link is offered in a toast (a user tap avoids popup blockers).
Future<void> runExport(WidgetRef ref, String label, Future<String> Function(ReportExporter) job) async {
  showToast('Preparing $label…');
  try {
    final url = await job(ref.read(reportExporterProvider));
    final uri = Uri.parse(url);
    if (kIsWeb) {
      showToast('$label is ready', actionLabel: 'Open', onAction: () => launchUrl(uri));
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    showToast("Couldn't create the $label: $e");
  }
}

String _signed(double? delta, {bool asPercent = true}) =>
    delta == null ? '' : ' (${deltaLabel(delta, 'vs previous period', asPercent: asPercent)})';

/// Everything on the Class Reports page, as data for PDF/CSV.
class ReportData {
  ReportData({
    required this.classRoom,
    required this.period,
    required this.summary,
    required this.students,
  });

  final ClassRoom classRoom;
  final ReportPeriod period;
  final ReportSummary? summary;
  final List<Student> students;

  static ReportData read(WidgetRef ref, ClassRoom c, ReportPeriod period) => ReportData(
        classRoom: c,
        period: period,
        summary: ref.read(reportSummaryProvider((c.id, period))).valueOrNull,
        students: ref.read(classStudentsProvider(c.id)).valueOrNull ?? const [],
      );

  String get title => 'Class Report – ${classRoom.name}';
  String get subtitle =>
      '${classRoom.subject} · ${period.label} · Generated ${fullDate(DateTime.now())}';
  String get slug => fileSlug('${classRoom.name} ${period.label}');

  ReportSection summarySection() {
    final s = summary;
    return ReportSection('Summary', lines: [
      'Completion: ${percent(s?.completion.value)}${_signed(s?.completion.delta)}',
      'Average score: ${percent(s?.averageScore.value)}${_signed(s?.averageScore.delta)}',
      'Attendance: ${percent(s?.attendance.value)}${_signed(s?.attendance.delta)}',
      'Students with missing work: ${s?.missingWork.value?.round() ?? '—'}'
          '${_signed(s?.missingWork.delta, asPercent: false)}',
    ]);
  }

  ReportSection trendSection() => ReportSection(
        'Monthly trend',
        table: ReportTable(
          ['Month', 'Completion', 'Average score', 'Attendance', 'Missing work'],
          [
            for (final m in summary?.trend ?? const <MonthlyStat>[])
              [
                '${monthAbbr(m.month)} ${m.month.year}',
                percent(m.completion),
                percent(m.averageScore),
                percent(m.attendance),
                '${m.missingWork}',
              ],
          ],
        ),
      );

  ReportTable studentTable() {
    final now = DateTime.now();
    final sorted = [...students]..sort((a, b) => a.name.compareTo(b.name));
    return ReportTable(
      ['Student', 'No.', 'Attendance', 'Quest completion', 'Average score', 'Missing work', 'Status'],
      [
        for (final s in sorted)
          [
            s.name,
            s.studentNumber,
            percent(s.attendanceRate),
            percent(s.questProgress),
            percent(s.averageScore),
            '${s.missingCount}',
            s.standing(now).label,
          ],
      ],
    );
  }
}

Future<void> exportFullPdf(WidgetRef ref, ClassRoom c, ReportPeriod period) {
  final d = ReportData.read(ref, c, period);
  final items = ref.read(classClassworkProvider(c.id)).valueOrNull ?? const [];
  final range = period.range(DateTime.now());
  final breakdown = completionBreakdown(items, c.studentCount, range, DateTime.now());
  final dist = scoreDistribution(d.students);
  return runExport(
    ref,
    'PDF report',
    (x) => x.exportPdf(
      title: d.title,
      subtitle: d.subtitle,
      fileName: d.slug,
      sections: [
        d.summarySection(),
        d.trendSection(),
        ReportSection('Completion by activity', lines: [
          'Completed: ${breakdown.completed} · Ongoing: ${breakdown.ongoing} · Overdue: ${breakdown.overdue}',
          for (final a in breakdown.byActivity) '${a.label}: ${percent(a.rate)}',
        ]),
        ReportSection('Score distribution', lines: [
          for (final e in dist.entries) '${e.key.label}: ${e.value} students',
        ]),
        ReportSection('Student progress', table: d.studentTable()),
      ],
    ),
  );
}

Future<void> exportStudentCsv(WidgetRef ref, ClassRoom c, ReportPeriod period) {
  final d = ReportData.read(ref, c, period);
  return runExport(ref, 'CSV export', (x) => x.exportCsv(table: d.studentTable(), fileName: d.slug));
}

/// "Download Report" inside a detail panel.
Future<void> exportPanelPdf(
  WidgetRef ref,
  ClassRoom c,
  ReportPeriod period,
  String panelTitle,
  List<ReportSection> sections,
) {
  final d = ReportData.read(ref, c, period);
  return runExport(
    ref,
    '$panelTitle report',
    (x) => x.exportPdf(
      title: '$panelTitle – ${c.name}',
      subtitle: d.subtitle,
      fileName: fileSlug('${c.name} $panelTitle ${period.label}'),
      sections: [d.summarySection(), ...sections],
    ),
  );
}
