import '../dates.dart';
import 'classwork_item.dart';
import 'model_utils.dart';

/// `missingWork/{studentId_classworkId}` — one row per student per item they
/// haven't submitted. Created by `nightlyRollup`, deleted by
/// `onSubmissionWritten` the moment the student turns the work in.
class MissingWork {
  const MissingWork({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.classworkId,
    required this.classworkTitle,
    required this.classworkType,
    required this.dueDate,
  });

  final String id;
  final String classId;
  final String studentId;
  final String studentName;
  final String classworkId;
  final String classworkTitle;
  final ClassworkType classworkType;
  final DateTime dueDate;

  factory MissingWork.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return MissingWork(
      id: doc.id,
      classId: readString(d['classId']),
      studentId: readString(d['studentId']),
      studentName: readString(d['studentName'], 'Student'),
      classworkId: readString(d['classworkId']),
      classworkTitle: readString(d['classworkTitle'], 'Classwork'),
      classworkType: ClassworkType.parse(d['classworkType']),
      dueDate: readDate(d['dueDate']) ?? DateTime.now(),
    );
  }

  /// Positive = days overdue; zero or negative = still open.
  int daysOverdue(DateTime now) =>
      startOfDay(now).difference(startOfDay(dueDate)).inDays;

  bool isOverdue(DateTime now) => daysOverdue(now) > 0;

  String statusLabel(DateTime now) {
    final d = daysOverdue(now);
    if (d > 0) return '$d ${d == 1 ? 'day' : 'days'} overdue';
    if (d == 0) return 'Due today';
    return 'Due in ${-d} ${d == -1 ? 'day' : 'days'}';
  }
}
