import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Reads and writes for the Classes module (list, detail page, archive,
/// Edit class details, Class settings).
class ClassesRepository {
  ClassesRepository(this._db, this._storage, this._functions, this.uid);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final String uid;

  DocumentReference<Json> _class(String id) => _db.collection('classes').doc(id);

  /// Every classwork item in one class, newest due date first.
  Stream<List<ClassworkItem>> watchClassClasswork(String classId) => _db
      .collection('classwork')
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .orderBy('dueDate', descending: true)
      .limit(150)
      .snapshots()
      .map((s) => s.docs.map(ClassworkItem.fromDoc).toList());

  Stream<List<ActivityEntry>> watchActivity(String classId) => _db
      .collection('activity')
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(ActivityEntry.fromDoc).toList());

  /// Students and teachers stop seeing it under Active Classes; lessons,
  /// submissions, grades and reports are kept.
  Future<void> archiveClass(String classId) => _class(classId).update({
        'status': ClassStatus.archived.name,
        'archivedAt': FieldValue.serverTimestamp(),
      });

  Future<void> restoreClass(String classId) => _class(classId).update({
        'status': ClassStatus.active.name,
        'archivedAt': null,
      });

  /// "Edit class details": cover, subject, room and description. (Grade,
  /// section and the class code are official — set by the administrator.)
  Future<void> updateClassDetails(
    String classId, {
    required String subject,
    required String room,
    required String description,
    Uint8List? coverBytes,
    String? coverFileName,
  }) async {
    final update = <String, dynamic>{
      'subject': subject.trim(),
      'room': room.trim(),
      'description': description.trim(),
    };
    if (coverBytes != null) {
      final ext = (coverFileName ?? 'cover.jpg').split('.').last.toLowerCase();
      final ref = _storage.ref('class-covers/$uid/$classId.$ext');
      await ref.putData(
        coverBytes,
        SettableMetadata(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'),
      );
      update['coverImageUrl'] = await ref.getDownloadURL();
    }
    await _class(classId).update(update);
  }

  /// The "Class settings" page.
  Future<void> saveClassSettings(
    String classId, {
    required String subject,
    required String room,
    required StreamPermission streamPermission,
    required ClassworkNotices classworkNotices,
    required int totalPoints,
    required bool showOverallGrade,
  }) =>
      _class(classId).update({
        'subject': subject.trim(),
        'room': room.trim(),
        'streamPermission': streamPermission.name,
        'classworkNotifications': classworkNotices.name,
        'totalPoints': totalPoints,
        'showOverallGrade': showOverallGrade,
      });

  /// "Reset code": issues a new official class code (old one stops working
  /// for new students). Returns the new code.
  Future<String> resetClassCode(String classId) async {
    try {
      final r = await _functions.httpsCallable('regenerateClassCode').call<Object?>({'classId': classId});
      final data = r.data;
      return data is Map ? '${data['classCode'] ?? ''}' : '';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Could not reset the code (${e.code}).');
    }
  }

  /// Official classes and class codes come from the administrator, so a
  /// teacher files a request instead of creating a class directly.
  Future<void> requestNewClass({
    required int gradeLevel,
    required String section,
    required String subject,
    String note = '',
  }) =>
      _db.collection('classRequests').add({
        'teacherId': uid,
        'gradeLevel': gradeLevel,
        'section': section.trim(),
        'subject': subject.trim(),
        'note': note.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
}
