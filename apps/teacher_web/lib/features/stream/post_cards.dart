import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../data/stream_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/stream_providers.dart';
import '../classwork/classwork_details_popover.dart';
import '../classwork/classwork_form_dialog.dart';
import 'comments_panel.dart';
import 'stream_composer.dart';
import 'stream_widgets.dart';

/// One card in the stream.
class StreamPostCard extends StatelessWidget {
  const StreamPostCard({super.key, required this.post, required this.classRoom});

  final StreamPost post;
  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) => switch (post) {
        AnnouncementPost(:final announcement) => AnnouncementCard(announcement: announcement, classRoom: classRoom),
        ClassworkPost p => ClassworkPostCard(post: p, classRoom: classRoom),
      };
}

/// "Teacher Jean" — how students address the teacher.
String teacherLabel(Teacher? t) => t == null ? 'Teacher' : 'Teacher ${t.firstName}';

/// Absolute link to a post (opens its class comments).
String postLink(String classId, PostRef ref, {String? commentId}) {
  final path = Routes.stream(classId: classId, post: ref.encode());
  final url = Uri.base.resolve(path);
  return commentId == null ? url.toString() : '$url#comment-$commentId';
}

Future<void> copyPostLink(String classId, PostRef ref) async {
  await Clipboard.setData(ClipboardData(text: postLink(classId, ref)));
  showToast('Link copied');
}

/// Opens the full editor for an existing post in a dialog.
Future<void> showEditPostDialog(BuildContext context, Announcement a, String classId) => showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        maxWidth: 780,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              title: a.status == PostStatus.draft ? 'Edit draft' : 'Edit post',
              subtitle: a.status == PostStatus.scheduled && a.publishAt != null
                  ? 'Scheduled for ${postTime(a.publishAt!)}'
                  : null,
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: StreamComposer(classId: classId, existing: a, onDone: () => Navigator.pop(ctx)),
              ),
            ),
          ],
        ),
      ),
    );

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
        child: child,
      );
}

/// "💬 5 comments" / "Add class comment".
class CommentsLink extends StatelessWidget {
  const CommentsLink({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: count == 0 ? AppColors.muted : AppColors.inkSoft),
        onPressed: onTap,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
        label: Text(count == 0 ? 'Add class comment' : '$count comment${count == 1 ? '' : 's'}'),
      );
}

// ---------------------------------------------------------------- announcement
class AnnouncementCard extends ConsumerWidget {
  const AnnouncementCard({super.key, required this.announcement, required this.classRoom});

  final Announcement announcement;
  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final now = DateTime.now();
    final live = a.isLive(now);
    final postedAt = a.postedAt;
    final postRef = PostRef(PostKind.announcement, a.id);

    void openComments() =>
        showCommentsPanel(context, post: postRef, title: a.headline, classId: classRoom.id);

    final header = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(teacherLabel(teacher), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        if (postedAt != null && live) Text(postTime(postedAt), style: AppText.meta.copyWith(fontSize: 13)),
        if (a.status == PostStatus.scheduled && !live && a.publishAt != null)
          Pill('Scheduled · ${postTime(a.publishAt!)}', tone: Tone.blue, icon: Icons.schedule_rounded),
        if (a.status == PostStatus.draft) const Pill('Draft', tone: Tone.neutral, icon: Icons.edit_note_rounded),
        if (a.pinned) const Pill('Pinned', tone: Tone.amber, icon: Icons.push_pin_rounded),
        if (a.classId == null) const Pill('All my classes', tone: Tone.green),
      ],
    );

    return _CardFrame(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(name: teacher?.displayName ?? 'Teacher', photoUrl: teacher?.photoUrl, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (a.title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.title, style: AppText.itemTitle.copyWith(fontSize: 17)),
                ],
                if (a.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  FormattedText(a.body, style: AppText.meta.copyWith(fontSize: 14, height: 1.45, color: AppColors.inkSoft)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  spacing: 12,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in a.attachments) AttachmentChip(attachment: f),
                    ]),
                    if (a.status == PostStatus.published || live)
                      CommentsLink(count: a.commentCount, onTap: openComments)
                    else
                      FilledButton.tonal(
                        onPressed: () => showEditPostDialog(context, a, classRoom.id),
                        child: Text(a.status == PostStatus.draft ? 'Edit draft' : 'Edit'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _AnnouncementMenu(announcement: a, classId: classRoom.id),
        ],
      ),
    );
  }
}

class _AnnouncementMenu extends ConsumerWidget {
  const _AnnouncementMenu({required this.announcement, required this.classId});

