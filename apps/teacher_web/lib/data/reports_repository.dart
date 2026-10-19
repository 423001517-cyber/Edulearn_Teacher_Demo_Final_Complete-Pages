import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// Reads for the Class Reports page and its detail panels.
class ReportsRepository {
  ReportsRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  /// Up to two years of monthly rollups, enough for "vs last year".
  Stream<List<MonthlyStat>> watchMonthlyStats(String classId) => _db
      .collection('classes')
      .doc(classId)
      .collection('monthlyStats')
      .orderBy('month', descending: true)
      .limit(24)
      .snapshots()
      .map((s) => s.docs.map(MonthlyStat.fromDoc).toList());

  Stream<List<MissingWork>> watchMissingWork(String classId) => _db
      .collection('missingWork')
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .orderBy('dueDate')
      .snapshots()
      .map((s) => s.docs.map(MissingWork.fromDoc).toList());

  Stream<List<AttendanceDay>> watchAttendance(String classId, DateTime from) => _db
      .collection('attendance')
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map(AttendanceDay.fromDoc).toList());

  /// All of the teacher's classwork due from [from] onward (Analytics).
  Stream<List<ClassworkItem>> watchClassworkDueFrom(DateTime from) => _db
      .collection('classwork')
      .where('teacherId', isEqualTo: uid)
      .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .orderBy('dueDate')
      .limit(800)
      .snapshots()
      .map((s) => s.docs.map(ClassworkItem.fromDoc).toList());
}
