import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum PostKind { announcement, classwork }

/// Points at a post in the class stream: an announcement or a classwork item
/// (both can have class comments).
class PostRef {
  const PostRef(this.kind, this.id);

  final PostKind kind;
  final String id;

  String get collection => kind == PostKind.announcement ? 'announcements' : 'classwork';

  /// For links: `a:{id}` (announcement) or `c:{id}` (classwork).
  String encode() => '${kind == PostKind.announcement ? 'a' : 'c'}:$id';

  static PostRef? decode(String? v) {
    if (v == null || v.length < 3 || v[1] != ':') return null;
    final id = v.substring(2);
    return switch (v[0]) {
      'a' => PostRef(PostKind.announcement, id),
      'c' => PostRef(PostKind.classwork, id),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) => other is PostRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Stream posts (`announcements`), class comments and their attachments.
class StreamRepository {
  StreamRepository(this._db, this._storage, this.uid);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final String uid;

  static const maxBytes = 25 * 1024 * 1024; // keep in sync with storage.rules

  CollectionReference<Json> get _posts => _db.collection('announcements');

  CollectionReference<Json> _comments(PostRef p) =>
      _db.collection(p.collection).doc(p.id).collection('comments');

  /// Posts in one class, including drafts and scheduled posts.
  Stream<List<Announcement>> watchClassPosts(String classId) => _posts
      .where('teacherId', isEqualTo: uid)
      .where('classId', isEqualTo: classId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());

  /// Posts sent to "all my classes" (they appear in every class stream).
  Stream<List<Announcement>> watchAllClassesPosts() => _posts
      .where('teacherId', isEqualTo: uid)
      .where('classId', isNull: true)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());

  /// Creates or updates a post. Publishing a draft/scheduled post now also
  /// resets `createdAt`, so it lands at the top of the stream.
  Future<String> savePost(Announcement a, {bool bumpDate = false}) async {
    final data = <String, dynamic>{...a.toMap(), 'teacherId': uid};
    if (a.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final doc = await _posts.add(data);
      return doc.id;
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (bumpDate) data['createdAt'] = FieldValue.serverTimestamp();
    await _posts.doc(a.id).update(data);
    return a.id;
  }

  Future<void> publishNow(Announcement a) => _posts.doc(a.id).update({
        'status': PostStatus.published.name,
        'publishAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setPinned(String id, bool pinned) => _posts.doc(id).update({'pinned': pinned});

  /// Deletes the post, its class comments and its uploaded files.
  Future<void> deletePost(Announcement a) async {
    final ref = PostRef(PostKind.announcement, a.id);
    final comments = await _comments(ref).get();
    final batch = _db.batch();
    for (final c in comments.docs) {
      batch.delete(c.reference);
    }
    batch.delete(_posts.doc(a.id));
    await batch.commit();
    for (final file in a.attachments) {
      await deleteFile(file);
    }
    for (final c in comments.docs) {
      final att = StreamComment.fromDoc(c).attachment;
      if (att != null) await deleteFile(att);
    }
  }

  // ---- class comments
  Stream<List<StreamComment>> watchComments(PostRef p) => _comments(p)
      .orderBy('createdAt')
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(StreamComment.fromDoc).toList());

  Future<void> addComment(PostRef p, StreamComment c) => _comments(p).add(c.toNewMap());

  Future<void> deleteComment(PostRef p, StreamComment c) async {
    await _comments(p).doc(c.id).delete();
    if (c.attachment != null) await deleteFile(c.attachment!);
  }

  // ---- attachments
  Future<PostAttachment> uploadFile({required String fileName, required Uint8List bytes}) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'stream/$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: _contentType(safeName)));
    return PostAttachment(
      name: fileName,
      url: await ref.getDownloadURL(),
      kind: AttachmentKind.file,
      sizeBytes: bytes.length,
      storagePath: path,
    );
  }

  /// Best effort: a missing file isn't an error.
  Future<void> deleteFile(PostAttachment a) async {
    final path = a.storagePath;
    if (path == null || !path.startsWith('stream/$uid/')) return;
    try {
      await _storage.ref(path).delete();
    } catch (_) {}
  }

  static String _contentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'mp3' => 'audio/mpeg',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }
}
