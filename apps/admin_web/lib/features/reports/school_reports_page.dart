import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';
import '../common/admin_widgets.dart';
import '../shell/top_bar.dart';

typedef _Row = ({ClassRoom c, String teacher, ReportSummary? s});

/// `/reports?period=` — every active class side by side, built from the same
/// monthly rollups the teacher website's Class Reports use.
class SchoolReportsPage extends ConsumerWidget {
  const SchoolReportsPage({super.key, required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(activeClassesProvider);
    final teachers = ref.watch(teacherByIdProvider);
    final rows = <_Row>[
      for (final c in classes.valueOrNull ?? const <ClassRoom>[])
        (
          c: c,
          teacher: teachers[c.teacherId]?.displayName ?? 'Unassigned',
          s: ref.watch(reportSummaryProvider((c.id, period))).valueOrNull,
        ),
    ];
    final school = _SchoolSummary.of(rows);

    return PageScaffold(
      header: const AdminPageHeader(
        icon: Icons.assessment_outlined,
        title: 'School Reports',
        subtitle: 'Completion, scores, attendance and missing work across every class.',
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterDropdown<ReportPeriod>(
              value: period,
              options: ReportPeriod.values,
              labelOf: (p) => p.label,
              minWidth: 180,
              onChanged: (p) => context.go(AdminRoutes.reports(period: p.name)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              onPressed: rows.isEmpty ? null : () => _export(ref, rows, school, pdf: true),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generate PDF'),
            ),
            FilledButton.icon(
              onPressed: rows.isEmpty ? null : () => _export(ref, rows, school, pdf: false),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        ResponsiveGrid(
          children: [
            _stat(classes, Icons.bar_chart_rounded, Tone.green, 'Completion', school.completion, school.completionDelta),
            _stat(classes, Icons.star_rounded, Tone.blue, 'Average Score', school.score, school.scoreDelta),
            _stat(classes, Icons.groups_rounded, Tone.purple, 'Attendance', school.attendance, school.attendanceDelta),
            StatCard(
              icon: Icons.priority_high_rounded,
              tone: Tone.red,
              label: 'Missing Work',
              value: classes.whenData((_) => '${school.missing}'),
              caption: school.missingDelta == null
                  ? 'Students behind'
                  : deltaLabel(school.missingDelta, period.comparisonLabel, asPercent: false),
              captionColor: deltaColor(school.missingDelta, lowerIsBetter: true),
            ),
          ],
        ),
        SectionCard(
          title: 'School Performance Trend',
          showDivider: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: school.trend.isEmpty
                ? const EmptyNote('Monthly results appear after the first nightly update.',
                    icon: Icons.insights_outlined)
                : TrendLineChart(
                    legendOnTop: true,
                    height: 240,
                    labels: [for (final m in school.trend) monthAbbr(m.month)],
                    lines: [
                      ChartLine(
                          name: 'Completion',
                          color: AppColors.chartGreen,
                          values: [for (final m in school.trend) m.completion]),
                      ChartLine(
                          name: 'Average Score',
                          color: AppColors.blue,
                          fill: false,
                          values: [for (final m in school.trend) m.averageScore]),
                      ChartLine(
                          name: 'Attendance',
                          color: AppColors.purple,
                          fill: false,
                          values: [for (final m in school.trend) m.attendance]),
                    ],
                  ),
          ),
        ),
        AsyncValueView<List<ClassRoom>>(
          value: classes,
          data: (_) => AdminTable<_Row>(
            noun: 'classes',
            emptyMessage: 'No active classes yet.',
            items: rows,
            columns: const [
              TableCol('Class', flex: 20),
              TableCol('Teacher', flex: 16),
              TableCol('Students', flex: 8),
              TableCol('Completion', flex: 13),
              TableCol('Avg Score', flex: 13),
              TableCol('Attendance', flex: 13),
              TableCol('Missing', flex: 10),
            ],
            cells: (r) => [
              Text(r.c.name, style: AppText.itemTitle),
              Text(r.teacher, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
              Text('${r.c.studentCount}', style: AppText.body),
              _MetricCell(r.s?.completion, period),
              _MetricCell(r.s?.averageScore, period),
              _MetricCell(r.s?.attendance, period),
              _MetricCell(r.s?.missingWork, period, count: true),
            ],
            compact: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(r.c.name, style: AppText.itemTitle),
                Text(
                  '${r.teacher} · Completion ${percent(r.s?.completion.value)} · '
                  'Avg ${percent(r.s?.averageScore.value)} · Attendance ${percent(r.s?.attendance.value)} · '
                  'Missing ${r.s?.missingWork.value?.round() ?? '—'}',
                  style: AppText.meta,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  StatCard _stat(AsyncValue<Object?> loading, IconData icon, Tone tone, String label, double? value, double? delta) =>
      StatCard(
        icon: icon,
        tone: tone,
        label: label,
        value: loading.whenData((_) => percent(value)),
        caption: deltaLabel(delta, period.comparisonLabel),
        captionColor: deltaColor(delta),
      );

  Future<void> _export(WidgetRef ref, List<_Row> rows, _SchoolSummary school, {required bool pdf}) async {
    final settings = ref.read(settingsProvider).valueOrNull ?? const SchoolSettings();
    final exporter = ref.read(reportExporterProvider);
    final table = ReportTable(
      ['Class', 'Code', 'Teacher', 'Students', 'Completion', 'Average score', 'Attendance', 'Missing work'],
      [
        for (final r in rows)
          [
            r.c.name,
            r.c.classCode,
            r.teacher,
            '${r.c.studentCount}',
            percent(r.s?.completion.value),
            percent(r.s?.averageScore.value),
            percent(r.s?.attendance.value),
            '${r.s?.missingWork.value?.round() ?? ''}',
          ],
      ],
    );
    final slug = fileSlug('${settings.schoolName} ${period.label}');
    showToast('Preparing ${pdf ? 'PDF' : 'CSV'}…');
    final url = await runAdminAction(() => pdf
        ? exporter.exportPdf(
            title: 'School Report – ${settings.schoolName}',
            subtitle: '${period.label}${settings.schoolYear.isEmpty ? '' : ' · School Year ${settings.schoolYear}'}'
                ' · Generated ${fullDate(DateTime.now())}',
            fileName: slug,
            sections: [
              ReportSection('School summary', lines: [
                'Completion: ${percent(school.completion)}',
                'Average score: ${percent(school.score)}',
                'Attendance: ${percent(school.attendance)}',
                'Students with missing work: ${school.missing}',
              ]),
              ReportSection('Classes', table: table),
            ],
          )
        : exporter.exportCsv(table: table, fileName: slug));
    if (url == null) return;
    final uri = Uri.parse(url);
    if (kIsWeb) {
      showToast('${pdf ? 'PDF' : 'CSV'} is ready', actionLabel: 'Open', onAction: () => launchUrl(uri));
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell(this.m, this.period, {this.count = false});

  final MetricSummary? m;
  final ReportPeriod period;
  final bool count;

  @override
  Widget build(BuildContext context) {
    final v = m?.value;
    final d = m?.delta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count ? '${v?.round() ?? '—'}' : percent(v), style: const TextStyle(fontWeight: FontWeight.w700)),
        if (d != null)
          Text(
            count ? '${d > 0 ? '+' : d < 0 ? '−' : '±'}${d.abs().round()}' : deltaLabel(d, '').trim(),
            style: TextStyle(fontSize: 11.5, color: deltaColor(d, lowerIsBetter: count)),
          ),
      ],
    );
  }
}

/// School-wide numbers = average of class numbers (missing work is summed).
class _SchoolSummary {
  _SchoolSummary({
    required this.completion,
    required this.completionDelta,
    required this.score,
    required this.scoreDelta,
    required this.attendance,
    required this.attendanceDelta,
    required this.missing,
    required this.missingDelta,
    required this.trend,
  });

  final double? completion, completionDelta, score, scoreDelta, attendance, attendanceDelta;
  final int missing;
  final double? missingDelta;
  final List<MonthlyStat> trend;

  static double? _avg(Iterable<double?> xs) {
    final v = xs.whereType<double>().toList();
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  static _SchoolSummary of(List<_Row> rows) {
    final s = [for (final r in rows) if (r.s != null) r.s!];
    final deltas = s.map((x) => x.missingWork.delta).whereType<double>();

    // Average the classes' monthly points into one school trend.
    final byMonth = <String, List<MonthlyStat>>{};
    for (final x in s) {
      for (final m in x.trend) {
        byMonth.putIfAbsent(monthKey(m.month), () => []).add(m);
      }
    }
    final months = byMonth.keys.toList()..sort();
    final trend = [
      for (final k in months)
        MonthlyStat(
          month: byMonth[k]!.first.month,
          completion: _avg(byMonth[k]!.map((m) => m.completion))!,
          averageScore: _avg(byMonth[k]!.map((m) => m.averageScore))!,
          attendance: _avg(byMonth[k]!.map((m) => m.attendance))!,
          missingWork: byMonth[k]!.fold<int>(0, (n, m) => n + m.missingWork),
        ),
    ];

    return _SchoolSummary(
      completion: _avg(s.map((x) => x.completion.value)),
      completionDelta: _avg(s.map((x) => x.completion.delta)),
      score: _avg(s.map((x) => x.averageScore.value)),
      scoreDelta: _avg(s.map((x) => x.averageScore.delta)),
      attendance: _avg(s.map((x) => x.attendance.value)),
      attendanceDelta: _avg(s.map((x) => x.attendance.delta)),
      missing: s.fold<int>(0, (n, x) => n + (x.missingWork.value?.round() ?? 0)),
      missingDelta: deltas.isEmpty ? null : deltas.reduce((a, b) => a + b),
      trend: trend,
    );
  }
}
