import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logic behind the Attendance, Rewards, Analytics, Messages and Settings
/// pages. Run with `flutter test` in packages/edulearn_core.
void main() {
  // Monday, 19 October 2026
  final now = DateTime(2026, 10, 19, 12);

  group('attendance', () {
    AttendanceDay day(int d, Map<String, AttendanceMark> marks) =>
        AttendanceDay(classId: 'c', date: DateTime(2026, 10, d), marks: marks);

    test('excused days count neither for nor against the rate', () {
      final d = day(19, {
        'a': AttendanceMark.present,
        'b': AttendanceMark.late,
        'c': AttendanceMark.absent,
        'd': AttendanceMark.excused,
      });
      expect(d.rate, closeTo(2 / 3, 1e-9));
      expect(d.count(AttendanceMark.excused), 1);
      expect(AttendanceDay.docId('rizal-4a', DateTime(2026, 10, 9)), 'rizal-4a_2026-10-09');
    });

    test('tallies, follow-up and summary text', () {
      final days = [
        day(5, {'a': AttendanceMark.absent, 'b': AttendanceMark.late}),
        day(6, {'a': AttendanceMark.absent, 'b': AttendanceMark.late}),
        day(7, {'a': AttendanceMark.excused, 'b': AttendanceMark.late}),
        day(8, {'a': AttendanceMark.present, 'b': AttendanceMark.present}),
      ];
      final t = tallyByStudent(days);
      expect(t['a']!.rate, closeTo(1 / 3, 1e-9));
      expect(t['a']!.needsFollowUp, isTrue);
      expect(t['a']!.summary, '2 absences, 1 excused');
      expect(t['b']!.rate, 1.0);
      expect(t['b']!.summary, '3 lates');
      expect(pooledRate(days), closeTo(5 / 7, 1e-9));
    });

    test('weekly rates, oldest first', () {
      final weeks = weeklyRates([day(5, {'a': AttendanceMark.present}), day(19, {'a': AttendanceMark.absent})], now);
      expect(weeks.length, 4);
      expect(weeks.last.monday, DateTime(2026, 10, 19));
      expect(weeks.last.rate, 0.0);
      expect(weeks[2].rate, isNull);
      expect(weeks[1].label, 'Oct 5 – 9');
      expect(weeks[1].rate, 1.0);
    });

    test('school days skip weekends', () {
      expect(nextSchoolDay(DateTime(2026, 10, 19), -1), DateTime(2026, 10, 16));
      expect(nextSchoolDay(DateTime(2026, 10, 16), 1), DateTime(2026, 10, 19));
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('rewards', () {
    ClassworkItem w(String id, ClassworkType t, int day, int points) => ClassworkItem(
        id: id, classId: 'c', className: 'C', type: t, title: id, dueDate: DateTime(2026, 10, day, 23, 59), points: points);
    final work = [
      w('quest', ClassworkType.quest, 12, 20),
      w('quiz', ClassworkType.quiz, 14, 20),
      w('activity', ClassworkType.activity, 15, 10),
      w('boss', ClassworkType.boss, 16, 50),
    ];
    Submission s(String student, String item, int score, int max, DateTime at) => Submission(
        id: '$student-$item', classId: 'c', studentId: student, studentName: student, gradeLevel: 4,
        classworkId: item, classworkTitle: item, classworkType: ClassworkType.quest, submittedAt: at,
        status: SubmissionStatus.returned, score: score, maxScore: max);
    DateTime early(int day) => DateTime(2026, 10, day - 2, 18);
    final students = [
      const Student(id: 'ana', name: 'Ana Lopez', classId: 'c', gradeLevel: 4),
      const Student(id: 'ben', name: 'Ben Cruz', classId: 'c', gradeLevel: 4),
    ];
    final subs = [
      s('ana', 'quest', 20, 20, early(12)),
      s('ana', 'quiz', 20, 20, early(14)),
      s('ana', 'activity', 9, 10, early(15)),
      s('ana', 'boss', 40, 50, early(16)),
      s('ben', 'quest', 12, 20, DateTime(2026, 10, 13, 9)), // a day late
    ];
    final awards = [
      PointAward(
        id: 'a1', classId: 'c', studentId: 'ana', studentName: 'Ana Lopez', points: 20,
        badgeId: 'helping-hand', createdAt: DateTime(2026, 10, 18),
      ),
    ];
    final requests = [
      RewardRequest(
        id: 'r1', classId: 'c', studentId: 'ana', studentName: 'Ana Lopez', itemId: 'seat',
        itemName: 'Seat', cost: 50, status: RewardStatus.approved,
      ),
    ];

    List<StudentRewards> run({DateTime? from}) => computeRewards(
          students: students,
          work: work,
          submissions: subs,
          awards: awards,
          requests: requests,
          settings: const RewardSettings(),
          now: now,
          periodStart: from,
        );

    test('points, level, balance and streak', () {
      final ana = run().first;
      // quest 10+5, quiz 25+5, activity 15+5, boss 30+5, award 20
      expect(ana.earned, 120);
      expect(ana.spent, 50);
      expect(ana.balance, 70);
      expect(ana.level, 1);
      expect(ana.levelProgress, closeTo(0.6, 1e-9));
      expect(ana.toNextLevel, 80);
      expect(ana.streak, 4);
      final ben = run()[1];
      expect(ben.earned, 10); // late: no on-time bonus
      expect(ben.streak, 0);
    });

    test('badges are worked out from the rules', () {
      final ids = run().first.badges.map((b) => b.id).toList();
      expect(ids, containsAll(['quiz-whiz', 'perfect-week', 'early-bird', 'helping-hand']));
      expect(ids, isNot(contains('boss-slayer'))); // needs 3 passes
      expect(ids, isNot(contains('top-scorer'))); // needs 5 scores of 90%+
      expect(badgeCounts(run())['quiz-whiz'], 1);
    });

    test('leaderboard by period', () {
      final rows = run(from: DateTime(2026, 10, 13));
      expect(rows.first.earnedInPeriod, 75); // activity 20 + boss 35 + award 20
      expect(rows[1].earnedInPeriod, 10);
      expect(leaderboard(rows, byPeriod: true).map((r) => r.student.id), ['ana', 'ben']);
    });

    test('settings survive a round trip', () {
      final s = const RewardSettings().copyWith(points: {PointRule.quest: 12}, levelSize: 300);
      final back = RewardSettings.fromMap(s.toMap());
      expect(back.pointsFor(PointRule.quest), 12);
      expect(back.pointsFor(PointRule.onTime), 5);
      expect(back.levelSize, 300);
      expect(back.badges.length, RewardSettings.defaultBadges.length);
      expect(back.badges.first.ruleText, 'Score 90% or higher 5 times');
    });
  });

  group('analytics', () {
    ClassworkItem w(String id, {double sum = 0, int scored = 0, int submitted = 0, int day = 10, String? topic}) =>
        ClassworkItem(
          id: id, classId: 'c', className: 'C', type: ClassworkType.quest, title: id,
          dueDate: DateTime(2026, 10, day), scoreSum: sum, scoredCount: scored, submittedCount: submitted, topicId: topic,
        );

    test('weighted average and completion', () {
      expect(weightedAverage([w('a', sum: 1.6, scored: 2), w('b', sum: 0.8, scored: 1)]), closeTo(0.8, 1e-9));
      expect(weightedAverage([w('c')]), isNull);
      final items = [w('a', submitted: 4), w('b', submitted: 2), w('future', submitted: 0, day: 30)];
      expect(averageCompletion(items, {'c': 4}, now), closeTo(0.75, 1e-9));
    });

    test('topics, newest first, without the week prefix', () {
      expect(topicLabel('Week 3: Klima at Panahon'), 'Klima at Panahon');
      final topics = [
        const ClassTopic(id: 't1', name: 'Week 1: Mapa', position: 1),
        const ClassTopic(id: 't2', name: 'Week 2: Rehiyon', position: 2),
      ];
      final m = topicMastery([
        w('a', sum: 0.9, scored: 1, topic: 't1'),
        w('b', sum: 0.6, scored: 1, topic: 't2'),
        w('c', sum: 0.8, scored: 1, topic: 't2'),
      ], topics);
      expect(m.map((t) => t.name), ['Rehiyon', 'Mapa']);
      expect(m.first.average, closeTo(0.7, 1e-9));
    });

    test('letter distribution and most improved', () {
      Student st(String id, double avg, double recent) =>
          Student(id: id, name: id, classId: 'c', gradeLevel: 4, averageScore: avg, recentScore: recent);
      final students = [st('a', 0.95, 0.95), st('b', 0.85, 0.9), st('c', 0.6, 0.62)];
      final d = letterDistribution(students, const GradebookSettings());
      expect(d.map((x) => '${x.level.letter}${x.count}'), ['A1', 'B1', 'C0', 'D0', 'F1']);
      final up = mostImproved(students);
      expect(up.first.student.id, 'b');
      expect(up.first.gain, closeTo(0.05, 1e-9));
    });

    test('ranges and comparison periods', () {
      final r = AnalyticsRange.month.range(now);
      expect(r.start, DateTime(2026, 10));
      expect(AnalyticsRange.month.previous(now).start, DateTime(2026, 9));
      expect(AnalyticsRange.parse('quarter'), AnalyticsRange.quarter);
      expect(AnalyticsRange.parse(null), AnalyticsRange.month);
      expect(seriesGain([null, 0.7, null, 0.82]), closeTo(0.12, 1e-9));
    });
  });

  group('settings, messages, students', () {
    test('preferences round trip and defaults', () {
      final p = const TeacherPreferences().copyWith(bossPoints: 40, weekStartsMonday: true)
          .withChoice(NotifyTopic.comments, const NotifyChoice(web: false, email: true));
      final back = TeacherPreferences.fromMap(p.toMap());
      expect(back, p);
      expect(back.choiceFor(NotifyTopic.comments).web, isFalse);
      expect(back.pointsFor(ClassworkType.boss), 40);
      expect(back.pointsFor(ClassworkType.quest), isNull);
      expect(TeacherPreferences.fromMap(null).gradebookDefaults.passingGrade, 75);
    });

    test('conversation ids and previews', () {
      expect(Conversation.directId('t1', 's1'), 'dm_t1_s1');
      expect(Conversation.groupId('rizal-4a'), 'class_rizal-4a');
      const c = Conversation(
        id: 'x', teacherId: 't', classId: 'c', kind: ConversationKind.group, title: 'Grade 4 – Rizal',
        lastMessage: 'Yes po!', lastRole: MessageRole.student, lastAuthor: 'Ana',
      );
      expect(c.preview, 'Ana: Yes po!');
    });

    test('calendar weeks can start on Monday', () {
      expect(monthGrid(DateTime(2026, 10)).first, DateTime(2026, 9, 27));
      expect(monthGrid(DateTime(2026, 10), mondayFirst: true).first, DateTime(2026, 9, 28));
      expect(weekDays(DateTime(2026, 10, 18), mondayFirst: true).first, DateTime(2026, 10, 12));
      expect(weekdayNames(mondayFirst: true).first, 'Mon');
    });

    test('low recent score means Watch, missing work means Needs support', () {
      const s = Student(id: 's', name: 'Carlo Reyes', classId: 'c', gradeLevel: 4, recentScore: 0.5, averageScore: 0.7);
      expect(s.standing(now), Standing.watch);
      const m = Student(id: 'm', name: 'Juan', classId: 'c', gradeLevel: 4, missingCount: 1);
      expect(m.standing(now), Standing.needsSupport);
    });

    test('teacher title', () {
      const t = Teacher(uid: 'u', displayName: 'Jean Magallanes');
      expect(t.title, 'Teacher Jean');
      const t2 = Teacher(uid: 'u', displayName: 'Jean Magallanes', titleName: 'Ma’am Jean');
      expect(t2.title, 'Ma’am Jean');
    });
  });
}
