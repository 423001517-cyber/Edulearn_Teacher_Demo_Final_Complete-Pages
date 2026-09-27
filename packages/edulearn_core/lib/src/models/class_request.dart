import 'model_utils.dart';

enum RequestStatus {
  pending('Pending'),
  approved('Approved'),
  declined('Declined');

  const RequestStatus(this.label);
  final String label;

  static RequestStatus parse(Object? v) =>
      RequestStatus.values.firstWhere((s) => s.name == v, orElse: () => RequestStatus.pending);
}

/// `classRequests/{id}` — a teacher's "Request New Class". An admin
/// approves it (a Cloud Function creates the class and its official code)
/// or declines it with a note.
class ClassRequest {
  const ClassRequest({
    required this.id,
    required this.teacherId,
    required this.gradeLevel,
    required this.section,
    required this.subject,
    this.note = '',
    this.status = RequestStatus.pending,
    this.createdAt,
    this.decidedAt,
    this.decisionNote = '',
    this.classId,
  });

  final String id;
  final String teacherId;
  final int gradeLevel;
  final String section;
  final String subject;
  final String note;
  final RequestStatus status;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String decisionNote;

  /// The class created when the request was approved.
  final String? classId;

  factory ClassRequest.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return ClassRequest(
      id: doc.id,
      teacherId: readString(d['teacherId']),
      gradeLevel: readInt(d['gradeLevel']),
      section: readString(d['section']),
      subject: readString(d['subject'], 'Araling Panlipunan'),
      note: readString(d['note']),
      status: RequestStatus.parse(d['status']),
      createdAt: readDate(d['createdAt']),
      decidedAt: readDate(d['decidedAt']),
      decisionNote: readString(d['decisionNote']),
      classId: readStringOrNull(d['classId']),
    );
  }

  /// "Grade 4 – Luna"
  String get className => 'Grade $gradeLevel – $section';
  bool get isPending => status == RequestStatus.pending;
}
