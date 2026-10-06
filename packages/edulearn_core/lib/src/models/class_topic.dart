import 'model_utils.dart';

/// `classes/{classId}/topics/{topicId}` — "Week 1: Mga Rehiyon". Classwork
/// items point at a topic with `topicId`.
class ClassTopic {
  const ClassTopic({this.id = '', required this.name, this.position = 0});

  final String id;
  final String name;

  /// Order in the Topics list (Move up / Move down).
  final double position;

  factory ClassTopic.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return ClassTopic(
      id: doc.id,
      name: readString(d['name'], 'Untitled topic'),
      position: readDouble(d['position']),
    );
  }

  Json toMap() => {'name': name.trim(), 'position': position};
}
