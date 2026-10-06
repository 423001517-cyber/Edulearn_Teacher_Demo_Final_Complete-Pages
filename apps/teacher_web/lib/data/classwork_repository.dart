import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// The Classwork module: topics, items, quiz/boss answer keys, reuse.
class ClassworkRepository {
  ClassworkRepository(this._db, this._storage, this.uid);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final String uid;

  CollectionReference<Json> get _items => _db.collection('classwork');

  CollectionReference<Json> _topics(String classId) =>
      _db.collection('classes').doc(classId).collection('topics');

  DocumentReference<Json> _answerKey(String itemId) =>
      _items.doc(itemId).collection('private').doc('questions');

  // ---------------------------------------------------------------- topics
  Stream<List<ClassTopic>> watchTopics(String classId) => _topics(classId)
      .orderBy('position')
      .snapshots()
      .map((s) => s.docs.map(ClassTopic.fromDoc).toList());

  Future<String> createTopic(String classId, String name, double position) async {
    final doc = await _topics(classId).add(ClassTopic(name: name, position: position).toMap());
    return doc.id;
  }

  Future<void> renameTopic(String classId, String topicId, String name) =>
      _topics(classId).doc(topicId).update({'name': name.trim()});

  /// Move up / Move down: swap positions with the neighbour.
  Future<void> swapTopics(String classId, ClassTopic a, ClassTopic b) async {
    final batch = _db.batch();
    batch.update(_topics(classId).doc(a.id), {'position': b.position});
    batch.update(_topics(classId).doc(b.id), {'position': a.position});
    await batch.commit();
  }

  /// Deletes the topic; its classwork stays, under "No topic".
  Future<void> deleteTopic(String classId, String topicId) async {
    final items = await _items
        .where('teacherId', isEqualTo: uid)
        .where('classId', isEqualTo: classId)
        .where('topicId', isEqualTo: topicId)
        .get();
    final batch = _db.batch();
    for (final d in items.docs) {
      batch.update(d.reference, {'topicId': null});
    }
    batch.delete(_topics(classId).doc(topicId));
    await batch.commit();
  }

  // ---------------------------------------------------------------- items
  Stream<ClassworkItem?> watchItem(String id) =>
      _items.doc(id).snapshots().map((d) => d.exists ? ClassworkItem.fromDoc(d) : null);

  /// Creates or updates an item; with [questions] (quiz / boss) the answer
  /// key is saved in the same batch. Returns the item id.
  Future<String> save(ClassworkItem item, {List<QuizQuestion>? questions}) async {
    final ref = item.id.isEmpty ? _items.doc() : _items.doc(item.id);
    final data = <String, dynamic>{
      ...item.toMap(),
      'teacherId': uid,
      if (questions != null) 'questionCount': questions.length,
    };
    final batch = _db.batch();
    if (item.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      batch.set(ref, data);
    } else {
      data['updatedAt'] = FieldValue.serverTimestamp();
      batch.update(ref, data);
    }
    if (questions != null) {
      batch.set(_answerKey(ref.id), {'questions': [for (final q in questions) q.toMap()]});
    }
    await batch.commit();
    return ref.id;
  }

  Future<List<QuizQuestion>> loadQuestions(String itemId) async {
    if (itemId.isEmpty) return const [];
    final snap = await _answerKey(itemId).get();
    final raw = snap.data()?['questions'];
    return raw is List ? raw.map(QuizQuestion.fromMap).toList() : const [];
  }

  Future<void> setStatus(ClassworkItem item, ClassworkStatus status) => _items.doc(item.id).update({
        'status': status.name,
        if (status != ClassworkStatus.scheduled) 'publishAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> moveToTopic(ClassworkItem item, String? topicId, {double? position}) =>
      _items.doc(item.id).update({
        'topicId': topicId,
        'position': position ?? DateTime.now().millisecondsSinceEpoch / 1000,
      });

  /// Saves a new order after a drag (positions 1, 2, 3…).
  Future<void> reorder(List<ClassworkItem> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].position != i + 1) batch.update(_items.doc(ordered[i].id), {'position': i + 1});
    }
    await batch.commit();
  }

  /// Deletes the item. The onClassworkWritten function then removes its
  /// submissions, missing-work rows, comments and answer key.
  Future<void> delete(ClassworkItem item) => _items.doc(item.id).delete();

  /// "Duplicate": a draft copy in the same class and topic.
  Future<String> duplicate(ClassworkItem item) async {
    final questions = item.type.hasQuestions ? await loadQuestions(item.id) : null;
    return save(
      item.copyWith(id: '', title: 'Copy of ${item.title}', status: ClassworkStatus.draft, clearPublishAt: true),
      questions: questions,
    );
  }

  /// "Reuse post": copies items from any of the teacher's classes into
  /// [target] as drafts (no topic). With [copyFiles], uploaded files are
  /// copied too, so deleting the original later won't break the copy.
  Future<int> reuse(
    List<ClassworkItem> items, {
    required ClassRoom target,
    required bool copyFiles,
  }) async {
    var copied = 0;
    for (final item in items) {
      final attachments = copyFiles
          ? [for (final a in item.attachments) await _copyFile(a)]
          : item.attachments;
      final questions = item.type.hasQuestions ? await loadQuestions(item.id) : null;
      await save(
        item.copyWith(
          id: '',
          classId: target.id,
          className: target.name,
          status: ClassworkStatus.draft,
          clearTopic: true,
          clearPublishAt: true,
          attachments: attachments,
          assignedStudentIds: const [],
        ),
        questions: questions,
      );
      copied++;
    }
    return copied;
  }

  Future<PostAttachment> _copyFile(PostAttachment a) async {
    final path = a.storagePath;
    if (path == null) return a; // links, videos, demo files
    final bytes = await _storage.ref(path).getData(30 * 1024 * 1024);
    if (bytes == null) return a;
    final copyPath = 'stream/$uid/${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
    final ref = _storage.ref(copyPath);
    await ref.putData(bytes);
    return PostAttachment(
      name: a.name,
      url: await ref.getDownloadURL(),
      kind: a.kind,
      sizeBytes: a.sizeBytes,
      storagePath: copyPath,
    );
  }
}
