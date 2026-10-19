import '../dates.dart';
import '../models/classwork_item.dart';
import '../models/rewards.dart';
import '../models/student.dart';
import '../models/submission.dart';

/// Points, level, badges and streak for one student. Worked out from
/// submissions (automatic points), teacher awards and approved rewards, so
/// nothing extra has to be stored per student.
class StudentRewards {
  const StudentRewards({
    required this.student,
    required this.earned,
    required this.earnedInPeriod,
    required this.spent,
    required this.levelSize,
    required this.badges,
    required this.streak,
  });

  final Student student;

  /// Everything earned so far (automatic points + teacher awards).
  final int earned;

  /// Earned since the leaderboard period started.
  final int earnedInPeriod;

  /// Points spent on approved rewards.
  final int spent;
  final int levelSize;
  final List<BadgeDef> badges;

  /// On-time submissions in a row, newest first.
  final int streak;

  int get balance => earned - spent;
  int get _points => earned < 0 ? 0 : earned;
  int get level => _points ~/ levelSize + 1;
  double get levelProgress => (_points % levelSize) / levelSize;
  int get toNextLevel => levelSize - _points % levelSize;
}

bool _counts(ClassworkItem w) =>
    w.type.isGraded && (w.status == ClassworkStatus.published || w.status == ClassworkStatus.closed);

bool _assigned(ClassworkItem w, String studentId) =>
    w.assignedStudentIds.isEmpty || w.assignedStudentIds.contains(studentId);

double? _ratio(Submission s) =>
    s.status == SubmissionStatus.returned && s.score != null && s.maxScore > 0 ? s.score! / s.maxScore : null;

bool _onTime(Submission s, ClassworkItem w) => !s.submittedAt.isAfter(w.dueDate);

bool _passedBoss(Submission s, ClassworkItem w) {
  final r = _ratio(s);
  final passing = w.passingScore > 0 ? w.passingScore : 70;
  return r != null && r * 100 >= passing;
}

bool _perfect(Submission s) => s.score != null && s.maxScore > 0 && s.score == s.maxScore;

/// Rewards for every student in [students], in the same order.
List<StudentRewards> computeRewards({
  required List<Student> students,
  required List<ClassworkItem> work,
  required List<Submission> submissions,
  required List<PointAward> awards,
  required List<RewardRequest> requests,
  required RewardSettings settings,
  required DateTime now,
  DateTime? periodStart,
}) {
  final items = {for (final w in work) w.id: w};
  final byStudent = <String, List<Submission>>{};
  for (final s in submissions) {
    if (items[s.classworkId] == null) continue;
    (byStudent[s.studentId] ??= []).add(s);
  }
  final pastDue = work.where((w) => _counts(w) && w.dueDate.isBefore(now)).toList()
    ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
  final enabled = settings.badges.where((b) => b.enabled).toList();

  return [
    for (final st in students)
      () {
        final subs = byStudent[st.id] ?? const <Submission>[];
        var earned = 0, inPeriod = 0;
        void add(int pts, DateTime when) {
          earned += pts;
          if (periodStart == null || !when.isBefore(periodStart)) inPeriod += pts;
        }

        var highScores = 0, perfectQuizzes = 0, bossPasses = 0, early = 0;
        final latest = <String, Submission>{};
        for (final s in subs) {
          final w = items[s.classworkId]!;
          final prev = latest[w.id];
          if (prev == null || s.submittedAt.isAfter(prev.submittedAt)) latest[w.id] = s;
          if (!w.type.isGraded) continue;
          var pts = switch (w.type) {
            ClassworkType.quest => settings.pointsFor(PointRule.quest),
            ClassworkType.activity => settings.pointsFor(PointRule.activity),
            _ => 0,
          };
          if (w.type == ClassworkType.quiz && _perfect(s) && s.status == SubmissionStatus.returned) {
            pts += settings.pointsFor(PointRule.perfectQuiz);
            perfectQuizzes++;
          }
          if (w.type == ClassworkType.boss && _passedBoss(s, w)) {
            pts += settings.pointsFor(PointRule.bossPass);
            bossPasses++;
          }
          if (_onTime(s, w)) pts += settings.pointsFor(PointRule.onTime);
          if ((_ratio(s) ?? 0) >= 0.9) highScores++;
          if (!s.submittedAt.isAfter(w.dueDate.subtract(const Duration(hours: 24)))) early++;
          add(pts, s.submittedAt);
        }

        final manual = <String>{};
        for (final a in awards) {
          if (a.studentId != st.id) continue;
          add(a.points, a.createdAt ?? now);
          if (a.badgeId != null) manual.add(a.badgeId!);
        }

        var spent = 0;
        for (final r in requests) {
          if (r.studentId == st.id && r.status == RewardStatus.approved) spent += r.cost;
        }

        // Weeks where every assigned item was turned in on time.
        final weeks = <DateTime, bool>{};
        for (final w in pastDue) {
          if (!_assigned(w, st.id)) continue;
          final key = startOfWeek(w.dueDate);
          final s = latest[w.id];
          final ok = s != null && _onTime(s, w);
          weeks[key] = (weeks[key] ?? true) && ok;
        }
        final perfectWeeks = weeks.values.where((ok) => ok).length;

        var streak = 0;
        for (final w in pastDue) {
          if (!_assigned(w, st.id)) continue;
          final s = latest[w.id];
          if (s == null || !_onTime(s, w)) break;
          streak++;
        }

        int progress(BadgeKind k) => switch (k) {
              BadgeKind.topScorer => highScores,
              BadgeKind.quizWhiz => perfectQuizzes,
              BadgeKind.bossSlayer => bossPasses,
              BadgeKind.perfectWeek => perfectWeeks,
              BadgeKind.earlyBird => early,
              BadgeKind.manual => 0,
            };
        final badges = [
          for (final b in enabled)
            if (b.kind == BadgeKind.manual ? manual.contains(b.id) : progress(b.kind) >= b.threshold) b,
        ];

        return StudentRewards(
          student: st,
          earned: earned,
          earnedInPeriod: inPeriod,
          spent: spent,
          levelSize: settings.levelSize,
          badges: badges,
          streak: streak,
        );
      }(),
  ];
}

/// Highest first; ties by name. [byPeriod] ranks by points earned in the
/// period instead of all points.
List<StudentRewards> leaderboard(Iterable<StudentRewards> rows, {required bool byPeriod}) {
  int pts(StudentRewards r) => byPeriod ? r.earnedInPeriod : r.earned;
  return rows.toList()
    ..sort((a, b) {
      final c = pts(b).compareTo(pts(a));
      return c != 0 ? c : a.student.name.compareTo(b.student.name);
    });
}

/// How many students have each badge (badge id -> count).
Map<String, int> badgeCounts(Iterable<StudentRewards> rows) {
  final out = <String, int>{};
  for (final r in rows) {
    for (final b in r.badges) {
      out[b.id] = (out[b.id] ?? 0) + 1;
    }
  }
  return out;
}
