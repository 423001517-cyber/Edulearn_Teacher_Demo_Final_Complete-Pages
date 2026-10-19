import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// Rewards page: per-class settings (rules, badges, shop), points given by
/// the teacher, and reward requests from the student app.
class RewardsRepository {
  RewardsRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  DocumentReference<Json> _settings(String classId) =>
      _db.collection('classes').doc(classId).collection('rewards').doc('settings');
  CollectionReference<Json> get _awards => _db.collection('pointAwards');
  CollectionReference<Json> get _requests => _db.collection('rewardRequests');

  Stream<RewardSettings> watchSettings(String classId) =>
      _settings(classId).snapshots().map((d) => RewardSettings.fromMap(d.data()));

  Future<void> saveSettings(String classId, RewardSettings s) => _settings(classId).set(s.toMap());

  /// Newest first (sorted here, so no composite index is needed).
  Stream<List<PointAward>> watchAwards(String classId) => _awards
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((s) => s.docs.map(PointAward.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())));

  /// "Give points": one award per student. Written ten at a time so each
  /// write stays well inside the security rules' per-request lookup limit.
  Future<void> giveAward({
    required String classId,
    required List<Student> students,
    required int points,
    String reason = '',
    String? badgeId,
  }) async {
    for (var i = 0; i < students.length; i += 10) {
      final batch = _db.batch();
      for (final s in students.skip(i).take(10)) {
        batch.set(_awards.doc(), {
          'teacherId': uid,
          'classId': classId,
          'studentId': s.id,
          'studentName': s.name,
          'points': points,
          'reason': reason.trim(),
          'badgeId': badgeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> deleteAward(String id) => _awards.doc(id).delete();

  Stream<List<RewardRequest>> watchRequests(String classId) => _requests
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((s) => s.docs.map(RewardRequest.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())));

  Future<void> decide(RewardRequest r, {required bool approve}) => _requests.doc(r.id).update({
        'status': approve ? RewardStatus.approved.name : RewardStatus.declined.name,
        'decidedAt': FieldValue.serverTimestamp(),
      });
}
