import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// Attendance page: read a stretch of school days and save one day.
class AttendanceRepository {
  AttendanceRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Json> get _attendance => _db.collection('attendance');

  /// Days in [from, to) for one class (uses the teacherId/classId/date index).
  Stream<List<AttendanceDay>> watchDays(String classId, DateTime from, DateTime to) => _attendance
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('date', isLessThan: Timestamp.fromDate(to))
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map(AttendanceDay.fromDoc).toList());

  /// Writes the whole day (every student's mark, notes and times).
  Future<void> saveDay(AttendanceDay day) =>
      _attendance.doc(AttendanceDay.docId(day.classId, day.date)).set(day.toMap(teacherId: uid));
}
