import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// The Submissions module: one item's hand-ins, grading, returning,
/// removing, reminders.
class SubmissionsRepository {
  SubmissionsRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Json> get _submissions => _db.collection('submissions');

  Stream<List<Submission>> watchForItem(String classworkId) => _submissions
      .where('teacherId', isEqualTo: uid)
      .where('classworkId', isEqualTo: classworkId)
      .snapshots()
      .map((s) => s.docs.map(Submission.fromDoc).toList());

  /// "Save draft": keeps the score and feedback without returning the work.
  Future<void> saveDraft(Submission s, {int? score, required String feedback, Map<String, int> rubric = const {}}) =>
      _submissions.doc(s.id).update({
        'score': score,
        'privateFeedback': feedback,
        'rubricScores': rubric,
        'status': SubmissionStatus.pending.name,
      });

  /// "Return": the student sees the score and feedback.
  Future<void> returnWork(
    Submission s, {
    int? score,
    required String feedback,
    Map<String, int> rubric = const {},
    bool notifyStudent = true,
  }) =>
      _submissions.doc(s.id).update({
        'score': score,
        'privateFeedback': feedback,
        'rubricScores': rubric,
        'notifyStudent': notifyStudent,
        'status': SubmissionStatus.returned.name,
        'returnedAt': FieldValue.serverTimestamp(),
      });

  /// "Return selected" / "Mark all as reviewed": returns as-is.
  Future<int> returnMany(Iterable<Submission> list) async {
    final pending = list.where((s) => s.status == SubmissionStatus.pending).toList();
    for (var i = 0; i < pending.length; i += 400) {
      final batch = _db.batch();
      for (final s in pending.skip(i).take(400)) {
        batch.update(_submissions.doc(s.id), {
          'status': SubmissionStatus.returned.name,
          'returnedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    return pending.length;
  }

  /// "Edit score" on returned or pending work (keeps the current status).
  Future<void> editScore(Submission s, int score) => _submissions.doc(s.id).update({'score': score});

  /// "Remove submission": the student has to hand it in again.
  Future<void> remove(Submission s) => _submissions.doc(s.id).delete();
}
