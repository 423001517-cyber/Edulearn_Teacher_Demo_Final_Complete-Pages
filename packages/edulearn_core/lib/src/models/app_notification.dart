import 'model_utils.dart';

enum NotificationKind {
  submissions,
  missingWork,
  schedule,
  message,
  reward,
  general;

  static NotificationKind parse(Object? v) => NotificationKind.values
      .firstWhere((k) => k.name == v, orElse: () => NotificationKind.general);
}

/// `teachers/{uid}/notifications/{id}` — written by Cloud Functions.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final NotificationKind kind;
  final DateTime createdAt;
  final bool read;

  factory AppNotification.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return AppNotification(
      id: doc.id,
      title: readString(d['title']),
      kind: NotificationKind.parse(d['kind']),
      createdAt: readDate(d['createdAt']) ?? DateTime.now(),
      read: d['read'] == true,
    );
  }
}
