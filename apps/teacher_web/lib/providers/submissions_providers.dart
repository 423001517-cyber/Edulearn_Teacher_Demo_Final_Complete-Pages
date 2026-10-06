import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'classes_providers.dart';
import 'core_providers.dart';
import 'data_providers.dart';

/// One student on one classwork item.
class SubmissionRow {
  const SubmissionRow(this.student, this.submission, this.state);

  final Student student;
  final Submission? submission;
  final WorkState state;
}

enum RowTab {
  all('All'),
  turnedIn('Turned in'),
  missing('Missing'),
  graded('Graded');

  const RowTab(this.label);
  final String label;

  bool shows(WorkState s) => switch (this) {
        RowTab.all => true,
        RowTab.turnedIn => s.handedIn,
        RowTab.missing => s == WorkState.missing,
        RowTab.graded => s == WorkState.graded,
      };
}

enum RowSort {
  newest('Newest first'),
  oldest('Oldest first'),
  name('Name A–Z'),
  score('Highest score');

  const RowSort(this.label);
  final String label;
}

/// Pure: everyone the item is assigned to, with their submission and state.
List<SubmissionRow> buildRows(ClassworkItem item, List<Student> roster, List<Submission> subs, DateTime now) {
  final byStudent = {for (final s in subs) s.studentId: s};
  final assigned = item.assignedStudentIds.isEmpty
      ? roster
      : roster.where((st) => item.assignedStudentIds.contains(st.id)).toList();
  return [
    for (final st in assigned)
      SubmissionRow(st, byStudent[st.id], workStateFor(item, byStudent[st.id], now)),
  ];
}

/// Pure: tab + search + sort.
List<SubmissionRow> filterRows(List<SubmissionRow> rows, RowTab tab, String query, RowSort sort) {
  final q = query.trim().toLowerCase();
  final out = rows.where((r) => tab.shows(r.state) && (q.isEmpty || r.student.name.toLowerCase().contains(q))).toList();
  DateTime at(SubmissionRow r) => r.submission?.submittedAt ?? DateTime(1970);
  out.sort(switch (sort) {
    RowSort.newest => (a, b) => at(b).compareTo(at(a)),
    RowSort.oldest => (a, b) {
        if (a.submission == null) return 1;
        if (b.submission == null) return -1;
        return at(a).compareTo(at(b));
      },
    RowSort.name => (a, b) => a.student.name.compareTo(b.student.name),
    RowSort.score => (a, b) => (b.submission?.score ?? -1).compareTo(a.submission?.score ?? -1),
  });
  return out;
}

final itemSubmissionsProvider = StreamProvider.autoDispose.family<List<Submission>, String>(
  (ref, itemId) => ref.watch(submissionsRepositoryProvider).watchForItem(itemId),
);

/// Rows for one item of one class (roster × submissions).
final itemRowsProvider =
    Provider.autoDispose.family<AsyncValue<List<SubmissionRow>>, (String classId, ClassworkItem item)>((ref, args) {
  final roster = ref.watch(classStudentsProvider(args.$1));
  final subs = ref.watch(itemSubmissionsProvider(args.$2.id));
  if (roster.hasError) return AsyncError(roster.error!, roster.stackTrace ?? StackTrace.current);
  if (subs.hasError) return AsyncError(subs.error!, subs.stackTrace ?? StackTrace.current);
  if (!roster.hasValue || !subs.hasValue) return const AsyncLoading();
  return AsyncData(buildRows(args.$2, roster.requireValue, subs.requireValue, DateTime.now()));
});

/// Graded, live classwork of a class — the Submissions "Classwork queue".
final gradableWorkProvider = Provider.autoDispose.family<AsyncValue<List<ClassworkItem>>, String>(
  (ref, classId) => ref.watch(classClassworkProvider(classId)).whenData((l) => l
      .where((w) =>
          w.type.isGraded && (w.status == ClassworkStatus.published || w.status == ClassworkStatus.closed))
      .toList()
    ..sort((a, b) => b.dueDate.compareTo(a.dueDate))),
);

/// Pending ("to review") submissions per classwork id in one class.
final toReviewByItemProvider = Provider.autoDispose.family<Map<String, int>, String>((ref, classId) {
  final out = <String, int>{};
  for (final s in ref.watch(pendingSubmissionsProvider).valueOrNull ?? const <Submission>[]) {
    if (s.classId == classId) out[s.classworkId] = (out[s.classworkId] ?? 0) + 1;
  }
  return out;
});
