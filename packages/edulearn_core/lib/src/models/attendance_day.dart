import 'model_utils.dart';

enum AttendanceMark { present, late, absent }

/// `attendance/{classId_yyyy-MM-dd}` — one document per class per school day.
class AttendanceDay {
  const AttendanceDay({required this.classId, required this.date, required this.marks});

  final String classId;
  final DateTime date;

  /// studentId -> mark
  final Map<String, AttendanceMark> marks;

  factory AttendanceDay.fromDoc(Doc doc) {
    final d = dataOf(doc);
    final raw = d['marks'];
    final marks = <String, AttendanceMark>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final mark = AttendanceMark.values.where((m) => m.name == v);
        if (k is String && mark.isNotEmpty) marks[k] = mark.first;
      });
    }
    return AttendanceDay(
      classId: readString(d['classId']),
      date: dateFromKey(doc.id) ?? readDate(d['date']) ?? DateTime.now(),
      marks: marks,
    );
  }

  int count(AttendanceMark m) => marks.values.where((v) => v == m).length;

  /// Present or late counts as attended.
  double get rate {
    if (marks.isEmpty) return 0;
    return (count(AttendanceMark.present) + count(AttendanceMark.late)) / marks.length;
  }
}
