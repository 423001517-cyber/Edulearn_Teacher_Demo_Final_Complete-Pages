import 'model_utils.dart';

enum ActivityKind {
  submitted,
  joined,
  announcement,
  completed,
  missed,
  published;

  static ActivityKind parse(Object? v) => ActivityKind.values
      .firstWhere((k) => k.name == v, orElse: () => ActivityKind.published);
}

/// `activity/{id}` — the "Recent Class Activity" feed, written by Cloud
/// Functions when students submit, join, or miss work.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.classId,
    required this.kind,
    required this.title,
    this.subtitle = '',
    required this.createdAt,
  });

  final String id;
  final String classId;
  final ActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime createdAt;

  factory ActivityEntry.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return ActivityEntry(
      id: doc.id,
      classId: readString(d['classId']),
      kind: ActivityKind.parse(d['kind']),
      title: readString(d['title']),
      subtitle: readString(d['subtitle']),
      createdAt: readDate(d['createdAt']) ?? DateTime.now(),
    );
  }
}
