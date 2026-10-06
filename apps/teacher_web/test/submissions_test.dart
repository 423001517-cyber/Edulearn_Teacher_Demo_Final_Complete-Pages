import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_web/app/routes.dart';
import 'package:teacher_web/providers/submissions_providers.dart';

/// Submissions page logic (no Firebase needed).
void main() {
  final due = DateTime(2026, 9, 20, 23, 59);
  final item = ClassworkItem(
    id: 'quest', classId: 'rizal-4a', className: 'Grade 4 – Rizal', type: ClassworkType.quest,
    title: 'Monday Quest', dueDate: due, points: 10,
  );
  Student st(String id, String name) => Student(id: id, name: name, classId: 'rizal-4a', gradeLevel: 4, studentNumber: id);
  Submission sub(String studentId, {DateTime? at, int? score, SubmissionStatus status = SubmissionStatus.pending}) =>
      Submission(
        id: 's-$studentId', classId: 'rizal-4a', studentId: studentId, studentName: studentId, gradeLevel: 4,
        classworkId: 'quest', classworkTitle: 'Monday Quest', classworkType: ClassworkType.quest,
        submittedAt: at ?? DateTime(2026, 9, 18, 9, 14), status: status, score: score, maxScore: 10,
      );
  final after = DateTime(2026, 9, 26);

  test('work states', () {
    expect(workStateFor(item, null, DateTime(2026, 9, 19)), WorkState.assigned);
    expect(workStateFor(item, null, after), WorkState.missing);
    expect(workStateFor(item, sub('a'), after), WorkState.turnedIn);
    expect(workStateFor(item, sub('a', at: DateTime(2026, 9, 21, 13)), after), WorkState.late);
    expect(workStateFor(item, sub('a', score: 8), after), WorkState.draft);
    expect(workStateFor(item, sub('a', score: 10, status: SubmissionStatus.returned), after), WorkState.graded);
    expect(WorkState.draft.needsReview && WorkState.late.handedIn && !WorkState.graded.needsReview, isTrue);
  });

  test('rows join the roster; tabs and sorting', () {
    final roster = [st('ana', 'Ana Cruz'), st('dan', 'Daniel Perez'), st('mar', 'Maria Lopez'), st('ella', 'Ella Reyes')];
    final subs = [
      sub('ana', at: DateTime(2026, 9, 18, 9, 14), score: 10, status: SubmissionStatus.returned),
      sub('dan', at: DateTime(2026, 9, 18, 10, 2)),
      sub('ella', at: DateTime(2026, 9, 17, 15, 21)),
    ];
    final rows = buildRows(item, roster, subs, after);
    expect(rows.length, 4);
    List<String> names(RowTab t, [RowSort s = RowSort.name]) =>
        [for (final r in filterRows(rows, t, '', s)) r.student.id];
    expect(names(RowTab.missing), ['mar']);
    expect(names(RowTab.graded), ['ana']);
    expect(names(RowTab.turnedIn), ['ana', 'dan', 'ella']);
    expect(names(RowTab.all, RowSort.newest), ['dan', 'ana', 'ella', 'mar']);
    expect([for (final r in filterRows(rows, RowTab.all, 'maria', RowSort.name)) r.student.id], ['mar']);

    // Remedial work only lists its assigned students.
    final remedial = ClassworkItem(
      id: 'r', classId: 'rizal-4a', className: 'C', type: ClassworkType.quest, title: 'Remedial',
      dueDate: due, assignedStudentIds: const ['mar'],
    );
    expect(buildRows(remedial, roster, const [], after).single.student.id, 'mar');
  });

  test('submission URLs', () {
    expect(Routes.submissions(classId: 'rizal-4a', item: 'quest'), '/submissions?classId=rizal-4a&item=quest');
    expect(Routes.reviewSubmission('quest', 'ana'), '/submissions/review?item=quest&student=ana');
    expect(NavSection.submissions.isBuilt, isTrue);
    expect(NavSection.fromPath('/submissions/review'), NavSection.submissions);
  });
}
