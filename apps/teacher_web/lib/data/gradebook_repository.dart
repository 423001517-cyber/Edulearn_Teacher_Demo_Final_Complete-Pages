import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// What the teacher picked in the grade-cell editor.
enum GradeEntry { graded, draft, missing }

/// Gradebook: settings, every submission of a class, grade entry.
class GradebookRepository {
  GradebookRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Json> get _submissions => _db.collection('submissions');

  DocumentReference<Json> _settings(String classId) =>
      _db.collection('classes').doc(classId).collection('gradebook').doc('settings');

  Stream<GradebookSettings> watchSettings(String classId) =>
      _settings(classId).snapshots().map((d) => GradebookSettings.fromMap(d.data()));

  Future<void> saveSettings(String classId, GradebookSettings s) => _settings(classId).set(s.toMap());

  Stream<List<Submission>> watchClassSubmissions(String classId) => _submissions
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((s) => s.docs.map(Submission.fromDoc).toList());

  /// Saves a grade from the grid. Missing removes the submission; a grade
  /// for someone with no submission creates one marked `source: teacher`
  /// (work handed in on paper).
  Future<void> setGrade({
    required ClassworkItem item,
    required Student student,
    required Submission? existing,
    required GradeEntry entry,
    int? score,
    String feedback = '',
  }) async {
    if (entry == GradeEntry.missing) {
      if (existing != null) await _submissions.doc(existing.id).delete();
      return;
    }
    final status = entry == GradeEntry.graded ? SubmissionStatus.returned : SubmissionStatus.pending;
    if (existing != null) {
      await _submissions.doc(existing.id).update({
        'score': score,
        'privateFeedback': feedback,
        'status': status.name,
        if (status == SubmissionStatus.returned) 'returnedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await _submissions.add({
      'teacherId': uid,
      'source': 'teacher',
      'classId': item.classId,
      'studentId': student.id,
      'studentName': student.name,
      'gradeLevel': student.gradeLevel,
      'classworkId': item.id,
      'classworkTitle': item.title,
      'classworkType': item.type.name,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': status.name,
      'score': score,
      'maxScore': item.points,
      'privateFeedback': feedback,
      if (status == SubmissionStatus.returned) 'returnedAt': FieldValue.serverTimestamp(),
    });
  }

  /// "Show overall grade to students" lives on the class.
  Future<void> setShowOverallGrade(String classId, bool show) =>
      _db.collection('classes').doc(classId).update({'showOverallGrade': show});

  /// Column menu → "Edit points and due date".
  Future<void> updatePointsAndDue(ClassworkItem item, {required int points, required DateTime dueDate}) =>
      _db.collection('classwork').doc(item.id).update({'points': points, 'dueDate': Timestamp.fromDate(dueDate)});
}
