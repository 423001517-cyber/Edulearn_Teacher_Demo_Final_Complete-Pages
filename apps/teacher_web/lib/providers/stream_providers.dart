import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stream_repository.dart';
import 'classes_providers.dart';
import 'core_providers.dart';
import 'dashboard_providers.dart';
import 'data_providers.dart';

/// What a classwork item looks like in the stream.
enum StreamWorkKind {
  assignment('an assignment', 'View assignment'),
  quiz('a quiz', 'View quiz'),
  material('a material', 'View material');

  const StreamWorkKind(this.noun, this.viewLabel);

  /// "Teacher Jean posted an assignment"
  final String noun;
  final String viewLabel;

  static StreamWorkKind of(ClassworkType t) => switch (t) {
        ClassworkType.lesson || ClassworkType.material => StreamWorkKind.material,
        ClassworkType.quiz || ClassworkType.boss => StreamWorkKind.quiz,
        ClassworkType.quest || ClassworkType.activity => StreamWorkKind.assignment,
      };
}

/// One card in the class stream.
sealed class StreamPost {
  const StreamPost();

  PostRef get ref;
  DateTime get date;
  bool get pinned => false;
}

class AnnouncementPost extends StreamPost {
  const AnnouncementPost(this.announcement);

  final Announcement announcement;

  @override
  PostRef get ref => PostRef(PostKind.announcement, announcement.id);

  @override
  DateTime get date => announcement.postedAt ?? DateTime.now();

  @override
  bool get pinned => announcement.pinned;
}

class ClassworkPost extends StreamPost {
  const ClassworkPost(this.item);

  final ClassworkItem item;

  StreamWorkKind get kind => StreamWorkKind.of(item.type);

  @override
  PostRef get ref => PostRef(PostKind.classwork, item.id);

  @override
  DateTime get date => item.createdAt ?? item.dueDate;
}

enum StreamFilter {
  all('All posts'),
  announcements('Announcements'),
  assignments('Assignments'),
  quizzes('Quizzes'),
  materials('Materials'),
  scheduled('Scheduled'),
  drafts('Drafts');

  const StreamFilter(this.label);
  final String label;
}

/// Pure: merges posts and classwork into the stream order (pinned first,
/// then newest first). Drafts and not-yet-live scheduled posts are kept so
/// the Scheduled / Drafts filters can show them.
List<StreamPost> buildStream({
  required Iterable<Announcement> announcements,
  required Iterable<ClassworkItem> classwork,
}) {
  final posts = <StreamPost>[
    for (final a in announcements) AnnouncementPost(a),
    for (final w in classwork)
      if ((w.status == ClassworkStatus.published || w.status == ClassworkStatus.closed) && w.postToStream)
        ClassworkPost(w),
  ];
  posts.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.date.compareTo(a.date);
  });
  return posts;
}

/// Pure: what each filter shows. [classworkNotices] = hidden keeps classwork
/// out of "All posts" (students won't see it there either).
List<StreamPost> filterStream(
  List<StreamPost> posts,
  StreamFilter filter,
  DateTime now, {
  ClassworkNotices classworkNotices = ClassworkNotices.condensed,
}) {
  bool live(StreamPost p) => p is! AnnouncementPost || p.announcement.isLive(now);
  return posts.where((p) {
    return switch (filter) {
      StreamFilter.all => live(p) && (p is AnnouncementPost || classworkNotices != ClassworkNotices.hidden),
      StreamFilter.announcements => p is AnnouncementPost && live(p),
      StreamFilter.assignments => p is ClassworkPost && p.kind == StreamWorkKind.assignment,
      StreamFilter.quizzes => p is ClassworkPost && p.kind == StreamWorkKind.quiz,
      StreamFilter.materials => p is ClassworkPost && p.kind == StreamWorkKind.material,
      StreamFilter.scheduled =>
        p is AnnouncementPost && p.announcement.status == PostStatus.scheduled && !live(p),
      StreamFilter.drafts => p is AnnouncementPost && p.announcement.status == PostStatus.draft,
    };
  }).toList();
}

final _classPostsProvider = StreamProvider.autoDispose.family<List<Announcement>, String>(
  (ref, classId) => ref.watch(streamRepositoryProvider).watchClassPosts(classId),
);

final _allClassesPostsProvider = StreamProvider.autoDispose<List<Announcement>>(
  (ref) => ref.watch(streamRepositoryProvider).watchAllClassesPosts(),
);

/// Everything in one class stream (unfiltered).
final classStreamProvider = Provider.autoDispose.family<AsyncValue<List<StreamPost>>, String>((ref, classId) {
  final own = ref.watch(_classPostsProvider(classId));
  final all = ref.watch(_allClassesPostsProvider);
  final work = ref.watch(classClassworkProvider(classId));
  for (final v in <AsyncValue<Object>>[own, all, work]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!own.hasValue || !all.hasValue || !work.hasValue) return const AsyncLoading();
  return AsyncData(buildStream(
    announcements: [...own.requireValue, ...all.requireValue],
    classwork: work.requireValue,
  ));
});

/// "Upcoming": graded, published work due today or later, soonest first.
final upcomingWorkProvider = Provider.autoDispose.family<AsyncValue<List<ClassworkItem>>, String>(
  (ref, classId) => ref.watch(classClassworkProvider(classId)).whenData((list) {
    final today = startOfDay(DateTime.now());
    return list
        .where((w) => w.type.isGraded && w.status == ClassworkStatus.published && !w.dueDate.isBefore(today))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }),
);

final postCommentsProvider = StreamProvider.autoDispose.family<List<StreamComment>, PostRef>(
  (ref, post) => ref.watch(streamRepositoryProvider).watchComments(post),
);

/// The class a Stream page shows: the URL's class, else the dashboard's
/// selected class, else the first active class.
final streamClassProvider = Provider.autoDispose.family<AsyncValue<ClassRoom?>, String?>((ref, classId) {
  return ref.watch(classesProvider).whenData((all) {
    final byId = {for (final c in all) c.id: c};
    final active = all.where((c) => !c.isArchived).toList();
    return byId[classId] ??
        byId[ref.watch(selectedClassIdProvider)] ??
        (active.isEmpty ? (all.isEmpty ? null : all.first) : active.first);
  });
});
