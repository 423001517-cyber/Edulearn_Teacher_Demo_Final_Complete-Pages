import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// School-wide Firestore reads and the few direct writes an admin may make
/// (the rules allow them only for users with the `admin` role).
class AdminRepository {
  AdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> get _classes => _db.collection('classes');
  CollectionReference<Json> get _students => _db.collection('students');

  Stream<List<Teacher>> watchTeachers() => _db
      .collection('teachers')
      .orderBy('displayName')
      .snapshots()
      .map((s) => s.docs.map(Teacher.fromDoc).toList());

  Stream<List<ClassRoom>> watchClasses() => _classes
      .orderBy('gradeLevel')
      .snapshots()
      .map((s) => s.docs.map(ClassRoom.fromDoc).toList()
        ..sort((a, b) {
          final g = a.gradeLevel.compareTo(b.gradeLevel);
          return g != 0 ? g : a.section.compareTo(b.section);
        }));

  Stream<List<Student>> watchStudents() =>
      _students.orderBy('name').snapshots().map((s) => s.docs.map(Student.fromDoc).toList());

  Stream<List<ClassRequest>> watchRequests() => _db
      .collection('classRequests')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(ClassRequest.fromDoc).toList());

  Stream<List<AdminUser>> watchAdmins() =>
      _db.collection('admins').snapshots().map((s) => s.docs.map(AdminUser.fromDoc).toList());

  Stream<SchoolSettings> watchSettings() => _db
      .collection('settings')
      .doc('school')
      .snapshots()
      .map((d) => d.exists ? SchoolSettings.fromDoc(d) : const SchoolSettings());

  Stream<List<MonthlyStat>> watchMonthlyStats(String classId) => _classes
      .doc(classId)
      .collection('monthlyStats')
      .orderBy('month', descending: true)
      .limit(24)
      .snapshots()
      .map((s) => s.docs.map(MonthlyStat.fromDoc).toList());

  Future<void> saveSettings(SchoolSettings s) =>
      _db.collection('settings').doc('school').set(s.toMap());

  // ---- classes (reassign / rename / archive; codes via functions)
  Future<void> updateClass(
    ClassRoom c, {
    required String teacherId,
    required int gradeLevel,
    required String section,
    required String subject,
  }) =>
      _classes.doc(c.id).update({
        'teacherId': teacherId,
        'gradeLevel': gradeLevel,
        'section': section.trim(),
        'subject': subject.trim(),
      });

  Future<void> setArchived(ClassRoom c, bool archived) => _classes.doc(c.id).update({
        'status': archived ? ClassStatus.archived.name : ClassStatus.active.name,
        'archivedAt': archived ? FieldValue.serverTimestamp() : null,
      });

  // ---- students (class rosters)
  Json _studentData(ClassRoom c, String name, String number) => {
        'name': name.trim(),
        'studentNumber': number.trim(),
        'classId': c.id,
        'teacherId': c.teacherId,
        'gradeLevel': c.gradeLevel,
      };

  Future<void> addStudent(ClassRoom c, {required String name, required String number}) =>
      _students.add({
        ..._studentData(c, name, number),
        'questProgress': 0,
        'missingCount': 0,
        'absences': 0,
        'lateCount': 0,
        'fcmTokens': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Rename, renumber, or move to another class.
  Future<void> updateStudent(Student s, ClassRoom c, {required String name, required String number}) =>
      _students.doc(s.id).update(_studentData(c, name, number));

  Future<void> deleteStudent(String studentId) => _students.doc(studentId).delete();

  /// Adds many students at once (CSV import). Batches of 400 writes.
  Future<void> importStudents(ClassRoom c, List<({String name, String number})> rows) async {
    for (var i = 0; i < rows.length; i += 400) {
      final batch = _db.batch();
      for (final r in rows.skip(i).take(400)) {
        batch.set(_students.doc(), {
          ..._studentData(c, r.name, r.number),
          'questProgress': 0,
          'missingCount': 0,
          'absences': 0,
          'lateCount': 0,
          'fcmTokens': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
