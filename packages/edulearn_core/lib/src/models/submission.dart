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
