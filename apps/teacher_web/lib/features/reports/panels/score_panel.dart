import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/navigation.dart';
import '../../../providers/classes_providers.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/reports_providers.dart';
import '../report_actions.dart';
import 'panel_frame.dart';

class ScorePanel extends ConsumerWidget {
  const ScorePanel({super.key, required this.classRoom, required this.period});

  final ClassRoom classRoom;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    final range = period.range(DateTime.now());
    final metric = ref.watch(reportSummaryProvider((c.id, period))).valueOrNull?.averageScore;
    final items = ref.watch(classClassworkProvider(c.id)).valueOrNull ?? const [];
    final students = ref.watch(classStudentsProvider(c.id)).valueOrNull ?? const <Student>[];
    final dist = scoreDistribution(students);
    final ranked = dist.values.fold<int>(0, (a, n) => a + n);
    final averages = assessmentAverages(items, range);
    final difficult = difficultTopics(items, range);

    return ReportPanelFrame(
      title: 'Average Score Details',
      icon: Icons.star_rounded,
      tone: Tone.blue,
      value: percent(metric?.value ?? c.averageScore),
      deltaText: deltaLabel(metric?.delta, period.comparisonLabel),
      deltaColor: deltaColor(metric?.delta),
      primaryLabel: 'Open Gradebook',
      onPrimary: () {
        Navigator.pop(context);
        goTo(Routes.classDetail(c.id, ClassTab.gradebook));
      },
      onDownload: () => exportPanelPdf(ref, c, period, 'Average Score', [
        ReportSection('Score distribution',
            lines: [for (final e in dist.entries) '${e.key.label}: ${e.value} students']),
        ReportSection('Assessment averages',
            lines: [for (final a in averages) '${a.label}: ${percent(a.rate)}']),
        ReportSection('Difficult topics',
            lines: [for (final w in difficult) '${w.title}: ${percent(w.averageScore)}']),
      ]),
      children: [
        const PanelSectionTitle('Score Distribution'),
        Row(
          children: [
            for (final band in ScoreBand.values) ...[
              if (band != ScoreBand.values.first) const SizedBox(width: 8),
              Expanded(
                child: _BandBox(
                  band: band,
                  count: dist[band]!,
                  share: ranked == 0 ? 0 : dist[band]! / ranked,
                ),
              ),
            ],
          ],
        ),
        const PanelSectionTitle('Assessment Averages'),
        if (averages.isEmpty)
          const EmptyNote('No graded results in this period yet.')
        else
          PanelBox(children: [
            for (final a in averages) RateRow(label: a.label, rate: a.rate),
          ]),
        const PanelSectionTitle('Difficult Topics'),
        if (difficult.isEmpty)
          const EmptyNote('No topic is below 75%. Nice work!')
        else
          PanelBox(children: [
            for (final w in difficult)
              RateRow(label: w.title, rate: w.averageScore!, color: const Color(0xFFF2A91E)),
          ]),
      ],
    );
  }
}

class _BandBox extends StatelessWidget {
  const _BandBox({required this.band, required this.count, required this.share});

  final ScoreBand band;
  final int count;
  final double share;

  @override
  Widget build(BuildContext context) {
    final tone = band.tone;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.bg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(band.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tone.fg, fontWeight: FontWeight.w700, fontSize: 11.5)),
          const SizedBox(height: 6),
          ProgressBar(value: share, color: tone.fg, height: 6),
          const SizedBox(height: 6),
          Text(percent(share), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('$count ${count == 1 ? 'student' : 'students'}',
              style: AppText.meta.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
