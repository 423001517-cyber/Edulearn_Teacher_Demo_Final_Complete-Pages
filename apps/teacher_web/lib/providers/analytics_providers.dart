import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'classwork_providers.dart';
import 'core_providers.dart';
import 'dashboard_providers.dart';
import 'data_providers.dart';
import 'settings_providers.dart';

/// Classwork due since the start of last quarter — enough for every range
/// and the period it is compared with.
final analyticsClassworkProvider = StreamProvider.autoDispose<List<ClassworkItem>>((ref) {
  final from = AnalyticsRange.quarter.previous(DateTime.now()).start;
  return ref.watch(reportsRepositoryProvider).watchClassworkDueFrom(from);
});

/// Everything the Analytics page shows for one class (or all active classes).
class AnalyticsData {
  const AnalyticsData({
    required this.classes,
    required this.students,
    required this.current,
    required this.average,
    required this.averageBefore,
    required this.completion,
    required this.completionBefore,
    required this.activeThisWeek,
    required this.belowPassing,
    required this.passingGrade,
    required this.byType,
    required this.distribution,
    required this.lowest,
    required this.improved,
    required this.support,
    required this.inactive,
  });

  final List<ClassRoom> classes;
  final List<Student> students;

  /// Graded classwork due in the selected range.
  final List<ClassworkItem> current;
  final double? average;
  final double? averageBefore;
  final double? completion;
  final double? completionBefore;
  final int activeThisWeek;
  final List<Student> belowPassing;
  final int passingGrade;
  final List<TypeScore> byType;
  final List<LetterCount> distribution;
  final List<ClassworkItem> lowest;
  final List<Improvement> improved;
  final List<FlaggedStudent> support;
  final List<Student> inactive;

  double? get averageDelta => average == null || averageBefore == null ? null : average! - averageBefore!;
  double? get completionDelta =>
      completion == null || completionBefore == null ? null : completion! - completionBefore!;
}

final analyticsProvider =
    Provider.autoDispose.family<AsyncValue<AnalyticsData>, (String?, AnalyticsRange)>((ref, key) {
  final (classId, range) = key;
  final classesValue = ref.watch(activeClassesProvider);
  final studentsValue = ref.watch(studentsProvider);
  final workValue = ref.watch(analyticsClassworkProvider);
  for (final v in <AsyncValue<Object>>[classesValue, studentsValue, workValue]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!classesValue.hasValue || !studentsValue.hasValue || !workValue.hasValue) return const AsyncLoading();

  final prefs = ref.watch(preferencesProvider);
  final now = DateTime.now();
  final classes = classesValue.requireValue.where((c) => classId == null || c.id == classId).toList();
  final ids = {for (final c in classes) c.id};
  final students = studentsValue.requireValue.where((s) => ids.contains(s.classId)).toList();
  final sizes = <String, int>{};
  for (final s in students) {
    sizes[s.classId] = (sizes[s.classId] ?? 0) + 1;
  }
  final work = workValue.requireValue.where((w) => ids.contains(w.classId)).toList();
  final current = gradedInRange(work, range.range(now));
  final before = gradedInRange(work, range.previous(now));
  final weekAgo = now.subtract(const Duration(days: 7));
  final passing = prefs.passingGrade / 100;

  return AsyncData(AnalyticsData(
    classes: classes,
    students: students,
    current: current,
    average: weightedAverage(current),
    averageBefore: weightedAverage(before),
    completion: averageCompletion(current, sizes, now),
    completionBefore: averageCompletion(before, sizes, now),
    activeThisWeek: students.where((s) => s.lastActiveAt != null && s.lastActiveAt!.isAfter(weekAgo)).length,
    belowPassing: students.where((s) => s.averageScore != null && s.averageScore! < passing).toList(),
    passingGrade: prefs.passingGrade,
    byType: scoreByType(current, sizes, now),
    distribution: letterDistribution(students, prefs.gradebookDefaults),
    lowest: lowestScoring(current),
    improved: mostImproved(students),
    support: flagStudents(students, now),
    inactive: inactiveStudents(students, now),
  ));
});