  final Announcement announcement;
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    final live = a.isLive(DateTime.now());
    return MoreMenu<String>(
      items: [
        menuItem('edit', Icons.edit_outlined, a.status == PostStatus.draft ? 'Edit draft' : 'Edit'),
        if (!live) menuItem('now', Icons.send_outlined, 'Post now'),
        if (live) menuItem('pin', Icons.push_pin_outlined, a.pinned ? 'Unpin' : 'Pin to top'),
        if (live) menuItem('link', Icons.link_rounded, 'Copy link'),
        const PopupMenuDivider(),
        menuItem('delete', Icons.delete_outline_rounded, 'Delete', destructive: true),
      ],
      onSelected: (v) async {
        final repo = ref.read(streamRepositoryProvider);
        switch (v) {
          case 'edit':
            showEditPostDialog(context, a, classId);
          case 'now':
            await repo.publishNow(a);
            showToast('Posted to the stream');
          case 'pin':
            await repo.setPinned(a.id, !a.pinned);
            showToast(a.pinned ? 'Unpinned' : 'Pinned to the top of the stream');
          case 'link':
            await copyPostLink(classId, PostRef(PostKind.announcement, a.id));
          case 'delete':
            final ok = await confirmAction(
              context,
              title: 'Delete this post?',
              message: '“${a.headline}” and its class comments will be removed from the stream.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (!ok) return;
            await repo.deletePost(a);
            showToast('Post deleted');
        }
      },
    );
  }
}

// ---------------------------------------------------------------- classwork
class ClassworkPostCard extends ConsumerWidget {
  const ClassworkPostCard({super.key, required this.post, required this.classRoom});

  final ClassworkPost post;
  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = post.item;
    final kind = post.kind;
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final detailed = classRoom.classworkNotices == ClassworkNotices.details;

    void openComments() => showCommentsPanel(context, post: post.ref, title: w.title, classId: classRoom.id);

    final view = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      onPressed: () => showClassworkPreview(context, w),
      child: Text(kind.viewLabel),
    );

    return _CardFrame(
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > 640;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToneIcon(kind.icon, tone: kind.tone, size: 50, circle: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: teacherLabel(teacher), style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: ' posted ${kind.noun}', style: AppText.meta),
                      TextSpan(text: '     ${postTime(post.date)}', style: AppText.meta.copyWith(fontSize: 12.5)),
                    ]),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(w.title, style: AppText.itemTitle.copyWith(fontSize: 17)),
                  if (w.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    FormattedText(
                      w.description,
                      maxLines: detailed ? null : 2,
                      style: AppText.meta.copyWith(fontSize: 14, height: 1.45, color: AppColors.inkSoft),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (w.type.isGraded) ...[
                        MetaChip(
                          icon: Icons.event_available_rounded,
                          label: 'Due ${fullDate(w.dueDate)}',
                          color: AppColors.primary,
                        ),
                        MetaChip(icon: Icons.bar_chart_rounded, label: '${w.points} points'),
                      ],
                      for (final f in w.allAttachments) AttachmentChip(attachment: f),
                      if (!wide) view,
                    ],
                  ),
                  if (w.commentCount > 0 || kind == StreamWorkKind.material)
                    Align(
                      alignment: Alignment.centerRight,
                      child: CommentsLink(count: w.commentCount, onTap: openComments),
                    ),
                ],
              ),
            ),
            if (wide) ...[const SizedBox(width: 12), view],
            _ClassworkMenu(item: w, classId: classRoom.id, onComments: openComments),
          ],
        );
      }),
    );
  }
}

class _ClassworkMenu extends ConsumerWidget {
  const _ClassworkMenu({required this.item, required this.classId, required this.onComments});

  final ClassworkItem item;
  final String classId;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MoreMenu<String>(
      items: [
        menuItem('view', Icons.visibility_outlined, 'View details'),
        menuItem('edit', Icons.edit_outlined, 'Edit'),
        menuItem('comments', Icons.chat_bubble_outline_rounded, 'Class comments'),
        menuItem('link', Icons.link_rounded, 'Copy link'),
        menuItem('open', Icons.open_in_new_rounded, 'Open in Classwork'),
      ],
      onSelected: (v) async {
        switch (v) {
          case 'view':
            showClassworkPreview(context, item);
          case 'edit':
            showClassworkForm(context, type: item.type, existing: item);
          case 'comments':
            onComments();
          case 'link':
            await copyPostLink(classId, PostRef(PostKind.classwork, item.id));
          case 'open':
            goTo(Routes.classDetail(classId, ClassTab.classwork));
        }
      },
    );
  }
}
