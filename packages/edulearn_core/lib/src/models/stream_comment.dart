import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';
import 'post_attachment.dart';

/// `announcements/{id}/comments/{commentId}` or
/// `classwork/{id}/comments/{commentId}` — "Class comments".
class StreamComment {
  const StreamComment({
    this.id = '',
    required this.authorId,
    required this.authorName,
    this.authorRole = 'student',
    this.body = '',
    this.createdAt,
    this.attachment,
  });

  final String id;
  final String authorId;
  final String authorName;

  /// "teacher" or "student".
  final String authorRole;
  final String body;
  final DateTime? createdAt;
  final PostAttachment? attachment;

  bool get isTeacher => authorRole == 'teacher';

  factory StreamComment.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return StreamComment(
      id: doc.id,
      authorId: readString(d['authorId']),
      authorName: readString(d['authorName'], 'Student'),
      authorRole: readString(d['authorRole'], 'student'),
      body: readString(d['body']),
      createdAt: readDate(d['createdAt']),
      attachment: d['attachment'] == null ? null : PostAttachment.fromMap(d['attachment']),
    );
  }

  Json toNewMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'body': body,
        'attachment': attachment?.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
