import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/reports_providers.dart';
import '../report_actions.dart';

/// Completion / Average Score / Attendance / Missing Work with the change
/// from the previous period. Tapping a card opens its detail panel.
class ReportStatsGrid extends ConsumerWidget {
  const ReportStatsGrid({
    super.key,
    required this.classId,
    required this.period,
    this.onOpen,
    this.selected,
  });

  final String classId;
  final ReportPeriod period;
  final ValueChanged<ReportPanel>? onOpen;
  final ReportPanel? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportSummaryProvider((classId, period)));
    final s = summary.valueOrNull;
    final cmp = period.comparisonLabel;

    StatCard card(ReportPanel p, IconData icon, Tone tone, MetricSummary? m,
        {bool count = false, bool lowerIsBetter = false}) {
      return StatCard(
        icon: icon,
        tone: tone,
        label: p.label,
        value: summary.whenData(
            (_) => count ? '${m?.value?.round() ?? '—'}' : percent(m?.value)),
        caption: m == null ? '' : deltaLabel(m.delta, cmp, asPercent: !count),
        captionColor: deltaColor(m?.delta, lowerIsBetter: lowerIsBetter),
        selected: selected == p,
        onTap: onOpen == null ? null : () => onOpen!(p),
      );
    }

    return ResponsiveGrid(
      children: [
        card(ReportPanel.completion, Icons.bar_chart_rounded, Tone.green, s?.completion),
        card(ReportPanel.score, Icons.star_rounded, Tone.blue, s?.averageScore),
        card(ReportPanel.attendance, Icons.groups_rounded, Tone.purple, s?.attendance),
        card(ReportPanel.missing, Icons.priority_high_rounded, Tone.red, s?.missingWork,
            count: true, lowerIsBetter: true),
      ],
    );
  }
}

class ReportTrendCard extends ConsumerWidget {
  const ReportTrendCard({super.key, required this.classId, required this.period});

  final String classId;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Class Performance Trend',
      showDivider: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AsyncValueView<ReportSummary>(
          value: ref.watch(reportSummaryProvider((classId, period))),
          loadingHeight: 260,
          data: (s) {
            if (s.trend.isEmpty) {
              return const EmptyNote(
                'Monthly results appear here after the first nightly update.',
                icon: Icons.insights_outlined,
              );
            }
            return TrendLineChart(
              legendOnTop: true,
              height: 250,
              labels: [for (final m in s.trend) monthAbbr(m.month)],
              lines: [
                ChartLine(
                  name: 'Completion',
                  color: AppColors.chartGreen,
                  values: [for (final m in s.trend) m.completion],
                ),
                ChartLine(
                  name: 'Average Score',
                  color: AppColors.blue,
                  values: [for (final m in s.trend) m.averageScore],
                  fill: false,
                ),
                ChartLine(
                  name: 'Attendance',
                  color: AppColors.purple,
                  values: [for (final m in s.trend) m.attendance],
                  fill: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Student Progress / Assessment Results / Attendance Summary / Quest
/// Completion.
class ReportOptionsCard extends StatelessWidget {
  const ReportOptionsCard({super.key, required this.onStudentProgress, required this.onPanel});

  final VoidCallback onStudentProgress;
  final ValueChanged<ReportPanel> onPanel;

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, Tone tone, String title, String subtitle, VoidCallback onTap) =>
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tone.fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.itemTitle),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
              ],
            ),
          ),
        );

    return SectionCard(
      title: 'Report Options',
      showDivider: false,
      child: Column(
        children: [
          option(Icons.bar_chart_rounded, Tone.blue, 'Student Progress',
              'View individual student progress and growth', onStudentProgress),
          option(Icons.description_rounded, Tone.blue, 'Assessment Results',
              'Analyze quiz and assignment results', () => onPanel(ReportPanel.score)),
          option(Icons.groups_rounded, Tone.purple, 'Attendance Summary',
              'View attendance trends and details', () => onPanel(ReportPanel.attendance)),
          option(Icons.emoji_events_rounded, Tone.amber, 'Quest Completion',
              'Track quest completion across topics', () => onPanel(ReportPanel.completion)),
        ],
      ),
    );
  }
}
