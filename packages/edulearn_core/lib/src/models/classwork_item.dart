import 'package:cloud_firestore/cloud_firestore.dart';

import '../dates.dart';
import 'model_utils.dart';

enum ClassworkType {
  lesson('Lesson'),
  quest('Quest'),
  quiz('Quiz'),
  boss('Friday Boss Assessment'),
  activity('Activity');

  const ClassworkType(this.label);
  final String label;

  bool get isGraded => this != ClassworkType.lesson;

  int get defaultPoints => switch (this) {
        ClassworkType.lesson => 0,
        ClassworkType.activity => 10,
        ClassworkType.boss => 50,
        ClassworkType.quest || ClassworkType.quiz => 20,
      };

  static ClassworkType parse(Object? v) => ClassworkType.values
      .firstWhere((t) => t.name == v, orElse: () => ClassworkType.quest);
}

enum ClassworkStatus {
  draft('Draft'),
  scheduled('Scheduled'),
  published('Published'),
  closed('Closed');

  const ClassworkStatus(this.label);
  final String label;

  static ClassworkStatus parse(Object? v) => ClassworkStatus.values
      .firstWhere((s) => s.name == v, orElse: () => ClassworkStatus.published);
}

/// `classwork/{itemId}` — lessons, quests, quizzes, activities and
/// Friday Boss Assessments share one collection, keyed by `type`.
class ClassworkItem {
  const ClassworkItem({
    this.id = '',
    required this.classId,
    required this.className,
    required this.type,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.status = ClassworkStatus.published,
    this.points = 0,
    this.attachmentUrl,
    this.attachmentName,
    this.assignedStudentIds = const [],
    this.createdAt,
    this.submittedCount = 0,
    this.scoreSum = 0,
    this.scoredCount = 0,
  });

  final String id;
  final String classId;
  final String className;
  final ClassworkType type;
  final String title;
  final String description;
  final DateTime dueDate;
  final ClassworkStatus status;
  final int points;
  final String? attachmentUrl;
  final String? attachmentName;

  /// Empty = whole class. Remedial quests target specific students.
  final List<String> assignedStudentIds;
  final DateTime? createdAt;

  // Maintained by the `onSubmissionWritten` Cloud Function.
  final int submittedCount;
  final double scoreSum; // sum of score/maxScore ratios
  final int scoredCount;

  factory ClassworkItem.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return ClassworkItem(
      id: doc.id,
      classId: readString(d['classId']),
      className: readString(d['className']),
      type: ClassworkType.parse(d['type']),
      title: readString(d['title'], 'Untitled'),
      description: readString(d['description']),
      dueDate: readDate(d['dueDate']) ?? DateTime.now(),
      status: ClassworkStatus.parse(d['status']),
      points: readInt(d['points']),
      attachmentUrl: readStringOrNull(d['attachmentUrl']),
      attachmentName: readStringOrNull(d['attachmentName']),
      assignedStudentIds: readStringList(d['assignedStudentIds']),
      createdAt: readDate(d['createdAt']),
      submittedCount: readInt(d['submittedCount']),
      scoreSum: readDouble(d['scoreSum']),
      scoredCount: readInt(d['scoredCount']),
    );
  }

  Json toMap() => {
        'classId': classId,
        'className': className,
        'type': type.name,
        'title': title,
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': status.name,
        'points': points,
        'attachmentUrl': attachmentUrl,
        'attachmentName': attachmentName,
        'assignedStudentIds': assignedStudentIds,
      };

  /// "Monday Quest", "Thursday Activity", "Friday Boss Assessment".
  String get headline => switch (type) {
        ClassworkType.quest || ClassworkType.activity =>
          '${weekdayName(dueDate)} ${type.label}',
        _ => type.label,
      };

  bool get isRemedial => assignedStudentIds.isNotEmpty;

  /// Share of assigned students who submitted, 0.0 – 1.0.
  double completionRate(int classSize) {
    final assigned = assignedStudentIds.isNotEmpty ? assignedStudentIds.length : classSize;
    if (assigned <= 0) return 0;
    return (submittedCount / assigned).clamp(0.0, 1.0).toDouble();
  }

  /// Average score of returned work, or null if nothing is graded yet.
  double? get averageScore => scoredCount == 0 ? null : scoreSum / scoredCount;

  bool isPastDue(DateTime now) => dueDate.isBefore(startOfDay(now));

  ClassworkItem copyWith({
    String? id,
    String? classId,
    String? className,
    DateTime? dueDate,
    ClassworkStatus? status,
    List<String>? assignedStudentIds,
  }) =>
      ClassworkItem(
        id: id ?? this.id,
        classId: classId ?? this.classId,
        className: className ?? this.className,
        type: type,
        title: title,
        description: description,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        points: points,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        assignedStudentIds: assignedStudentIds ?? this.assignedStudentIds,
      );
}
