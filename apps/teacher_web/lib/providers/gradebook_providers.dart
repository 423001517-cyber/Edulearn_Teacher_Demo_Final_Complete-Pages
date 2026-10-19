import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'classes_providers.dart';
import 'classwork_providers.dart';
import 'core_providers.dart';
import 'data_providers.dart';
import 'settings_providers.dart';

final gradebookSettingsProvider = StreamProvider.autoDispose.family<GradebookSettings, String>(
  (ref, classId) => ref
      .watch(gradebookRepositoryProvider)
      .watchSettings(classId, fallback: ref.watch(preferencesProvider).gradebookDefaults),
);

final classSubmissionsProvider = StreamProvider.autoDispose.family<List<Submission>, String>(
  (ref, classId) => ref.watch(gradebookRepositoryProvider).watchClassSubmissions(classId),
);

/// Everything the Gradebook page shows.
class GradebookData {
  const GradebookData({
    required this.columns,
    required this.students,
    required this.cells,
    required this.overall,
    required this.columnAverage,
    required this.classAverage,
    required this.highest,
    required this.missing,
    required this.needsGrading,
    required this.distribution,
  });

  /// Graded classwork shown as columns, by due date.
  final List<ClassworkItem> columns;
  final List<Student> students;

  /// studentId → classworkId → submission.
  final Map<String, Map<String, Submission>> cells;

  /// studentId → overall percentage (null = none yet).
  final Map<String, double?> overall;

  /// classworkId → average score (points), null when nothing is graded.
  final Map<String, double?> columnAverage;
  final double? classAverage;
  final double? highest;

  /// Empty cells that are past due.
  final int missing;

  /// Turned in but not scored.
  final int needsGrading;

  /// Letter → number of students.
  final Map<String, int> distribution;
}

/// Pure: builds the grid for one class.
GradebookData buildGradebook({
  required List<ClassworkItem> work,
  required List<Student> roster,
  required List<Submission> submissions,
  required GradebookSettings settings,
  required DateTime now,
  int? quarter,
  String? topicId,
}) {
  final columns = work
      .where((w) =>
          w.type.isGraded &&
          (w.status == ClassworkStatus.published || w.status == ClassworkStatus.closed) &&
          !settings.removedColumns.contains(w.id) &&
          (quarter == null || w.quarter == quarter) &&
          (topicId == null || w.topicId == topicId))
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final ids = {for (final w in columns) w.id};
  final cells = <String, Map<String, Submission>>{};
  for (final s in submissions) {
    if (ids.contains(s.classworkId)) (cells[s.studentId] ??= {})[s.classworkId] = s;
  }
  bool assigned(ClassworkItem w, Student st) => w.assignedStudentIds.isEmpty || w.assignedStudentIds.contains(st.id);

  final overall = <String, double?>{};
  var missing = 0;
  var needsGrading = 0;
  for (final st in roster) {
    final mine = cells[st.id] ?? const <String, Submission>{};
    final cols = [for (final w in columns) if (assigned(w, st)) w];
    overall[st.id] = overallGrade(settings, cols, mine, now);
    for (final w in cols) {
      final s = mine[w.id];
      if (s == null && w.dueDate.isBefore(now)) missing++;
      if (s != null && s.score == null) needsGrading++;
    }
  }
  final counted = [
    for (final st in roster)
      if (!settings.excludedStudents.contains(st.id) && overall[st.id] != null) overall[st.id]!,
  ];
  final columnAverage = <String, double?>{
    for (final w in columns)
      w.id: () {
        final scores = [
          for (final st in roster)
            if (cells[st.id]?[w.id]?.score != null) cells[st.id]![w.id]!.score!.toDouble(),
        ];
        return scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;
      }(),
  };
  final distribution = {for (final g in settings.scale) g.letter: 0};
  for (final p in counted) {
    final g = settings.letterFor(p);
    if (g != null) distribution[g.letter] = (distribution[g.letter] ?? 0) + 1;
  }
  return GradebookData(
    columns: columns,
    students: roster,
    cells: cells,
    overall: overall,
    columnAverage: columnAverage,
    classAverage: counted.isEmpty ? null : counted.reduce((a, b) => a + b) / counted.length,
    highest: counted.isEmpty ? null : counted.reduce((a, b) => a > b ? a : b),
    missing: missing,
    needsGrading: needsGrading,
    distribution: distribution,
  );
}

/// The grid for one class, quarter and topic.
final gradebookProvider =
    Provider.autoDispose.family<AsyncValue<GradebookData>, (String classId, int? quarter, String? topicId)>((ref, a) {
  final work = ref.watch(classClassworkProvider(a.$1));
  final roster = ref.watch(classStudentsProvider(a.$1));
  final subs = ref.watch(classSubmissionsProvider(a.$1));
  final settings = ref.watch(gradebookSettingsProvider(a.$1));
  for (final v in <AsyncValue<Object>>[work, roster, subs, settings]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!work.hasValue || !roster.hasValue || !subs.hasValue || !settings.hasValue) return const AsyncLoading();
  return AsyncData(buildGradebook(
    work: work.requireValue,
    roster: roster.requireValue,
    submissions: subs.requireValue,
    settings: settings.requireValue,
    now: DateTime.now(),
    quarter: a.$2,
    topicId: a.$3,
  ));
});

/// Topics for the "All topics" filter.
final gradebookTopicsProvider = Provider.autoDispose.family<List<ClassTopic>, String>(
  (ref, classId) => ref.watch(classTopicsProvider(classId)).valueOrNull ?? const [],
);
