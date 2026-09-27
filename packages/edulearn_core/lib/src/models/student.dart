import '../dates.dart';
import 'model_utils.dart';

enum SupportLevel { urgent, watch }

class SupportFlag {
  const SupportFlag({required this.label, required this.level, required this.priority});

  final String label;
  final SupportLevel level;

  /// Higher = more urgent. Orders the "Students Needing Support" lists.
  final int priority;
}

/// Performance level used by the Students filter and the score distribution.
enum ScoreBand {
  excellent('Excellent'),
  proficient('Proficient'),
  developing('Developing'),
  needsSupport('Needs Support');

  const ScoreBand(this.label);
  final String label;

  static ScoreBand of(double score) => score >= 0.9
      ? ScoreBand.excellent
      : score >= 0.75
          ? ScoreBand.proficient
          : score >= 0.6
              ? ScoreBand.developing
              : ScoreBand.needsSupport;
}

/// The status pill in the Students table.
enum Standing {
  onTrack('On Track'),
  needsSupport('Needs Support'),
  excellent('Excellent');

  const Standing(this.label);
  final String label;
}

/// `students/{studentId}` — progress fields are recomputed nightly by the
/// `nightlyRollup` Cloud Function; the student app updates `lastActiveAt`.
class Student {
  static const lowScoreThreshold = 0.6;
  static const inactiveDaysThreshold = 3;

  const Student({
    required this.id,
    required this.name,
    required this.classId,
    required this.gradeLevel,
    this.studentNumber = '',
    this.questProgress = 0,
    this.attendanceRate,
    this.averageScore,
    this.recentScore,
    this.missingCount = 0,
    this.absences = 0,
    this.lateCount = 0,
    this.lastActiveAt,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String classId;
  final int gradeLevel;

  /// Display number, e.g. "0001" (shown as #0001).
  final String studentNumber;

  /// 0.0 – 1.0 share of assigned work submitted (last 30 days).
  final double questProgress;
  final double? attendanceRate;

  /// Average of all returned work this quarter.
  final double? averageScore;

  /// Average of the last three returned pieces of work.
  final double? recentScore;
  final int missingCount;
  final int absences;
  final int lateCount;
  final DateTime? lastActiveAt;
  final String? photoUrl;

  factory Student.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return Student(
      id: doc.id,
      name: readString(d['name'], 'Student'),
      classId: readString(d['classId']),
      gradeLevel: readInt(d['gradeLevel']),
      studentNumber: readString(d['studentNumber']),
      questProgress: readDouble(d['questProgress']),
      attendanceRate: readDoubleOrNull(d['attendanceRate']),
      averageScore: readDoubleOrNull(d['averageScore']),
      recentScore: readDoubleOrNull(d['recentScore']),
      missingCount: readInt(d['missingCount']),
      absences: readInt(d['absences']),
      lateCount: readInt(d['lateCount']),
      lastActiveAt: readDate(d['lastActiveAt']),
      photoUrl: readStringOrNull(d['photoUrl']),
    );
  }

  String get initials => initialsOf(name);
  String get firstName => firstNameOf(name);
  String get gradeLabel => 'Grade $gradeLevel';
  String get numberLabel => studentNumber.isEmpty ? '' : '#$studentNumber';

  int inactiveDays(DateTime now) => lastActiveAt == null
      ? 0
      : startOfDay(now).difference(startOfDay(lastActiveAt!)).inDays;

  ScoreBand? get band => averageScore == null ? null : ScoreBand.of(averageScore!);

  Standing standing(DateTime now) {
    if (supportFlag(now) != null) return Standing.needsSupport;
    if ((averageScore ?? 0) >= 0.9) return Standing.excellent;
    return Standing.onTrack;
  }

  bool get hasAttendanceConcern => absences >= 2 || lateCount >= 3;

  /// The single most important reason this student needs attention, if any.
  SupportFlag? supportFlag(DateTime now) {
    if (missingCount > 0) {
      return SupportFlag(
        label: 'Missing $missingCount ${missingCount == 1 ? 'quest' : 'quests'}',
        level: SupportLevel.urgent,
        priority: 300 + missingCount,
      );
    }
    final score = recentScore;
    if (score != null && score < lowScoreThreshold) {
      return const SupportFlag(
        label: 'Low assessment score',
        level: SupportLevel.watch,
        priority: 200,
      );
    }
    final idle = inactiveDays(now);
    if (idle >= inactiveDaysThreshold) {
      return SupportFlag(
        label: 'Inactive $idle days',
        level: SupportLevel.urgent,
        priority: 100 + idle,
      );
    }
    return null;
  }
}
