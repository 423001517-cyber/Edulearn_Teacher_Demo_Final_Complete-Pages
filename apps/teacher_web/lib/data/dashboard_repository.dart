import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// Every Firestore read/write the teacher dashboard makes.
///
/// All queries are scoped by `teacherId == uid`, which is exactly what the
/// security rules require. Class filtering ("Grade 4 – Rizal" vs "All
/// Classes") happens client-side, so switching classes is instant and needs
/// no extra composite indexes.
class DashboardRepository {
  DashboardRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Json> get _classes => _db.collection('classes');
  CollectionReference<Json> get _students => _db.collection('students');
  CollectionReference<Json> get _classwork => _db.collection('classwork');
  CollectionReference<Json> get _submissions => _db.collection('submissions');
  CollectionReference<Json> get _announcements => _db.collection('announcements');
  CollectionReference<Json> get _reminders => _db.collection('reminders');
  CollectionReference<Json> get _notifications =>
      _db.collection('teachers').doc(uid).collection('notifications');

  Query<Json> _mine(CollectionReference<Json> c) => c.where('teacherId', isEqualTo: uid);

  // ---------------------------------------------------------------- reads

  Stream<Teacher?> watchTeacher() => _db
      .collection('teachers')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Teacher.fromDoc(d) : null);

  Stream<List<ClassRoom>> watchClasses() => _mine(_classes)
      .orderBy('gradeLevel')
      .snapshots()
      .map((s) => s.docs.map(ClassRoom.fromDoc).toList());

  Stream<List<Student>> watchStudents() => _mine(_students)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Student.fromDoc).toList());

  /// Everything due from [from] onward (this week's work + upcoming).
  Stream<List<ClassworkItem>> watchClassworkFrom(DateTime from) => _mine(_classwork)
      .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .orderBy('dueDate')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(ClassworkItem.fromDoc).toList());

  /// Recently created items — the source list for "Reuse Activity".
  Stream<List<ClassworkItem>> watchRecentClasswork() => _mine(_classwork)
      .orderBy('createdAt', descending: true)
      .limit(40)
      .snapshots()
      .map((s) => s.docs.map(ClassworkItem.fromDoc).toList());

  Stream<List<Submission>> watchPendingSubmissions() => _mine(_submissions)
      .where('status', isEqualTo: SubmissionStatus.pending.name)
      .orderBy('submittedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Submission.fromDoc).toList());

  Stream<List<Submission>> watchStudentSubmissions(String studentId) => _mine(_submissions)
      .where('studentId', isEqualTo: studentId)
      .orderBy('submittedAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(Submission.fromDoc).toList());

  Stream<List<Announcement>> watchAnnouncements() => _mine(_announcements)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());

  Stream<List<AppNotification>> watchNotifications() => _notifications
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  Future<List<PerformancePoint>> fetchPerformance(
    String classId,
    DateTime start,
    DateTime endExclusive,
  ) async {
    final snap = await _classes
        .doc(classId)
        .collection('dailyPerformance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('date')
        .get();
    return snap.docs.map(PerformancePoint.fromDoc).toList();
  }

  // --------------------------------------------------------------- writes

  Future<void> saveClasswork(ClassworkItem item) async {
    final data = <String, dynamic>{...item.toMap(), 'teacherId': uid};
    if (item.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _classwork.add(data);
    } else {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _classwork.doc(item.id).update(data);
    }
  }

  Future<void> deleteClasswork(String id) => _classwork.doc(id).delete();

  /// "Reuse Activity": copies an item into another class as a draft.
  Future<void> duplicateClasswork(
    ClassworkItem source, {
    required ClassRoom target,
    required DateTime dueDate,
  }) =>
      saveClasswork(source.copyWith(
        id: '',
        classId: target.id,
        className: target.name,
        dueDate: dueDate,
        status: ClassworkStatus.draft,
        assignedStudentIds: const [],
      ));

  Future<void> returnSubmission(
    String submissionId, {
    required int? score,
    required String feedback,
  }) =>
      _submissions.doc(submissionId).update({
        'score': score,
        'privateFeedback': feedback,
        'status': SubmissionStatus.returned.name,
        'returnedAt': FieldValue.serverTimestamp(),
      });

  Future<void> saveAnnouncement(Announcement a) async {
    final data = <String, dynamic>{...a.toMap(), 'teacherId': uid};
    if (a.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _announcements.add(data);
    } else {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _announcements.doc(a.id).update(data);
    }
  }

  Future<void> setAnnouncementPinned(String id, bool pinned) =>
      _announcements.doc(id).update({'pinned': pinned});

  Future<void> deleteAnnouncement(String id) => _announcements.doc(id).delete();

  Future<void> markNotificationRead(String id, {bool read = true}) =>
      _notifications.doc(id).update({'read': read});

  Future<void> markAllNotificationsRead(Iterable<AppNotification> items) async {
    final unread = items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final n in unread) {
      batch.update(_notifications.doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String id) => _notifications.doc(id).delete();

  /// Queued here; the `deliverReminder` Cloud Function pushes it to the
  /// student's devices via FCM.
  Future<void> sendReminder({
    required String studentId,
    required String classId,
    required String message,
    String? classworkId,
  }) =>
      _reminders.add({
        'teacherId': uid,
        'studentId': studentId,
        'classId': classId,
        'classworkId': classworkId,
        'message': message,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> sendReminderTo(Student student, String message) =>
      sendReminder(studentId: student.id, classId: student.classId, message: message);
}
