import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/messages_providers.dart';
import '../shell/top_bar.dart';
import 'message_info.dart';
import 'message_thread.dart';
import 'messages_dialogs.dart';

enum _Tab {
  all('All'),
  unread('Unread'),
  groups('Classes');

  const _Tab(this.label);
  final String label;
}

/// `/messages?c=&student=&group=` — chats with students and class groups.
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key, this.conversationId, this.studentId, this.groupClassId});

  final String? conversationId;

  /// Open (or start) the chat with this student.
  final String? studentId;

  /// Open (or start) this class's group chat.
  final String? groupClassId;

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String? _selected;
  _Tab _tab = _Tab.all;
  String _query = '';

  /// "id:unread" last marked as read, so an open chat is marked once per new message.
  String? _markedFor;

  @override
  void initState() {
    super.initState();
    _selected = widget.conversationId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromLink());
  }

  @override
  void didUpdateWidget(MessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId && widget.conversationId != null) {
      setState(() => _selected = widget.conversationId);
    }
    if (oldWidget.studentId != widget.studentId || oldWidget.groupClassId != widget.groupClassId) {
      _openFromLink();
    }
  }

  /// ?student= / ?group= links from other pages start the chat if needed.
  Future<void> _openFromLink() async {
    final repo = ref.read(messagesRepositoryProvider);
    try {
      String? id;
      if (widget.studentId != null) {
        final students = await ref.read(studentsProvider.future);
        for (final s in students) {
          if (s.id == widget.studentId) id = await repo.ensureDirect(s);
        }
      } else if (widget.groupClassId != null) {
        final classes = await ref.read(classesProvider.future);
        for (final c in classes) {
          if (c.id == widget.groupClassId) id = await repo.ensureGroup(c);
        }
      }
      if (id != null && mounted) setState(() => _selected = id);
    } catch (e) {
      showToast('Couldn’t open the conversation: $e');
    }
  }

  void _select(Conversation c) {
    setState(() => _selected = c.id);
    ref.read(messagesRepositoryProvider).markRead(c);
  }

  Future<void> _newMessage() async {
    final student = await pickStudentDialog(context);
    if (student == null || !mounted) return;
    final id = await ref.read(messagesRepositoryProvider).ensureDirect(student);
    if (mounted) setState(() => _selected = id);
  }

  Future<void> _messageClass(ClassRoom c) async {
    final id = await ref.read(messagesRepositoryProvider).ensureGroup(c);
    if (mounted) setState(() => _selected = id);
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    // Keep the roster loaded for ?student= links and the New message picker.
    ref.watch(studentsProvider);

    return PageScaffold(
      header: PageHeader(
        icon: Icons.wb_sunny_rounded,
        title: 'Messages',
        subtitle: 'Chat with students and class groups, and answer questions quickly.',
        actions: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PopupMenuButton<ClassRoom>(
              tooltip: 'Message a whole class',
              position: PopupMenuPosition.under,
              onSelected: _messageClass,
              itemBuilder: (_) => [
                for (final c in classes) menuItem(c, Icons.groups_rounded, c.name),
              ],
              child: IgnorePointer(
                child: OutlinedButton.icon(
                  onPressed: classes.isEmpty ? null : () {},
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Message a class'),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _newMessage,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New message'),
            ),
          ],
        ),
      ),
      children: [
        AsyncValueView<List<Conversation>>(
          value: conversations,
          loadingHeight: 400,
          data: (all) => _layout(all),
        ),
      ],
    );
  }

  Widget _layout(List<Conversation> all) {
    final q = _query.trim().toLowerCase();
    final shown = all.where((c) {
      if (_tab == _Tab.unread && c.unread == 0) return false;
      if (_tab == _Tab.groups && !c.isGroup) return false;
      if (q.isNotEmpty && !'${c.title} ${c.lastMessage}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    Conversation? current;
    for (final c in all) {
      if (c.id == _selected) current = c;
    }
    final unread = all.fold<int>(0, (n, c) => n + c.unread);

    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      final showInfo = width >= 1150;
      final split = width >= 780;
      current ??= split && shown.isNotEmpty ? shown.first : null;
      final open = current;
      // The open chat is being read: clear its unread count.
      if (open != null && open.unread > 0 && _markedFor != '${open.id}:${open.unread}') {
        _markedFor = '${open.id}:${open.unread}';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(messagesRepositoryProvider).markRead(open);
        });
      }

      final list = _ConversationList(
        conversations: shown,
        selectedId: open?.id,
        tab: _tab,
        unread: unread,
        onTab: (t) => setState(() => _tab = t),
        onQuery: (v) => setState(() => _query = v),
        query: _query,
        onSelect: _select,
        empty: all.isEmpty,
      );

      final Widget thread = open == null
          ? const Center(
              child: EmptyNote('Choose a conversation, or start one with New message.',
                  icon: Icons.chat_bubble_outline_rounded),
            )
          : MessageThread(
              key: ValueKey(open.id),
              conversation: open,
              onBack: split ? null : () => setState(() => _selected = null),
            );

      return Container(
        height: split ? 720 : null,
        decoration: AppDecorations.card,
        clipBehavior: Clip.antiAlias,
        child: split
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: width >= 1000 ? 320 : 280, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(child: thread),
                  if (showInfo && open != null) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(width: 290, child: MessageInfoPane(conversation: open)),
                  ],
                ],
              )
            : SizedBox(height: 640, child: open == null ? list : thread),
      );
    });
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.selectedId,
    required this.tab,
    required this.unread,
    required this.onTab,
    required this.onQuery,
    required this.query,
    required this.onSelect,
    required this.empty,
  });

  final List<Conversation> conversations;
  final String? selectedId;
  final _Tab tab;
  final int unread;
  final ValueChanged<_Tab> onTab;
  final ValueChanged<String> onQuery;
  final String query;
  final ValueChanged<Conversation> onSelect;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(hint: 'Search messages', initialValue: query, onChanged: onQuery),
              const SizedBox(height: 10),
              SegmentedPills<_Tab>(
                value: tab,
                options: _Tab.values,
                labelOf: (t) => t == _Tab.unread && unread > 0 ? 'Unread ($unread)' : t.label,
                expand: true,
                height: 34,
                onChanged: onTab,
              ),
            ],
          ),
        ),
        Expanded(
          child: conversations.isEmpty
              ? EmptyNote(
                  empty
                      ? 'No conversations yet. Start one with New message.'
                      : tab == _Tab.unread
                          ? 'No unread messages. You’re all caught up.'
                          : 'No conversations match.',
                  icon: Icons.forum_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: conversations.length,
                  itemBuilder: (_, i) => _ConversationTile(
                    conversation: conversations[i],
                    selected: conversations[i].id == selectedId,
                    onTap: () => onSelect(conversations[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.selected, required this.onTap});

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unread > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.primarySoft.withValues(alpha: 0.7) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConversationAvatar(conversation: c, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ),
                          if (c.lastMessageAt != null)
                            Text(shortWhen(c.lastMessageAt!), style: AppText.meta.copyWith(fontSize: 11.5)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: unread ? AppColors.ink : AppColors.muted,
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              constraints: const BoxConstraints(minWidth: 20),
                              height: 20,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                              child: Text('${c.unread}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Consumer(builder: (context, ref, _) {
                        final cls = ref.watch(classByIdProvider)[c.classId];
                        return Text(
                          c.isGroup ? 'Class group' : (cls?.name ?? 'Student'),
                          style: AppText.meta.copyWith(fontSize: 11.5),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Initials for a student chat, a group icon for a class chat.
class ConversationAvatar extends ConsumerWidget {
  const ConversationAvatar({super.key, required this.conversation, this.size = 40});

  final Conversation conversation;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    if (c.isGroup) {
      final cls = ref.watch(classByIdProvider)[c.classId];
      final color = AppColors.forClass(cls?.colorIndex ?? 0);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(Icons.groups_rounded, color: AppColors.ink, size: size * 0.5),
      );
    }
    String? photo;
    for (final s in ref.watch(studentsProvider).valueOrNull ?? const <Student>[]) {
      if (s.id == c.studentId) photo = s.photoUrl;
    }
    return InitialsAvatar(initials: initialsOf(c.title), tone: toneForName(c.title), size: size, imageUrl: photo);
  }
}

/// "9:42 AM" today, "Yesterday", "Mon" this week, else "Oct 9".
String shortWhen(DateTime t, [DateTime? now]) {
  final today = startOfDay(now ?? DateTime.now());
  final day = startOfDay(t);
  if (day == today) return clockText(t);
  if (day == addDays(today, -1)) return 'Yesterday';
  if (today.difference(day).inDays < 7) return weekdayName(t).substring(0, 3);
  return dayMonth(t);
}

/// Used by other pages: "Message" → this page with the student's chat open.
void openStudentChat(Student s) => goTo(Routes.messages(studentId: s.id));