/// Newest topics of one class with their average score.
final topicMasteryProvider = Provider.autoDispose.family<AsyncValue<List<TopicMastery>>, String>((ref, classId) {
  final topics = ref.watch(classTopicsProvider(classId));
  final work = ref.watch(analyticsClassworkProvider);
  if (topics.hasError) return AsyncError(topics.error!, topics.stackTrace ?? StackTrace.current);
  if (work.hasError) return AsyncError(work.error!, work.stackTrace ?? StackTrace.current);
  if (!topics.hasValue || !work.hasValue) return const AsyncLoading();
  final now = DateTime.now();
  final items = work.requireValue.where((w) =>
      w.classId == classId && w.type.isGraded && w.status != ClassworkStatus.draft && w.dueDate.isBefore(now));
  return AsyncData(topicMastery(items, topics.requireValue));
});

enum InsightKind { hardTopic, bigGain, lowCompletion, inactive }

class Insight {
  const Insight({required this.kind, required this.title, required this.detail, this.studentId, this.classId});

  final InsightKind kind;
  final String title;
  final String detail;

  /// The class the finding is about (for its action link).
  final String? classId;

  /// For "Send a reminder": the first inactive student.
  final String? studentId;
}

/// Plain-language findings for the Insights card.
final analyticsInsightsProvider =
    Provider.autoDispose.family<List<Insight>, (String?, AnalyticsRange)>((ref, key) {
  final (classId, range) = key;
  final data = ref.watch(analyticsProvider(key)).valueOrNull;
  if (data == null) return const [];
  final out = <Insight>[];

  // Hardest topic across the classes in view.
  TopicMastery? hardest;
  ClassRoom? hardestClass;
  for (final c in data.classes) {
    for (final t in ref.watch(topicMasteryProvider(c.id)).valueOrNull ?? const <TopicMastery>[]) {
      if (hardest == null || t.average < hardest.average) {
        hardest = t;
        hardestClass = c;
      }
    }
  }
  if (hardest != null && hardestClass != null && hardest.average < data.passingGrade / 100) {
    out.add(Insight(
      kind: InsightKind.hardTopic,
      title: '${hardest.name} is the hardest topic',
      detail: 'Average ${_pct(hardest.average)} in ${hardestClass.name}, below the ${data.passingGrade}% passing grade',
      classId: hardestClass.id,
    ));
  }

  // Biggest improvement on the score trend.
  final chart =
      ref.watch(performanceChartProvider(PerformanceQuery(classId: classId, range: range.chartRange))).valueOrNull;
  if (chart != null) {
    PerformanceSeries? best;
    double? bestGain;
    for (final s in chart.series) {
      final g = seriesGain(s.values);
      if (g != null && (bestGain == null || g > bestGain)) {
        best = s;
        bestGain = g;
      }
    }
    if (best != null && bestGain != null && bestGain >= 0.01) {
      out.add(Insight(
        kind: InsightKind.bigGain,
        title: '${best.name} is up ${(bestGain * 100).round()} points',
        detail: chart.series.length > 1
            ? 'The biggest gain across your classes ${range.label.toLowerCase()}'
            : 'Average score is rising ${range.label.toLowerCase()}',
      ));
    }
  }

  // Classwork type with the lowest completion.
  TypeScore? low;
  for (final t in data.byType) {
    final c = t.completion;
    if (c == null) continue;
    if (low == null || c < low.completion!) low = t;
  }
  if (low != null && low.completion! < 0.9) {
    out.add(Insight(
      kind: InsightKind.lowCompletion,
      title: '${low.type.shortLabel} has the lowest completion',
      detail: '${_pct(low.completion)} of students turned it in ${range.label.toLowerCase()}',
      classId: classId,
    ));
  }

  // Students who stopped opening the app.
  if (data.inactive.isNotEmpty) {
    final n = data.inactive.length;
    final byClass = <String, int>{};
    for (final s in data.inactive) {
      byClass[s.classId] = (byClass[s.classId] ?? 0) + 1;
    }
    final names = {for (final c in data.classes) c.id: c.name};
    out.add(Insight(
      kind: InsightKind.inactive,
      title: '$n ${n == 1 ? 'student hasn’t' : 'students haven’t'} opened EduLearn in 7 days',
      detail: [for (final e in byClass.entries) '${e.value} in ${names[e.key] ?? 'a class'}'].join(', '),
      studentId: data.inactive.first.id,
      classId: data.inactive.first.classId,
    ));
  }
  return out;
});

String _pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';
