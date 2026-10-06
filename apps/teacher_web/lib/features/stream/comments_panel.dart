import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../data/stream_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/stream_providers.dart';
import 'post_cards.dart';
import 'stream_widgets.dart';

/// "Class comments — Welcome to Quarter 1!" side panel.
Future<void> showCommentsPanel(
  BuildContext context, {
  required PostRef post,
  required String title,
  required String classId,
}) =>
    showSidePanel<void>(
      context: context,
      width: 480,
      builder: (_) => _CommentsPanel(post: post, title: title, classId: classId),
    );

class _CommentsPanel extends ConsumerStatefulWidget {
  const _CommentsPanel({required this.post, required this.title, required this.classId});

  final PostRef post;
  final String title;
  final String classId;

  @override
  ConsumerState<_CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends ConsumerState<_CommentsPanel> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  PostAttachment? _attachment;
  bool _uploading = false;
  bool _sending = false;
  int _lastCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reply(StreamComment c) {
    final mention = '@${c.authorName.split(' ').first} ';
    if (!_input.text.startsWith(mention)) {
      _input.text = '$mention${_input.text}';
    }
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  Future<void> _attach() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final f = result?.files.single;
    final bytes = f?.bytes;
    if (f == null || bytes == null) return;
    if (bytes.length > StreamRepository.maxBytes) {
      showToast('${f.name} is larger than 25 MB.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final a = await ref.read(streamRepositoryProvider).uploadFile(fileName: f.name, bytes: bytes);
      if (mounted) setState(() => _attachment = a);
    } catch (e) {
      showToast('Couldn’t upload ${f.name}: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _attachment == null) return;
    final teacher = ref.read(teacherProvider).valueOrNull;
    setState(() => _sending = true);
    try {
      await ref.read(streamRepositoryProvider).addComment(
            widget.post,
            StreamComment(
              authorId: ref.read(uidProvider),
              authorName: teacher?.displayName ?? 'Teacher',
              authorRole: 'teacher',
              body: text,
              attachment: _attachment,
            ),
          );
      _input.clear();
      setState(() => _attachment = null);
    } catch (e) {
      showToast('Couldn’t post the comment: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEndIfNew(int count) {
    if (count > _lastCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
    _lastCount = count;
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(postCommentsProvider(widget.post));
    final teacher = ref.watch(teacherProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class comments', style: AppText.dialogTitle.copyWith(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(widget.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 26),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AsyncValueView<List<StreamComment>>(
            value: comments,
            data: (list) {
              _scrollToEndIfNew(list.length);
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyNote('No class comments yet. Start the conversation below.',
                      icon: Icons.chat_bubble_outline_rounded),
                );
              }
              return ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _CommentTile(
                  comment: list[i],
                  onReply: () => _reply(list[i]),
                  onCopyLink: () async {
                    await Clipboard.setData(
                        ClipboardData(text: postLink(widget.classId, widget.post, commentId: list[i].id)));
                    showToast('Link copied');
                  },
                  onDelete: () async {
                    final repo = ref.read(streamRepositoryProvider);
                    final ok = await confirmAction(
                      context,
                      title: 'Delete this comment?',
                      message: 'It will be removed for everyone in the class.',
                      confirmLabel: 'Delete comment',
                      destructive: true,
                    );
                    if (!ok) return;
                    await repo.deleteComment(widget.post, list[i]);
                    showToast('Comment deleted');
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_attachment != null || _uploading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _uploading
                        ? const Chip(
                            avatar: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            label: Text('Uploading…'),
                          )
                        : AttachmentChip(
                            attachment: _attachment!,
                            onRemove: () {
                              ref.read(streamRepositoryProvider).deleteFile(_attachment!);
                              setState(() => _attachment = null);
                            },
                          ),
                  ),
                ),
              Row(
                children: [
                  PersonAvatar(name: teacher?.displayName ?? 'Teacher', photoUrl: teacher?.photoUrl, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Add class comment...', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Attach a file',
                    onPressed: _uploading ? null : _attach,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending || _uploading ? null : _send,
                    child: const Text('Post'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onCopyLink,
    required this.onDelete,
  });

  final StreamComment comment;
  final VoidCallback onReply;
  final VoidCallback onCopyLink;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = comment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(name: c.authorName, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(c.isTeacher ? 'Teacher ${c.authorName.split(' ').first}' : c.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (c.isTeacher) const Pill('Teacher', tone: Tone.blue),
                    if (c.createdAt != null) Text(postTime(c.createdAt!), style: AppText.meta.copyWith(fontSize: 12.5)),
                  ],
                ),
                if (c.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  FormattedText(c.body, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.inkSoft)),
                ],
                if (c.attachment != null) ...[
                  const SizedBox(height: 8),
                  AttachmentChip(attachment: c.attachment!),
                ],
              ],
            ),
          ),
          MoreMenu<String>(
            items: [
              menuItem('reply', Icons.reply_rounded, 'Reply'),
              menuItem('link', Icons.link_rounded, 'Copy link'),
              const PopupMenuDivider(),
              menuItem('delete', Icons.delete_outline_rounded, 'Delete comment', destructive: true),
            ],
            onSelected: (v) {
              switch (v) {
                case 'reply':
                  onReply();
                case 'link':
                  onCopyLink();
                case 'delete':
                  onDelete();
              }
            },
          ),
        ],
      ),
    );
  }
}
