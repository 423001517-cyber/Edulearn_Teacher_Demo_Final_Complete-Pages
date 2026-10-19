import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// Messages page: conversations with students and class groups.
class MessagesRepository {
  MessagesRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Json> get _conversations => _db.collection('conversations');
  CollectionReference<Json> _messages(String conversationId) =>
      _conversations.doc(conversationId).collection('messages');

  /// Every conversation, newest activity first.
  Stream<List<Conversation>> watchConversations() => _conversations
      .where('teacherId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Conversation.fromDoc).toList()
        ..sort((a, b) {
          final at = a.lastMessageAt ?? a.createdAt ?? DateTime(2000);
          final bt = b.lastMessageAt ?? b.createdAt ?? DateTime(2000);
          return bt.compareTo(at);
        }));

  /// The last 200 messages, oldest first.
  Stream<List<ChatMessage>> watchMessages(String conversationId) => _messages(conversationId)
      .orderBy('createdAt')
      .limitToLast(200)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  /// Opens (creating if needed) the one-to-one chat with [student].
  Future<String> ensureDirect(Student student) async {
    final id = Conversation.directId(uid, student.id);
    final ref = _conversations.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'teacherId': uid,
        'classId': student.classId,
        'kind': ConversationKind.student.name,
        'studentId': student.id,
        'title': student.name,
        'lastMessage': '',
        'lastMessageAt': null,
        'lastRole': MessageRole.teacher.name,
        'lastAuthor': '',
        'unread': 0,
        'studentsCanReply': true,
        'quietHours': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return id;
  }

  /// Opens (creating if needed) the whole-class group chat.
  Future<String> ensureGroup(ClassRoom c) async {
    final id = Conversation.groupId(c.id);
    final ref = _conversations.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'teacherId': uid,
        'classId': c.id,
        'kind': ConversationKind.group.name,
        'studentId': null,
        'title': c.name,
        'lastMessage': '',
        'lastMessageAt': null,
        'lastRole': MessageRole.teacher.name,
        'lastAuthor': '',
        'unread': 0,
        'studentsCanReply': true,
        'quietHours': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return id;
  }

  /// Adds the teacher's message and updates the conversation preview.
  Future<void> send(
    Conversation c, {
    required String authorName,
    String body = '',
    PostAttachment? attachment,
    ClassworkItem? classwork,
  }) async {
    final text = body.trim();
    final batch = _db.batch();
    final msg = ChatMessage(
      id: '',
      authorId: uid,
      authorName: authorName,
      role: MessageRole.teacher,
      body: text,
      attachment: attachment,
      classworkId: classwork?.id,
      classworkTitle: classwork?.title,
    );
    batch.set(_messages(c.id).doc(), {
      'authorId': uid,
      'authorName': authorName,
      'authorRole': MessageRole.teacher.name,
      'body': text,
      'attachment': attachment?.toMap(),
      'classworkId': classwork?.id,
      'classworkTitle': classwork?.title,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final preview = msg.previewText;
    batch.update(_conversations.doc(c.id), {
      'lastMessage': preview.length > 140 ? '${preview.substring(0, 140)}…' : preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastRole': MessageRole.teacher.name,
      'lastAuthor': firstNameOf(authorName),
    });
    await batch.commit();
  }

  Future<void> markRead(Conversation c) async {
    if (c.unread == 0) return;
    await _conversations.doc(c.id).update({'unread': 0});
  }

  Future<void> updateGroup(Conversation c, {bool? studentsCanReply, bool? quietHours}) =>
      _conversations.doc(c.id).update({
        if (studentsCanReply != null) 'studentsCanReply': studentsCanReply,
        if (quietHours != null) 'quietHours': quietHours,
      });
}
