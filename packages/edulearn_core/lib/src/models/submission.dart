import 'classwork_item.dart';
import 'model_utils.dart';

enum SubmissionStatus {
  pending('Pending'),
  returned('Returned');

  const SubmissionStatus(this.label);
  final String label;

  static SubmissionStatus parse(Object? v) => SubmissionStatus.values
      .firstWhere((s) => s.name == v, orElse: () => SubmissionStatus.pending);
}

/// `submissions/{submissionId}` — created by the student app; the teacher
/// may only update score, privateFeedback, status and returnedAt (see rules).
class Submission {
  const Submission({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.gradeLevel,
    required this.classworkId,
    required this.classworkTitle,
    required this.classworkType,
    required this.submittedAt,
    required this.status,
    this.score,
    this.maxScore = 20,
    this.privateFeedback = '',
    this.attachmentUrl,
    this.attachmentName,
    this.textResponse = '',
    this.rubricScores = const {},
    this.returnedAt,
  });

  final String id;
  final String classId;
  final String studentId;
  final String studentName;
  final int gradeLevel;
  final String classworkId;
  final String classworkTitle;
  final ClassworkType classworkType;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final int? score;
  final int maxScore;
  final String privateFeedback;
  final String? attachmentUrl;
  final String? attachmentName;

  /// Typed answer (activities with "Text response").
  final String textResponse;

  /// Points per rubric criterion title (Review submission → Rubric).
  final Map<String, int> rubricScores;
  final DateTime? returnedAt;

  factory Submission.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return Submission(
      id: doc.id,
      classId: readString(d['classId']),
      studentId: readString(d['studentId']),
      studentName: readString(d['studentName'], 'Student'),
      gradeLevel: readInt(d['gradeLevel']),
      classworkId: readString(d['classworkId']),
      classworkTitle: readString(d['classworkTitle'], 'Classwork'),
      classworkType: ClassworkType.parse(d['classworkType']),
      submittedAt: readDate(d['submittedAt']) ?? DateTime.now(),
      status: SubmissionStatus.parse(d['status']),
      score: readIntOrNull(d['score']),
      maxScore: readInt(d['maxScore'], 20),
      privateFeedback: readString(d['privateFeedback']),
      attachmentUrl: readStringOrNull(d['attachmentUrl']),
      attachmentName: readStringOrNull(d['attachmentName']),
      textResponse: readString(d['textResponse']),
      rubricScores: d['rubricScores'] is Map
          ? {
              for (final e in (d['rubricScores'] as Map).entries)
                if (e.value is num) '${e.key}': (e.value as num).toInt(),
            }
          : const {},
      returnedAt: readDate(d['returnedAt']),
    );
  }

  /// "Kasaysayan ng Pilipinas – Quiz"
  String get displayTitle {
    final kind = classworkType == ClassworkType.boss ? 'Boss Assessment' : classworkType.label;
    return '$classworkTitle – $kind';
  }

  String get studentInitials => initialsOf(studentName);
  String get gradeLabel => 'Grade $gradeLevel';
}

/// What the teacher sees for one student on one classwork item.
enum WorkState {
  assigned('Assigned'),
  turnedIn('Turned in'),
  late('Late'),
  draft('Draft grade'),
  graded('Graded'),
  missing('Missing');

  const WorkState(this.label);
  final String label;

  /// Counts as "Turned in" on the tabs (late and draft-graded work too).
  bool get handedIn => this == turnedIn || this == late || this == draft || this == graded;

  /// Still waiting for the teacher.
  bool get needsReview => this == turnedIn || this == late || this == draft;
}

/// Pure: a student's state for [item] given their submission (if any).
/// Draft grade = scored but not returned yet ("Save draft").
WorkState workStateFor(ClassworkItem item, Submission? s, DateTime now) {
  if (s == null) {
    return item.dueDate.isBefore(now) ? WorkState.missing : WorkState.assigned;
  }
  if (s.status == SubmissionStatus.returned) return WorkState.graded;
  if (s.score != null) return WorkState.draft;
  return s.submittedAt.isAfter(item.dueDate) ? WorkState.late : WorkState.turnedIn;
}
