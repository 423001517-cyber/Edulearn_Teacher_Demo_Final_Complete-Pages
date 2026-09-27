import 'model_utils.dart';

/// `announcements/{id}` — `classId == null` means "all my classes".
class Announcement {
  const Announcement({
    this.id = '',
    this.classId,
    required this.title,
    this.body = '',
    this.createdAt,
    this.pinned = false,
  });

  final String id;
  final String? classId;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool pinned;

  factory Announcement.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return Announcement(
      id: doc.id,
      classId: readStringOrNull(d['classId']),
      title: readString(d['title'], 'Announcement'),
      body: readString(d['body']),
      createdAt: readDate(d['createdAt']),
      pinned: d['pinned'] == true,
    );
  }

  Json toMap() => {
        'classId': classId,
        'title': title,
        'body': body,
        'pinned': pinned,
      };
}
