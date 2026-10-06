import 'model_utils.dart';

enum ClassStatus {
  active,
  archived;

  static ClassStatus parse(Object? v) =>
      v == ClassStatus.archived.name ? ClassStatus.archived : ClassStatus.active;
}

/// Who may post and comment in the class stream (Class settings).
enum StreamPermission {
  postAndComment('Students can post and comment'),
  commentOnly('Students can only comment'),
  teachersOnly('Only teachers can post or comment');

  const StreamPermission(this.label);
  final String label;

  static StreamPermission parse(Object? v) => StreamPermission.values
      .firstWhere((p) => p.name == v, orElse: () => StreamPermission.postAndComment);
}

/// How new classwork appears in the stream (Class settings).
enum ClassworkNotices {
  details('Show attachments and details'),
  condensed('Show condensed notifications'),
  hidden('Hide notifications');

  const ClassworkNotices(this.label);
  final String label;

  static ClassworkNotices parse(Object? v) => ClassworkNotices.values
      .firstWhere((n) => n.name == v, orElse: () => ClassworkNotices.condensed);
}

/// `classes/{classId}` — created by an administrator (grade, section and
/// class code are official). Counters and averages are kept current by
/// Cloud Functions. Teachers may change the status, subject, cover, room,
/// description and the Class settings preferences.
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
    this.room = '',
    this.description = '',
    this.streamPermission = StreamPermission.postAndComment,
    this.classworkNotices = ClassworkNotices.condensed,
    this.totalPoints = 20,
    this.showOverallGrade = true,
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

  // ---- Edit class details / Class settings
  final String room;
  final String description;
  final StreamPermission streamPermission;
  final ClassworkNotices classworkNotices;

  /// Default points for new graded classwork in this class.
  final int totalPoints;

  /// Students see their overall grade in the Gradebook (student app).
  final bool showOverallGrade;

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
      room: readString(d['room']),
      description: readString(d['description']),
      streamPermission: StreamPermission.parse(d['streamPermission']),
      classworkNotices: ClassworkNotices.parse(d['classworkNotifications']),
      totalPoints: d['totalPoints'] is num ? (d['totalPoints'] as num).toInt() : 20,
      showOverallGrade: d['showOverallGrade'] != false,
    );
  }

  /// "Grade 4 – Rizal"
  String get name => 'Grade $gradeLevel – $section';
  String get gradeLabel => 'Grade $gradeLevel';
  bool get isArchived => status == ClassStatus.archived;
}
