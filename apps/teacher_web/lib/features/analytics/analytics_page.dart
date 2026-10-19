import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/analytics_providers.dart';
import '../reports/report_actions.dart' show runExport;
import '../shell/class_scope_selector.dart';
import '../shell/top_bar.dart';
import 'analytics_cards.dart';

/// `/analytics?classId=&range=` — learning progress and trends across classes.
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key, this.classId, this.range = AnalyticsRange.month});

  /// null = all active classes.
  final String? classId;
  final AnalyticsRange range;

  void _go(String? classId, AnalyticsRange r) =>
      goTo(Routes.analytics(classId: classId, range: r == AnalyticsRange.month ? null : r.name));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(analyticsProvider((classId, range)));
    return PageScaffold(
      header: PageHeader(
        icon: Icons.wb_sunny_rounded,
        title: 'Analytics',
        subtitle: 'Track learning progress and spot trends across your classes.',
        actions: ClassScopeSelector(classId: classId, onChanged: (id) => _go(id, range)),
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SegmentedPills<AnalyticsRange>(
              value: range,
              options: AnalyticsRange.values,
              labelOf: (r) => r.label,
              filled: true,
              onChanged: (r) => _go(classId, r),
            ),
            OutlinedButton.icon(
              onPressed: data.hasValue ? () => _export(ref, data.requireValue) : null,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export report'),
            ),
          ],
        ),
        AsyncValueView<AnalyticsData>(
          value: data,
          loadingHeight: 320,
          data: (d) {
            if (d.classes.isEmpty) {
              return const EmptyNote('No active classes yet — analytics appear once a class is assigned to you.',
                  icon: Icons.query_stats);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stats(data: d, range: range),
                const SizedBox(height: 20),
                TwoColumn(
                  leftFlex: 2,
                  rightFlex: 1,
                  left: [ScoreTrendCard(classId: classId, range: range)],
                  right: [TopicMasteryCard(classes: d.classes, initialClassId: classId, passingGrade: d.passingGrade)],
                ),
                const SizedBox(height: 20),
                ResponsiveGrid(
                  minItemWidth: 330,
                  maxColumns: 3,
                  spacing: 20,
                  children: [
                    TypeScoresCard(data: d),
                    GradeDistributionCard(data: d),
                    InsightsCard(classId: classId, range: range),
                  ],
                ),
                const SizedBox(height: 20),
                TwoColumn(
                  leftFlex: 2,
                  rightFlex: 1,
                  left: [LowestScoringCard(data: d)],
                  right: [SpotlightCard(data: d, classId: classId)],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _export(WidgetRef ref, AnalyticsData d) {
    final scope = classId == null ? 'All classes' : (d.classes.isEmpty ? 'Class' : d.classes.first.name);
    final now = DateTime.now();
    String pct(double? v) => percent(v);
    return runExport(
      ref,
      'analytics report',
      (x) => x.exportPdf(
        title: 'Analytics – $scope',
        subtitle: '${range.label} · ${d.students.length} students · generated ${fullDate(now)}',
        fileName: fileSlug('analytics $scope ${range.label}'),
        sections: [
          ReportSection('Summary', lines: [
            'Average score: ${pct(d.average)} (${deltaLabel(d.averageDelta, range.comparison)})',
            'Completion rate: ${pct(d.completion)} (${deltaLabel(d.completionDelta, range.comparison)})',
            'Opened EduLearn this week: ${d.activeThisWeek} of ${d.students.length} students',
            'Below the ${d.passingGrade}% passing grade: ${d.belowPassing.length} students',
          ]),
          ReportSection(
            'Score by classwork type',
            table: ReportTable(['Type', 'Average score', 'Completion', 'Items'], [
              for (final t in d.byType) [t.type.shortLabel, pct(t.average), pct(t.completion), '${t.items}'],
            ]),
          ),
          ReportSection(
            'Grade distribution',
            table: ReportTable(['Grade', 'Range', 'Students'], [
              for (final l in d.distribution) [l.level.letter, '${l.level.min}–${l.level.max}', '${l.count}'],
            ]),
          ),
          ReportSection(
            'Lowest-scoring classwork',
            table: ReportTable(['Classwork', 'Class', 'Due', 'Average', 'Turned in'], [
              for (final w in d.lowest)
                [w.title, w.className, dayMonth(w.dueDate), pct(w.averageScore), '${w.submittedCount}'],
            ]),
          ),
          ReportSection(
            'Students needing support',
            table: ReportTable(['Student', 'Reason'], [
              for (final f in d.support) [f.student.name, f.flag.label],
            ]),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data, required this.range});

  final AnalyticsData data;
  final AnalyticsRange range;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final below = d.belowPassing.length;
    return ResponsiveGrid(
      maxColumns: 4,
      children: [
        StatCard(
          icon: Icons.bar_chart_rounded,
          tone: Tone.green,
          label: 'Average score',
          value: AsyncData(percent(d.average)),
          caption: deltaLabel(d.averageDelta, range.comparison),
          captionColor: d.averageDelta == null ? null : deltaColor(d.averageDelta),
        ),
        StatCard(
          icon: Icons.task_alt_rounded,
          tone: Tone.blue,
          label: 'Completion rate',
          value: AsyncData(percent(d.completion)),
          caption: deltaLabel(d.completionDelta, range.comparison),
          captionColor: d.completionDelta == null ? null : deltaColor(d.completionDelta),
        ),
        StatCard(
          icon: Icons.groups_rounded,
          tone: Tone.amber,
          label: 'Active this week',
          value: AsyncData('${d.activeThisWeek}'),
          caption: 'of ${d.students.length} students opened EduLearn',
        ),
        StatCard(
          icon: Icons.warning_amber_rounded,
          tone: Tone.red,
          label: 'Below ${d.passingGrade}%',
          value: AsyncData('$below'),
          caption: below == 0 ? 'Everyone is passing' : '${below == 1 ? 'student' : 'students'} under the passing grade',
          captionColor: below == 0 ? AppColors.primary : AppColors.red,
          onTap: below == 0 ? null : () => goTo(Routes.students()),
        ),
      ],
    );
  }
}
