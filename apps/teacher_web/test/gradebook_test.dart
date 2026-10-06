import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_web/app/routes.dart';
import 'package:teacher_web/providers/gradebook_providers.dart';

void main() {
  final now = DateTime(2026, 5, 30);
  ClassworkItem w(String id, ClassworkType t, int points, {int day = 20}) => ClassworkItem(
      id: id, classId: 'c', className: 'C', type: t, title: id, dueDate: DateTime(2026, 5, day), points: points);
  Submission s(String item, int? score, {String student = 'ana', SubmissionStatus status = SubmissionStatus.returned}) =>
      Submission(id: '$student-$item', classId: 'c', studentId: student, studentName: student, gradeLevel: 4,
          classworkId: item, classworkTitle: item, classworkType: ClassworkType.quest, submittedAt: DateTime(2026, 5, 19),
          status: status, score: score, maxScore: 50);

  final cols = [w('quest', ClassworkType.quest, 10), w('quiz', ClassworkType.quiz, 20), w('boss', ClassworkType.boss, 50)];

  test('total points, missing as zero or excluded, rounding', () {
    const st = GradebookSettings();
    final subs = {'quest': s('quest', 10), 'quiz': s('quiz', 17)}; // boss missing
    expect(overallGrade(st, cols, subs, now), 34); // 27 / 80
    expect(overallGrade(st.copyWith(missingAsZero: false), cols, subs, now), 90); // 27 / 30
    expect(overallGrade(st.copyWith(missingAsZero: false, roundGrades: false), [cols[1]], {'quiz': s('quiz', 17)}, now), 85.0);
    expect(overallGrade(st.copyWith(calculation: GradeCalculation.none), cols, subs, now), isNull);
    expect(overallGrade(st.copyWith(hiddenColumns: ['boss']), cols, subs, now), 90);
    // Not due yet and turned-in-but-ungraded work doesn't count.
    final later = w('later', ClassworkType.quest, 10, day: 31);
    expect(overallGrade(st, [cols[0], later], {'quest': s('quest', 8)}, now), 80);
    expect(overallGrade(st, [cols[0]], {'quest': s('quest', null, status: SubmissionStatus.pending)}, now), isNull);
  });

  test('weighted by category', () {
    final st = const GradebookSettings().copyWith(calculation: GradeCalculation.weighted);
    // quest 100% (w25), quiz 85% (w20), boss 80% (w30) → (2500+1700+2400)/75 = 88
    final subs = {'quest': s('quest', 10), 'quiz': s('quiz', 17), 'boss': s('boss', 40)};
    expect(overallGrade(st, cols, subs, now), 88);
  });

  test('letters and scale validation', () {
    const st = GradebookSettings();
    expect(st.letterFor(94)?.letter, 'A');
    expect(st.letterFor(79.6)?.letter, 'B'); // rounds to 80
    expect(st.letterFor(72)?.letter, 'D');
    expect(st.letterFor(12)?.letter, 'F');
    expect(validateScale(GradeLevel.defaults), isNull);
    expect(validateScale(const [GradeLevel('A', 90, 100, 0), GradeLevel('F', 0, 95, 0)]), contains('overlap'));
    expect(validateScale(const [GradeLevel('A', 90, 100, 0), GradeLevel('F', 0, 80, 0)]), contains('gap'));
    expect(validateScale(const [GradeLevel('A', 10, 100, 0)]), contains('start at 0'));
  });

  test('grid: columns, missing, needs grading, averages, distribution', () {
    final roster = [
      const Student(id: 'ana', name: 'Ana Cruz', classId: 'c', gradeLevel: 4),
      const Student(id: 'dan', name: 'Daniel Perez', classId: 'c', gradeLevel: 4),
    ];
    final d = buildGradebook(
      work: [...cols, ClassworkItem(id: 'lesson', classId: 'c', className: 'C', type: ClassworkType.lesson, title: 'L', dueDate: DateTime(2026, 5, 1))],
      roster: roster,
      submissions: [
        s('quest', 10), s('quiz', 18), s('boss', 46),
        s('quest', 9, student: 'dan'), s('quiz', null, student: 'dan', status: SubmissionStatus.pending),
      ],
      settings: const GradebookSettings(),
      now: now,
    );
    expect(d.columns.map((c) => c.id), ['quest', 'quiz', 'boss']); // lessons aren't graded
    expect(d.overall['ana'], 93); // 74 / 80
    expect(d.missing, 1); // dan's boss
    expect(d.needsGrading, 1); // dan's quiz
    expect(d.columnAverage['quest'], 9.5);
    expect(d.distribution['A'], 1);
    expect(Routes.gradebook(classId: 'c'), '/gradebook?classId=c');
    expect(NavSection.gradebook.isBuilt, isTrue);
  });
}
