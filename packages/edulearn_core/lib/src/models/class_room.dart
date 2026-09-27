import 'model_utils.dart';

enum ClassStatus {
  active,
  archived;

  static ClassStatus parse(Object? v) =>
      v == ClassStatus.archived.name ? ClassStatus.archived : ClassStatus.active;
}

/// `classes/{classId}` — created by an administrator (class codes are
/// official). Counters and averages are kept current by Cloud Functions;
/// teachers may only change `status`, `subject` and `coverImageUrl`.
class ClassRoom {
  const ClassRoom({
    required this.id,
    required this.teacherId,
    required this.gradeLevel,
    required this.section,
    this.subject = 'Araling Panlipunan',
    this.classCode = '',
    this.status = ClassStatus.active,
    this.studentCount = 0,
    this.questCount = 0,
    this.completionRate = 0,
    this.averageScore = 0,
    this.coverImageUrl,
    this.colorIndex = 0,
    this.archivedAt,
  });

  final String id;
  final String teacherId;
  final int gradeLevel;
  final String section;
  final String subject;

  /// Students join with this code, e.g. "RIZAL-4A".
  final String classCode;
  final ClassStatus status;
  final int studentCount;

  /// Graded classwork currently assigned (quests, quizzes, activities, boss).
  final int questCount;

  /// 0.0 – 1.0
  final double completionRate;

  /// 0.0 – 1.0
  final double averageScore;
  final String? coverImageUrl;

  /// Index into [AppColors.classPalette] for chart lines and thumbnails.
  final int colorIndex;
  final DateTime? archivedAt;

  factory ClassRoom.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return ClassRoom(
      id: doc.id,
      teacherId: readString(d['teacherId']),
      gradeLevel: readInt(d['gradeLevel']),
      section: readString(d['section']),
      subject: readString(d['subject'], 'Araling Panlipunan'),
      classCode: readString(d['classCode']),
      status: ClassStatus.parse(d['status']),
      studentCount: readInt(d['studentCount']),
      questCount: readInt(d['questCount']),
      completionRate: readDouble(d['completionRate']),
      averageScore: readDouble(d['averageScore']),
      coverImageUrl: readStringOrNull(d['coverImageUrl']),
      colorIndex: readInt(d['colorIndex']),
      archivedAt: readDate(d['archivedAt']),
    );
  }

  /// "Grade 4 – Rizal"
  String get name => 'Grade $gradeLevel – $section';
  String get gradeLabel => 'Grade $gradeLevel';
  bool get isArchived => status == ClassStatus.archived;
}
