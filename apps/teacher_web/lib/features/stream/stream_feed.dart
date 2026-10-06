import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/stream_repository.dart';
import '../../providers/stream_providers.dart';
import '../classes/widgets/class_actions.dart';
import 'comments_panel.dart';
import 'post_cards.dart';
import 'stream_composer.dart';

/// Composer + "All posts" filter + the list of posts. Used by the Stream
/// page and by the Stream tab on the class page.
class StreamFeed extends ConsumerStatefulWidget {
  const StreamFeed({super.key, required this.classRoom, this.openPost});

  final ClassRoom classRoom;

  /// From a copied link (`?post=a:{id}`): open that post's comments.
  final String? openPost;

  @override
  ConsumerState<StreamFeed> createState() => _StreamFeedState();
}

class _StreamFeedState extends ConsumerState<StreamFeed> {
  static const _pageSize = 15;
  final _composer = GlobalKey<StreamComposerState>();
  StreamFilter _filter = StreamFilter.all;
  int _shown = _pageSize;
  String? _openedPost;

  @override
  void didUpdateWidget(StreamFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classRoom.id != widget.classRoom.id) {
      _filter = StreamFilter.all;
      _shown = _pageSize;
    }
  }

  void _maybeOpenLinkedPost(List<StreamPost> posts) {
    final wanted = PostRef.decode(widget.openPost);
    if (wanted == null || _openedPost == widget.openPost) return;
    for (final p in posts) {
      if (p.ref == wanted) {
        _openedPost = widget.openPost;
        final title = switch (p) {
          AnnouncementPost(:final announcement) => announcement.headline,
          ClassworkPost(:final item) => item.title,
        };
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showCommentsPanel(context, post: p.ref, title: title, classId: widget.classRoom.id);
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classRoom;
    final stream = ref.watch(classStreamProvider(c.id));
    final now = DateTime.now();
    final all = stream.valueOrNull ?? const <StreamPost>[];
    int count(StreamFilter f) => filterStream(all, f, now).length;
    final scheduled = count(StreamFilter.scheduled);
    final drafts = count(StreamFilter.drafts);

    final filter = FilterDropdown<StreamFilter>(
      value: _filter,
      options: StreamFilter.values,
      labelOf: (f) => switch (f) {
        StreamFilter.scheduled when scheduled > 0 => 'Scheduled ($scheduled)',
        StreamFilter.drafts when drafts > 0 => 'Drafts ($drafts)',
        _ => f.label,
      },
      minWidth: 150,
      onChanged: (f) => setState(() {
        _filter = f;
        _shown = _pageSize;
      }),
    );

    final composer = c.isArchived
        ? Container(
            decoration: AppDecorations.card,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const ToneIcon(Icons.archive_outlined, tone: Tone.neutral, size: 42),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('This class is archived. Restore it to post announcements again.',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                OutlinedButton(
                  onPressed: () => runClassAction(context, ref, c, ClassAction.restore),
                  child: const Text('Restore'),
                ),
                const SizedBox(width: 12),
                filter,
              ],
            ),
          )
        : StreamComposer(
            key: _composer,
            classId: c.id,
            trailing: [
              filter,
              IconButton.outlined(
                tooltip: 'Attach a file to a new post',
                style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
                onPressed: () => _composer.currentState?.openWithFile(),
                icon: const Icon(Icons.attach_file_rounded),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        composer,
        const SizedBox(height: 16),
        AsyncValueView<List<StreamPost>>(
          value: stream,
          loadingHeight: 220,
          data: (posts) {
            _maybeOpenLinkedPost(posts);
            final visible = filterStream(posts, _filter, now, classworkNotices: c.classworkNotices);
            if (visible.isEmpty) {
              return Container(
                decoration: AppDecorations.card,
                child: EmptyNote(
                  switch (_filter) {
                    StreamFilter.all => 'Nothing in the stream yet. Share an announcement to get started.',
                    StreamFilter.scheduled => 'No scheduled posts. Use Post ▾ → Schedule.',
                    StreamFilter.drafts => 'No drafts. Use Post ▾ → Save draft.',
                    _ => 'No ${_filter.label.toLowerCase()} in this class yet.',
                  },
                  icon: Icons.dynamic_feed_outlined,
                ),
              );
            }
            final page = visible.take(_shown).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in page) ...[
                  StreamPostCard(key: ValueKey(p.ref), post: p, classRoom: c),
                  const SizedBox(height: 14),
                ],
                if (visible.length > page.length)
                  Center(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _shown += _pageSize),
                      child: Text('Show more (${visible.length - page.length})'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
