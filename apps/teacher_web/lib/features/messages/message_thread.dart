import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/messages_providers.dart';
import 'messages_dialogs.dart';
import 'messages_page.dart' show ConversationAvatar;

/// Header, messages and the composer for one conversation.
class MessageThread extends ConsumerWidget {
  const MessageThread({super.key, required this.conversation, this.onBack});

  final Conversation conversation;

  /// Phones: back to the conversation list.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final cls = ref.watch(classByIdProvider)[c.classId];
    final messages = ref.watch(conversationMessagesProvider(c.id));
    final subtitle = c.isGroup
        ? 'Class group · ${cls?.studentCount ?? 0} students${c.studentsCanReply ? '' : ' · announcements only'}'
        : '${cls?.name ?? 'Student'} · Student';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
              ConversationAvatar(conversation: c, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sectionTitle.copyWith(fontSize: 16)),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
                  ],
                ),
              ),
              MoreMenu<String>(
                items: [
                  if (!c.isGroup) menuItem('student', Icons.person_outline_rounded, 'View student'),
                  menuItem('class', Icons.menu_book_outlined, 'Open class'),
                  menuItem('stream', Icons.dynamic_feed_outlined, 'Post to Stream instead'),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'student':
                      goTo(Routes.students(classId: c.classId, studentId: c.studentId));
                    case 'stream':
                      goTo(Routes.stream(classId: c.classId));
                    default:
                      goTo(Routes.classDetail(c.classId));
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFFCFBF7),
            child: AsyncValueView<List<ChatMessage>>(
              value: messages,
              data: (list) => list.isEmpty
                  ? EmptyNote(
                      c.isGroup
                          ? 'Say hello to ${c.title}. Every student in the class will see it.'
                          : 'No messages yet. Say hello to ${firstNameOf(c.title)}.',
                      icon: Icons.waving_hand_outlined,
                    )
                  : _MessageList(messages: list, group: c.isGroup),
            ),
          ),
        ),
        const Divider(height: 1),
        MessageComposer(key: ValueKey('composer_${c.id}'), conversation: c),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.group});

  final List<ChatMessage> messages;
  final bool group;

  @override
  Widget build(BuildContext context) {
    // Oldest first, with a date chip whenever the day changes.
    final entries = <Object>[];
    DateTime? lastDay;
    for (final m in messages) {
      final day = startOfDay(m.createdAt ?? DateTime.now());
      if (lastDay == null || day != lastDay) entries.add(day);
      lastDay = day;
      entries.add(m);
    }
    return LayoutBuilder(builder: (context, c) {
      final maxBubble = c.maxWidth * 0.72;
      return ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final e = entries[entries.length - 1 - i];
          if (e is DateTime) return _DayChip(day: e);
          final m = e as ChatMessage;
          return _Bubble(message: m, showAuthor: group && !m.fromTeacher, maxWidth: maxBubble);
        },
      );
    });
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());
    final label = day == today
        ? 'Today'
        : day == addDays(today, -1)
            ? 'Yesterday'
            : longDate(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: AppText.meta.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showAuthor, required this.maxWidth});

  final ChatMessage message;
  final bool showAuthor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.fromTeacher;
    final time = m.createdAt == null ? 'Sending…' : clockText(m.createdAt!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showAuthor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 4),
                  child: Text(m.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.inkSoft)),
                ),
              if (m.body.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.primary : Colors.white,
                    border: mine ? null : Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 16),
                    ),
                  ),
                  child: SelectableText(
                    m.body,
                    style: TextStyle(fontSize: 13.5, height: 1.45, color: mine ? Colors.white : AppColors.ink),
                  ),
                ),
              if (m.attachment != null) ...[
                const SizedBox(height: 6),
                _AttachmentChip(attachment: m.attachment!),
              ],
              if (m.classworkId != null) ...[
                const SizedBox(height: 6),
                _ClassworkChip(id: m.classworkId!, title: m.classworkTitle ?? 'Classwork'),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Text(time, style: AppText.meta.copyWith(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment});

  final PostAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final image = RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(a.name);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: a.url == null ? null : () => launchUrl(Uri.parse(a.url!)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToneIcon(image ? Icons.image_outlined : Icons.insert_drive_file_outlined, tone: Tone.amber, size: 32),
              const SizedBox(width: 10),
              Flexible(
                child: Text(a.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassworkChip extends ConsumerWidget {
  const _ClassworkChip({required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.blueSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => goTo(Routes.classwork(item: id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_outlined, size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.ink)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.link),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text box, attach, link classwork, quick replies.
class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({super.key, required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  static const _quick = [
    'Great job!',
    'Please check Classwork for the instructions.',
    'See you in class tomorrow.',
  ];

  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _author => ref.read(teacherProvider).valueOrNull?.title ?? 'Teacher';

  Future<void> _send({PostAttachment? attachment, ClassworkItem? classwork}) async {
    final body = _text.text.trim();
    if (body.isEmpty && attachment == null && classwork == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesRepositoryProvider).send(
            widget.conversation,
            authorName: _author,
            body: attachment == null && classwork == null ? body : '',
            attachment: attachment,
            classwork: classwork,
          );
      if (attachment == null && classwork == null) _text.clear();
    } catch (e) {
      showToast('Couldn’t send: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _focus.requestFocus();
      }
    }
  }

  Future<void> _attach() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 25 * 1024 * 1024) {
      showToast('Choose a file under 25 MB.');
      return;
    }
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final a = await ref.read(streamRepositoryProvider).uploadFile(fileName: file.name, bytes: file.bytes!);
      await _send(attachment: a);
    } catch (e) {
      showToast('Couldn’t upload: $e');
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _linkClasswork() async {
    final item = await pickClassworkDialog(context, classId: widget.conversation.classId);
    if (item != null) await _send(classwork: item);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Attach a file',
                onPressed: _sending ? null : _attach,
                icon: const Icon(Icons.attach_file_rounded, size: 20),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Share classwork',
                onPressed: _sending ? null : _linkClasswork,
                icon: const Icon(Icons.assignment_outlined, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: c.isGroup ? 'Message ${c.title}…' : 'Write a message…',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _sending ? null : () => _send(),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in _quick)
                ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _text.text = q;
                    _text.selection = TextSelection.collapsed(offset: q.length);
                    _focus.requestFocus();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
