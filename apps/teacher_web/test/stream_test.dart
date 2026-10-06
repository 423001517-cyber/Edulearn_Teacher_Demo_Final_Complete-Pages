import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_web/app/routes.dart';
import 'package:teacher_web/data/stream_repository.dart';
import 'package:teacher_web/providers/stream_providers.dart';

/// The Stream page's ordering and "All posts" filter (no Firebase needed).
void main() {
  final now = DateTime(2026, 9, 26, 10);

  ClassworkItem work(String id, ClassworkType type, DateTime created,
          {ClassworkStatus status = ClassworkStatus.published}) =>
      ClassworkItem(
        id: id,
        classId: 'rizal-4a',
        className: 'Grade 4 – Rizal',
        type: type,
        title: id,
        dueDate: created.add(const Duration(days: 4)),
        status: status,
        createdAt: created,
      );

  final posts = buildStream(
    announcements: [
      Announcement(id: 'welcome', title: 'Welcome', createdAt: DateTime(2026, 9, 25, 8, 30)),
      Announcement(id: 'pinned', title: 'Field trip', pinned: true, createdAt: DateTime(2026, 9, 20)),
      Announcement(id: 'draft', body: 'x', status: PostStatus.draft, createdAt: DateTime(2026, 9, 26)),
      Announcement(
          id: 'later', body: 'x', status: PostStatus.scheduled, publishAt: DateTime(2026, 9, 27, 8),
          createdAt: DateTime(2026, 9, 26)),
    ],
    classwork: [
      work('assignment', ClassworkType.quest, DateTime(2026, 9, 24, 14, 15)),
      work('quiz', ClassworkType.quiz, DateTime(2026, 9, 23, 10)),
      work('material', ClassworkType.lesson, DateTime(2026, 9, 22, 13, 45)),
      work('hidden-draft', ClassworkType.quest, DateTime(2026, 9, 26), status: ClassworkStatus.draft),
    ],
  );

  List<String> ids(List<StreamPost> l) => [for (final p in l) p.ref.id];

  test('pinned first, then newest; draft classwork never appears', () {
    expect(ids(filterStream(posts, StreamFilter.all, now)),
        ['pinned', 'welcome', 'assignment', 'quiz', 'material']);
  });

  test('filters', () {
    expect(ids(filterStream(posts, StreamFilter.announcements, now)), ['pinned', 'welcome']);
    expect(ids(filterStream(posts, StreamFilter.assignments, now)), ['assignment']);
    expect(ids(filterStream(posts, StreamFilter.quizzes, now)), ['quiz']);
    expect(ids(filterStream(posts, StreamFilter.materials, now)), ['material']);
    expect(ids(filterStream(posts, StreamFilter.drafts, now)), ['draft']);
    expect(ids(filterStream(posts, StreamFilter.scheduled, now)), ['later']);
    // Once its time has come, a scheduled post is live (sorted by publishAt).
    final tomorrow = DateTime(2026, 9, 27, 9);
    expect(ids(filterStream(posts, StreamFilter.all, tomorrow)).take(2), ['pinned', 'later']);
    expect(filterStream(posts, StreamFilter.scheduled, tomorrow), isEmpty);
  });

  test('"Hide notifications" keeps classwork out of All posts', () {
    expect(ids(filterStream(posts, StreamFilter.all, now, classworkNotices: ClassworkNotices.hidden)),
        ['pinned', 'welcome']);
  });

  test('classwork shows as assignment / quiz / material', () {
    expect(StreamWorkKind.of(ClassworkType.quest), StreamWorkKind.assignment);
    expect(StreamWorkKind.of(ClassworkType.activity), StreamWorkKind.assignment);
    expect(StreamWorkKind.of(ClassworkType.boss), StreamWorkKind.quiz);
    expect(StreamWorkKind.of(ClassworkType.lesson), StreamWorkKind.material);
    expect(StreamWorkKind.quiz.viewLabel, 'View quiz');
  });

  test('post links and stream URLs', () {
    const ref = PostRef(PostKind.announcement, 'welcome');
    expect(PostRef.decode(ref.encode()), ref);
    expect(PostRef.decode('c:quiz'), const PostRef(PostKind.classwork, 'quiz'));
    expect(PostRef.decode('nonsense'), isNull);
    expect(Routes.stream(classId: 'rizal-4a', post: ref.encode()), '/stream?classId=rizal-4a&post=a%3Awelcome');
    expect(Routes.classSettings('rizal-4a'), '/stream/settings?classId=rizal-4a');
    expect(NavSection.fromPath('/stream/settings'), NavSection.stream);
    expect(NavSection.stream.isBuilt, isTrue);
  });
}
