import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

final conversationsProvider = StreamProvider.autoDispose<List<Conversation>>(
  (ref) => ref.watch(messagesRepositoryProvider).watchConversations(),
);

final conversationMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>(
  (ref, id) => ref.watch(messagesRepositoryProvider).watchMessages(id),
);

/// Unread student messages across every conversation (sidebar badge).
final unreadMessageCountProvider = Provider.autoDispose<int>((ref) {
  var n = 0;
  for (final c in ref.watch(conversationsProvider).valueOrNull ?? const <Conversation>[]) {
    n += c.unread;
  }
  return n;
});
