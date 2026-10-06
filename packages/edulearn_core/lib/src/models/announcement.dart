import 'package:cloud_firestore/cloud_firestore.dart';

import '../stream/post_format.dart';
import 'model_utils.dart';
import 'post_attachment.dart';

enum PostStatus {
  published('Posted'),
  scheduled('Scheduled'),
  draft('Draft');

  const PostStatus(this.label);
  final String label;

  static PostStatus parse(Object? v) =>
      PostStatus.values.firstWhere((s) => s.name == v, orElse: () => PostStatus.published);
}

/// `announcements/{id}` — a teacher's post in the class stream.
/// `classId == null` means "all my classes". Comments live in
/// `announcements/{id}/comments`; `commentCount` is kept by a Cloud Function.
class Announcement {
  const Announcement({
    this.id = '',
    this.classId,
    this.title = '',
    this.body = '',
    this.createdAt,
    this.pinned = false,
    this.status = PostStatus.published,
    this.publishAt,
    this.attachments = const [],
    this.commentCount = 0,
  });

  final String id;
  final String? classId;

  /// Bold first line in the stream ("Welcome to Quarter 1!"). May be empty.
  final String title;

  /// Text with light formatting: **bold**, *italic*, __underline__,
  /// "• " bullet lines and [links](https://…).
  final String body;
  final DateTime? createdAt;
  final bool pinned;
  final PostStatus status;

  /// When a scheduled post goes live.
  final DateTime? publishAt;
  final List<PostAttachment> attachments;
  final int commentCount;

  factory Announcement.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return Announcement(
      id: doc.id,
      classId: readStringOrNull(d['classId']),
      title: readString(d['title']),
      body: readString(d['body']),
      createdAt: readDate(d['createdAt']),
      pinned: d['pinned'] == true,
      status: PostStatus.parse(d['status']),
      publishAt: readDate(d['publishAt']),
      attachments: PostAttachment.listFrom(d['attachments']),
      commentCount: readInt(d['commentCount']),
    );
  }

  Json toMap() => {
        'classId': classId,
        'title': title,
        'body': body,
        'pinned': pinned,
        'status': status.name,
        'publishAt': publishAt == null ? null : Timestamp.fromDate(publishAt!),
        'attachments': [for (final a in attachments) a.toMap()],
      };

  Announcement copyWith({
    String? id,
    String? classId,
    bool clearClass = false,
    String? title,
    String? body,
    bool? pinned,
    PostStatus? status,
    DateTime? publishAt,
    bool clearPublishAt = false,
    List<PostAttachment>? attachments,
  }) =>
      Announcement(
        id: id ?? this.id,
        classId: clearClass ? null : (classId ?? this.classId),
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt,
        pinned: pinned ?? this.pinned,
        status: status ?? this.status,
        publishAt: clearPublishAt ? null : (publishAt ?? this.publishAt),
        attachments: attachments ?? this.attachments,
        commentCount: commentCount,
      );

  /// Students can see it: posted, or scheduled and its time has come
  /// (the publishScheduledPosts function then flips the status).
  bool isLive(DateTime now) =>
      status == PostStatus.published ||
      (status == PostStatus.scheduled && publishAt != null && !publishAt!.isAfter(now));

  /// The date shown on the post and used to order the stream.
  DateTime? get postedAt => status == PostStatus.scheduled ? publishAt : createdAt;

  /// Title, or the first line of the body when there's no title.
  String get headline {
    if (title.isNotEmpty) return title;
    final first = plainText(body).split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return first.isEmpty ? (attachments.isEmpty ? 'Announcement' : attachments.first.name) : first.trim();
  }

  /// Body without formatting marks (one-line previews).
  String get plainBody => plainText(body);
}
