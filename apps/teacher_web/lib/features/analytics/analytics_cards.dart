import 'dart:math' as math;

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/analytics_providers.dart';
import '../../providers/data_providers.dart';
import '../students/student_support_panel.dart';

/// Small grey line under a card title.
class CardNote extends StatelessWidget {
  const CardNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: AppText.meta));
}

/// Weekly average score per class (from the nightly rollup).
class ScoreTrendCard extends ConsumerWidget {
  const ScoreTrendCard({super.key, required this.classId, required this.range});

  final String? classId;
  final AnalyticsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(performanceChartProvider(PerformanceQuery(classId: classId, range: range.chartRange)));
    return SectionCard(
      title: 'Average score trend',
      icon: Icons.show_chart_rounded,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardNote('Average of returned work, ${range.label.toLowerCase()}'),
            AsyncValueView<PerformanceChartData>(
              value: chart,
              loadingHeight: 260,
              data: (c) {
                if (!c.hasData) {
                  return const EmptyNote('No graded work was returned in this period yet.',
                      icon: Icons.show_chart_rounded);
                }
                return TrendLineChart(
                  labels: c.labels,
                  height: 260,
                  legendOnTop: true,
                  lines: [
                    for (final s in c.series)
                      ChartLine(
                        name: s.name,
                        color: AppColors.forClass(s.colorIndex),
                        values: s.values,
                        fill: c.series.length == 1,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Average score for each of a class's newest topics.
class TopicMasteryCard extends ConsumerStatefulWidget {
  const TopicMasteryCard({super.key, required this.classes, required this.initialClassId, required this.passingGrade});

  final List<ClassRoom> classes;
  final String? initialClassId;
  final int passingGrade;

  @override
  ConsumerState<TopicMasteryCard> createState() => _TopicMasteryCardState();
}

class _TopicMasteryCardState extends ConsumerState<TopicMasteryCard> {
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final classes = widget.classes;
    ClassRoom? cls;
    for (final c in classes) {
      if (c.id == (_classId ?? widget.initialClassId)) cls = c;
    }
    cls ??= classes.isEmpty ? null : classes.first;
    if (cls == null) return const SizedBox.shrink();
    final current = cls;
    final topics = ref.watch(topicMasteryProvider(current.id));
    final passing = widget.passingGrade / 100;

    return SectionCard(
      title: 'Mastery by topic',
      icon: Icons.school_outlined,
      trailing: classes.length > 1 && widget.initialClassId == null
          ? FilterDropdown<ClassRoom>(
              value: current,
              options: classes,
              labelOf: (c) => c.name,
              onChanged: (c) => setState(() => _classId = c.id),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardNote('Average score per topic in ${current.name}, newest first'),
            AsyncValueView<List<TopicMastery>>(
              value: topics,
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyNote('Topic scores appear once graded classwork is filed under a topic.');
                }
                return Column(
                  children: [
                    for (final t in list) ...[
                      _TopicRow(topic: t, low: t.average < passing),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Passing grade: ${widget.passingGrade}% (Settings › Grading)',
                      style: AppText.meta.copyWith(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.low});

  final TopicMastery topic;
  final bool low;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(topic.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            if (low) ...[
              const Pill('Needs review', tone: Tone.amber, icon: Icons.warning_amber_rounded),
              const SizedBox(width: 8),
            ],
            Text(percent(topic.average), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(value: topic.average, color: low ? AppColors.amber : AppColors.chartGreen, height: 10),
      ],
    );
  }
}

/// Average score by classwork type, as columns.
class TypeScoresCard extends StatelessWidget {
  const TypeScoresCard({super.key, required this.data});

  final AnalyticsData data;

  static String _plural(ClassworkType t) => switch (t) {
        ClassworkType.quest => 'Quests',
        ClassworkType.activity => 'Activities',
        ClassworkType.quiz => 'Quizzes',
        ClassworkType.boss => 'Friday Boss',
        _ => t.label,
      };

  @override
  Widget build(BuildContext context) {
    const barArea = 170.0;
    return SectionCard(
      title: 'Score by classwork type',
      icon: Icons.bar_chart_rounded,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CardNote('Average score of returned work in this period'),
            SizedBox(
              height: barArea + 26,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final t in data.byType)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(percent(t.average),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          Tooltip(
                            message: '${_plural(t.type)}: ${percent(t.average)} average, '
                                '${t.items} ${t.items == 1 ? 'item' : 'items'}',
                            child: Container(
                              width: 40,
                              height: math.max(4.0, barArea * (t.average ?? 0)),
                              decoration: BoxDecoration(
                                color: t.average == null ? AppColors.track : AppColors.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final t in data.byType)
                  Expanded(
                    child: Column(
                      children: [
                        Icon(t.type.icon, size: 18, color: t.type.tone.fg),
                        const SizedBox(height: 2),
                        Text(_plural(t.type),
                            textAlign: TextAlign.center,
                            style: AppText.meta.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Students per letter grade.
class GradeDistributionCard extends StatelessWidget {
  const GradeDistributionCard({super.key, required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final rows = data.distribution;
    final most = rows.fold<int>(0, (m, r) => math.max(m, r.count));
    final graded = data.students.where((s) => s.averageScore != null).length;
    final passing = graded - data.belowPassing.length;
    return SectionCard(
      title: 'Grade distribution',
      icon: Icons.leaderboard_outlined,
      actionLabel: data.classes.length == 1 ? 'Gradebook' : null,
      onAction: data.classes.length == 1 ? () => goTo(Routes.gradebook(classId: data.classes.first.id)) : null,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardNote('$graded students, by overall average'),
            for (final r in rows) ...[
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(r.level.color).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(r.level.letter,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink)),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 62,
                    child: Text(r.level.min == 0 ? 'Below ${r.level.max + 1}' : '${r.level.min}–${r.level.max}',
                        style: AppText.meta.copyWith(fontSize: 12)),
                  ),
                  Expanded(
                    child: ProgressBar(
                      value: most == 0 ? 0 : r.count / most,
                      color: Color(r.level.color),
                      height: 12,
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('${r.count}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Text(
              graded == 0
                  ? 'No grades yet.'
                  : '$passing of $graded students (${percent(passing / graded)}) are at or above the '
                      '${data.passingGrade}% passing grade.',
              style: AppText.meta.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain-language findings with a next step.
class InsightsCard extends ConsumerWidget {
  const InsightsCard({super.key, required this.classId, required this.range});

  final String? classId;
  final AnalyticsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(analyticsInsightsProvider((classId, range)));
    return SectionCard(
      title: 'Insights',
      icon: Icons.lightbulb_outline_rounded,
      child: insights.isEmpty
          ? const EmptyNote('Nothing stands out right now. Insights appear as work is graded.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < insights.length; i++) ...[
                  if (i > 0) const Divider(),
                  _InsightRow(insight: insights[i]),
                ],
              ],
            ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final i = insight;
    final (icon, tone) = switch (i.kind) {
      InsightKind.hardTopic => (Icons.warning_amber_rounded, Tone.red),
      InsightKind.bigGain => (Icons.trending_up_rounded, Tone.green),
      InsightKind.lowCompletion => (Icons.schedule_rounded, Tone.amber),
      InsightKind.inactive => (Icons.groups_outlined, Tone.blue),
    };
    final (String? label, String? target) = switch (i.kind) {
      InsightKind.hardTopic => ('Assign a review quest', Routes.classworkNew(ClassworkType.quest, classId: i.classId)),
      InsightKind.lowCompletion => ('Open Submissions', Routes.submissions(classId: i.classId)),
      InsightKind.inactive => ('Send a message', Routes.messages(studentId: i.studentId)),
      InsightKind.bigGain => (null, null),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToneIcon(icon, tone: tone, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(i.detail, style: AppText.meta.copyWith(fontSize: 12.5)),
                if (label != null && target != null) ...[
                  const SizedBox(height: 2),
                  LinkButton(label: label, onTap: () => goTo(target)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The classwork students found hardest in this period.
class LowestScoringCard extends StatelessWidget {
  const LowestScoringCard({super.key, required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final sizes = <String, int>{};
    for (final s in data.students) {
      sizes[s.classId] = (sizes[s.classId] ?? 0) + 1;
    }
    final passing = data.passingGrade / 100;
    return SectionCard(
      title: 'Lowest-scoring classwork',
      icon: Icons.trending_down_rounded,
      actionLabel: 'Submissions',
      onAction: () => goTo(Routes.submissions(classId: data.classes.length == 1 ? data.classes.first.id : null)),
      child: data.lowest.isEmpty
          ? const EmptyNote('No graded classwork in this period yet.')
          : LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 620;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  if (wide)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text('Classwork', style: AppText.label.copyWith(fontSize: 12.5))),
                          Expanded(flex: 3, child: Text('Average', style: AppText.label.copyWith(fontSize: 12.5))),
                          Expanded(flex: 2, child: Text('Turned in', style: AppText.label.copyWith(fontSize: 12.5))),
                          const SizedBox(width: 90),
                        ],
                      ),
                    ),
                  for (final w in data.lowest) ...[
                    const Divider(),
                    _LowRow(item: w, size: sizes[w.classId] ?? 0, low: (w.averageScore ?? 1) < passing, wide: wide),
                  ],
                ],
              );
            }),
    );
  }
}

class _LowRow extends StatelessWidget {
  const _LowRow({required this.item, required this.size, required this.low, required this.wide});

  final ClassworkItem item;
  final int size;
  final bool low;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final w = item;
    final title = Row(
      children: [
        ToneIcon(w.type.icon, tone: w.type.tone, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              Text('${w.className} · due ${dayMonth(w.dueDate)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
    final score = Row(
      children: [
        Expanded(
          child: ProgressBar(value: w.averageScore ?? 0, color: low ? AppColors.amber : AppColors.chartGreen, height: 8),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(percent(w.averageScore), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
    final turnedIn = Text(size == 0 ? '${w.submittedCount}' : '${w.submittedCount} of $size', style: AppText.body);
    final review = LinkButton(label: 'Review', onTap: () => goTo(Routes.submissions(classId: w.classId, item: w.id)));

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 8),
            score,
            const SizedBox(height: 4),
            Row(children: [Expanded(child: turnedIn), review]),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 5, child: Padding(padding: const EdgeInsets.only(right: 16), child: title)),
          Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 16), child: score)),
          Expanded(flex: 2, child: turnedIn),
          SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: review)),
        ],
      ),
    );
  }
}

enum _Spotlight {
  improved('Most improved'),
  support('Needs support');

  const _Spotlight(this.label);
  final String label;
}

/// Most improved students, or the ones who need help.
class SpotlightCard extends StatefulWidget {
  const SpotlightCard({super.key, required this.data, required this.classId});

  final AnalyticsData data;
  final String? classId;

  @override
  State<SpotlightCard> createState() => _SpotlightCardState();
}

class _SpotlightCardState extends State<SpotlightCard> {
  _Spotlight _tab = _Spotlight.improved;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final names = {for (final c in d.classes) c.id: c.name};
    final rows = <Widget>[
      if (_tab == _Spotlight.improved)
        for (final i in d.improved)
          _PersonRow(
            student: i.student,
            subtitle: '${names[i.student.classId] ?? ''} · ${percent(i.student.averageScore)} → '
                '${percent(i.student.recentScore)}',
            trailing: Text('▲ ${(i.gain * 100).round()} pts',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          )
      else
        for (final f in d.support.take(5))
          _PersonRow(
            student: f.student,
            subtitle: names[f.student.classId] ?? '',
            trailing: Pill(f.flag.label, tone: f.flag.level.tone),
          ),
    ];
    return SectionCard(
      title: 'Student spotlight',
      icon: Icons.star_outline_rounded,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedPills<_Spotlight>(
              value: _tab,
              options: _Spotlight.values,
              labelOf: (t) => t.label,
              expand: true,
              height: 36,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              EmptyNote(_tab == _Spotlight.improved
                  ? 'No one has moved up yet — check back after more work is graded.'
                  : 'No students need support right now.')
            else
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), rows[i]],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: LinkButton(label: 'View all students', onTap: () => goTo(Routes.students(classId: widget.classId))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.student, required this.subtitle, required this.trailing});

  final Student student;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showStudentPanel(context, student),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            InitialsAvatar(
              initials: student.initials,
              tone: toneForName(student.name),
              size: 38,
              imageUrl: student.photoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
