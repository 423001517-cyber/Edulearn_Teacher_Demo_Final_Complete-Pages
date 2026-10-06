import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared logic used by every EduLearn app. Run with `flutter test` in
/// packages/edulearn_core.
void main() {
  // Saturday, 26 September 2026
  final now = DateTime(2026, 9, 26, 10);

  group('performance chart', () {
    test('This Week = Monday to Friday of the current week', () {
      final buckets = const PerformanceRange(RangeKind.week).buckets(DateTime(2026, 9, 23, 14));
      expect(buckets.map((b) => b.label), ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
      expect(buckets.first.start, DateTime(2026, 9, 21));
      expect(buckets.last.end, DateTime(2026, 9, 26));
    });

    test('bucket averages leave gaps where there is no data', () {
      final buckets = const PerformanceRange(RangeKind.week).buckets(DateTime(2026, 9, 23));
      final values = bucketAverages(buckets, [
        PerformancePoint(DateTime(2026, 9, 21, 8), 0.6),
        PerformancePoint(DateTime(2026, 9, 21, 15), 0.8),
        PerformancePoint(DateTime(2026, 9, 23), 0.9),
      ]);
      expect(values[0], closeTo(0.7, 1e-9));
      expect(values[1], isNull);
      expect(values[2], closeTo(0.9, 1e-9));
    });

    test('provider family keys compare by value', () {
      expect(const PerformanceRange(RangeKind.week), const PerformanceRange(RangeKind.week));
      expect(
        const PerformanceQuery(classId: 'a', range: PerformanceRange(RangeKind.month)),
        const PerformanceQuery(classId: 'a', range: PerformanceRange(RangeKind.month)),
      );
    });
  });

  group('class reports', () {
    test('quarter ranges', () {
      final q = ReportPeriod.thisQuarter.range(now);
      expect(q.start, DateTime(2026, 7));
      expect(q.end, DateTime(2026, 10));
      expect(ReportPeriod.thisQuarter.previousRange(now).start, DateTime(2026, 4));
      final early = ReportPeriod.lastQuarter.range(DateTime(2026, 2, 10));
      expect(early.start, DateTime(2025, 10));
      expect(early.end, DateTime(2026, 1));
    });

    test('summary matches the View Reports mockup (+12%, +8%, +4%, −6)', () {
      MonthlyStat m(int month, double c, double a, double t, int miss) =>
          MonthlyStat(month: DateTime(2026, month), completion: c, averageScore: a, attendance: t, missingWork: miss);
      final stats = [
        m(4, 0.62, 0.73, 0.895, 10), m(5, 0.63, 0.74, 0.9, 9), m(6, 0.64, 0.75, 0.905, 8),
        m(7, 0.74, 0.81, 0.935, 4), m(8, 0.75, 0.82, 0.94, 3), m(9, 0.76, 0.83, 0.945, 2),
      ];
      final s = ReportSummary.compute(stats, ReportPeriod.thisQuarter, now);
      expect(s.completion.value, closeTo(0.75, 1e-9));
      expect(s.completion.delta, closeTo(0.12, 1e-9));
      expect(s.averageScore.delta, closeTo(0.08, 1e-9));
      expect(s.attendance.delta, closeTo(0.04, 1e-9));
      expect(s.missingWork.value, 2);
      expect(s.missingWork.delta, -6);
      expect(s.trend.map((x) => x.month.month), [4, 5, 6, 7, 8, 9]);
    });

    test('no previous data means no delta', () {
      final s = ReportSummary.compute(
        [MonthlyStat(month: DateTime(2026, 9), completion: 0.5, averageScore: 0.5, attendance: 0.9, missingWork: 1)],
        ReportPeriod.thisQuarter,
        now,
      );
      expect(s.completion.value, 0.5);
      expect(s.completion.delta, isNull);
    });

    test('completion breakdown: completed / ongoing / overdue and by activity', () {
      ClassworkItem w(String id, ClassworkType type, DateTime due, int submitted,
              {ClassworkStatus status = ClassworkStatus.published}) =>
          ClassworkItem(
            id: id,
            classId: 'c',
            className: 'Grade 4 – Rizal',
            type: type,
            title: id,
            dueDate: due,
            status: status,
            submittedCount: submitted,
          );
      final items = [
        w('q1', ClassworkType.quest, DateTime(2026, 9, 21), 18), // Monday, 90% → completed
        w('a1', ClassworkType.activity, DateTime(2026, 9, 24), 12), // Thursday, 60% → overdue
        w('b1', ClassworkType.boss, DateTime(2026, 9, 28), 0), // future → ongoing
        w('l1', ClassworkType.lesson, DateTime(2026, 9, 21), 0), // lessons aren't graded
        w('d1', ClassworkType.quiz, DateTime(2026, 9, 22), 0, status: ClassworkStatus.draft),
      ];
      final b = completionBreakdown(items, 20, ReportPeriod.thisQuarter.range(now), now);
      expect(b.completed, 1);
      expect(b.overdue, 1);
      expect(b.ongoing, 1);
      expect(b.byActivity.map((x) => x.label),
          ['Monday Quest', 'Thursday Activity', 'Friday Boss Assessment']);
      expect(b.byActivity.first.rate, closeTo(0.9, 1e-9));
    });

    test('score distribution bands', () {
      Student s(double avg) => Student(id: '$avg', name: 'S', classId: 'c', gradeLevel: 4, averageScore: avg);
      final d = scoreDistribution([s(0.95), s(0.91), s(0.8), s(0.65), s(0.4)]);
      expect(d[ScoreBand.excellent], 2);
      expect(d[ScoreBand.proficient], 1);
      expect(d[ScoreBand.developing], 1);
      expect(d[ScoreBand.needsSupport], 1);
    });

    test('attendance week trend and latest day', () {
      AttendanceDay day(int d, Map<String, AttendanceMark> marks) =>
          AttendanceDay(classId: 'c', date: DateTime(2026, 9, d), marks: marks);
      final days = [
        day(21, {'a': AttendanceMark.present, 'b': AttendanceMark.absent}),
        day(25, {'a': AttendanceMark.late, 'b': AttendanceMark.present}),
      ];
      expect(latestAttendance(days)!.date, DateTime(2026, 9, 25));
      final t = weekTrend(days);
      expect(t.labels, ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
      expect(t.rates, [0.5, null, null, null, 1.0]);
    });

    test('Manila-keyed document ids parse as local dates', () {
      expect(dateFromKey('2026-09'), DateTime(2026, 9));
      expect(dateFromKey('rizal-4a_2026-09-26'), DateTime(2026, 9, 26));
      expect(dateFromKey('not-a-date'), isNull);
    });
  });

  group('students', () {
    Student student({int missing = 0, double? recent, double? avg, DateTime? lastActive}) => Student(
          id: 's',
          name: 'Carlo Reyes',
          classId: 'c',
          gradeLevel: 4,
          missingCount: missing,
          recentScore: recent,
          averageScore: avg,
          lastActiveAt: lastActive,
        );

    test('support flag priority: missing > low score > inactive', () {
      expect(student(missing: 2, recent: 0.4).supportFlag(now)!.label, 'Missing 2 quests');
      expect(student(recent: 0.5).supportFlag(now)!.label, 'Low assessment score');
      expect(student(lastActive: DateTime(2026, 9, 23)).supportFlag(now)!.label, 'Inactive 3 days');
      expect(student(recent: 0.9, lastActive: now).supportFlag(now), isNull);
    });

    test('status pill: Needs Support / Excellent / On Track', () {
      expect(student(missing: 1, avg: 0.95).standing(now), Standing.needsSupport);
      expect(student(avg: 0.94, recent: 0.95).standing(now), Standing.excellent);
      expect(student(avg: 0.85, recent: 0.86).standing(now), Standing.onTrack);
    });

    test('missing work status label', () {
      final m = MissingWork(
        id: 'x',
        classId: 'c',
        studentId: 's',
        studentName: 'Carlo Reyes',
        classworkId: 'w',
        classworkTitle: 'Thursday Activity',
        classworkType: ClassworkType.activity,
        dueDate: DateTime(2026, 9, 23),
      );
      expect(m.statusLabel(now), '3 days overdue');
      expect(m.isOverdue(now), isTrue);
    });
  });

  group('class stream posts', () {
    test('formatting: bold, italic, underline, links and bullets', () {
      final segs = parseInline('**Basahin** ang *pahina 1* at __gabay__: [aralin](https://edulearn.ph/a)');
      expect(segs.map((s) => s.style).toList(), [
        SegmentStyle.bold, SegmentStyle.plain, SegmentStyle.italic, SegmentStyle.plain,
        SegmentStyle.underline, SegmentStyle.plain, SegmentStyle.link,
      ]);
      expect(segs.last.url, 'https://edulearn.ph/a');
      expect(parseInline('see https://youtu.be/x').last.url, 'https://youtu.be/x');
      final lines = parsePost('Mga dadalhin:\n• lapis\n- papel');
      expect(lines.map((l) => l.bullet).toList(), [false, true, true]);
      expect(plainText('**Hi** *there*'), 'Hi there');
    });

    test('a short first line becomes the headline', () {
      expect(splitHeadline('Welcome to Quarter 1!\nMagandang araw!'),
          (title: 'Welcome to Quarter 1!', body: 'Magandang araw!'));
      expect(splitHeadline('Just one line'), (title: '', body: 'Just one line'));
      expect(splitHeadline('• item one\n• item two').title, '');
    });

    test('scheduled posts go live at publishAt; drafts never do', () {
      final at = DateTime(2026, 9, 27, 8);
      final scheduled = Announcement(status: PostStatus.scheduled, publishAt: at, body: 'x');
      expect(scheduled.isLive(DateTime(2026, 9, 27, 7, 59)), isFalse);
      expect(scheduled.isLive(at), isTrue);
      expect(scheduled.postedAt, at);
      expect(const Announcement(status: PostStatus.draft, body: 'x').isLive(now), isFalse);
      expect(const Announcement(body: '**Paalala:** quiz bukas').headline, 'Paalala: quiz bukas');
    });

    test('attachment size labels', () {
      expect(formatBytes(2516582), '2.4 MB');
      expect(formatBytes(5452595), '5.2 MB');
      expect(formatBytes(840 * 1024), '840 KB');
      expect(formatBytes(null), '');
      expect(const PostAttachment(name: 'Q1_Orientation.pdf').extension, 'PDF');
    });
  });
}
