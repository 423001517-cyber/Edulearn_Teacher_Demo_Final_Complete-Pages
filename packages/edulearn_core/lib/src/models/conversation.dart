import 'model_utils.dart';
import 'post_attachment.dart';

enum ConversationKind {
  /// Teacher and one student.
  student,

  /// Teacher and a whole class.
  group;

  static ConversationKind parse(Object? v) =>
      v == ConversationKind.group.name ? ConversationKind.group : ConversationKind.student;
}

enum MessageRole {
  teacher,
  student;

  static MessageRole parse(Object? v) =>
      v == MessageRole.student.name ? MessageRole.student : MessageRole.teacher;
}

/// `conversations/{id}` — a chat between a teacher and a student, or a
/// teacher and a whole class. The student app adds student messages; the
/// `onConversationMessage` function keeps `lastMessage` and `unread` current.
class Conversation {
  const Conversation({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.kind,
    required this.title,
    this.studentId,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastRole = MessageRole.teacher,
    this.lastAuthor = '',
    this.unread = 0,
    this.studentsCanReply = true,
    this.quietHours = true,
    this.createdAt,
  });

  final String id;
  final String teacherId;
  final String classId;
  final ConversationKind kind;

  /// Student name, or class name for a group.
  final String title;
  final String? studentId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final MessageRole lastRole;

  /// First name of whoever wrote the last group message.
  final String lastAuthor;

  /// Student messages the teacher hasn't opened yet.
  final int unread;

  /// Groups only: students may reply (otherwise announcements only).
  final bool studentsCanReply;

  /// Students can't send messages from 8 PM to 6 AM.
  final bool quietHours;
  final DateTime? createdAt;

  bool get isGroup => kind == ConversationKind.group;

  /// One chat per teacher and student, so "Message" always opens the same one.
  static String directId(String teacherId, String studentId) => 'dm_${teacherId}_$studentId';

  /// One class group per class.
  static String groupId(String classId) => 'class_$classId';

  factory Conversation.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return Conversation(
      id: doc.id,
      teacherId: readString(d['teacherId']),
      classId: readString(d['classId']),
      kind: ConversationKind.parse(d['kind']),
      title: readString(d['title'], 'Conversation'),
      studentId: readStringOrNull(d['studentId']),
      lastMessage: readString(d['lastMessage']),
      lastMessageAt: readDate(d['lastMessageAt']),
      lastRole: MessageRole.parse(d['lastRole']),
      lastAuthor: readString(d['lastAuthor']),
      unread: readInt(d['unread']),
      studentsCanReply: d['studentsCanReply'] != false,
      quietHours: d['quietHours'] != false,
      createdAt: readDate(d['createdAt']),
    );
  }

  /// "You: …", "Ana: …" or just the text.
  String get preview {
    if (lastMessage.isEmpty) return 'No messages yet';
    if (lastRole == MessageRole.teacher) return 'You: $lastMessage';
    if (isGroup && lastAuthor.isNotEmpty) return '$lastAuthor: $lastMessage';
    return lastMessage;
  }
}

/// `conversations/{id}/messages/{messageId}`
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.role,
    required this.body,
    this.createdAt,
    this.attachment,
    this.classworkId,
    this.classworkTitle,
  });

  final String id;
  final String authorId;
  final String authorName;
  final MessageRole role;
  final String body;

  /// null while the server timestamp is pending.
  final DateTime? createdAt;
  final PostAttachment? attachment;

  /// "Link classwork": opens that item on the Classwork page.
  final String? classworkId;
  final String? classworkTitle;

  bool get fromTeacher => role == MessageRole.teacher;

  factory ChatMessage.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return ChatMessage(
      id: doc.id,
      authorId: readString(d['authorId']),
      authorName: readString(d['authorName'], 'Student'),
      role: MessageRole.parse(d['authorRole']),
      body: readString(d['body']),
      createdAt: readDate(d['createdAt']),
      attachment: d['attachment'] is Map ? PostAttachment.fromMap(d['attachment']) : null,
      classworkId: readStringOrNull(d['classworkId']),
      classworkTitle: readStringOrNull(d['classworkTitle']),
    );
  }

  /// The text shown in the conversation list for this message.
  String get previewText {
    if (body.trim().isNotEmpty) return body.trim();
    if (attachment != null) return 'Sent a file: ${attachment!.name}';
    if (classworkTitle != null) return 'Shared: $classworkTitle';
    return '';
  }
}
