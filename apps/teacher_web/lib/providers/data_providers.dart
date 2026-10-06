import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

// Live Firestore streams shared by the Dashboard, Classes, Students and
// Reports pages. Because every page reads the same streams, an action on one
// page (archiving a class, returning a submission) updates the others
// instantly — this is what keeps the homepage and Classes connected.

final classesProvider = StreamProvider.autoDispose<List<ClassRoom>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchClasses(),
);

final activeClassesProvider = Provider.autoDispose<AsyncValue<List<ClassRoom>>>(
  (ref) => ref.watch(classesProvider).whenData((l) => l.where((c) => !c.isArchived).toList()),
);

final classByIdProvider = Provider.autoDispose<Map<String, ClassRoom>>((ref) => {
      for (final c in ref.watch(classesProvider).valueOrNull ?? const <ClassRoom>[]) c.id: c,
    });

final classProvider = Provider.autoDispose.family<AsyncValue<ClassRoom?>, String>(
  (ref, classId) => ref.watch(classesProvider).whenData((list) {
    for (final c in list) {
      if (c.id == classId) return c;
    }
    return null;
  }),
);

final studentsProvider = StreamProvider.autoDispose<List<Student>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchStudents(),
);

final classStudentsProvider = Provider.autoDispose.family<AsyncValue<List<Student>>, String>(
  (ref, classId) =>
      ref.watch(studentsProvider).whenData((l) => l.where((s) => s.classId == classId).toList()),
);

/// Students with missing work, per class id — the "3 missing" pills.
final missingByClassProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final out = <String, int>{};
  for (final s in ref.watch(studentsProvider).valueOrNull ?? const <Student>[]) {
    if (s.missingCount > 0) out[s.classId] = (out[s.classId] ?? 0) + 1;
  }
  return out;
});

/// Classwork due from Monday of this week onward.
final classworkFromWeekProvider = StreamProvider.autoDispose<List<ClassworkItem>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchClassworkFrom(startOfWeek(DateTime.now())),
);

final recentClassworkProvider = StreamProvider.autoDispose<List<ClassworkItem>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchRecentClasswork(),
);

final pendingSubmissionsProvider = StreamProvider.autoDispose<List<Submission>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchPendingSubmissions(),
);

final studentSubmissionsProvider = StreamProvider.autoDispose.family<List<Submission>, String>(
  (ref, studentId) => ref.watch(dashboardRepositoryProvider).watchStudentSubmissions(studentId),
);

final announcementsProvider = StreamProvider.autoDispose<List<Announcement>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchAnnouncements(),
);

/// Live announcements for one class (plus those posted to all classes).
/// Drafts and not-yet-due scheduled posts only show on the Stream page.
final classAnnouncementsProvider =
    Provider.autoDispose.family<AsyncValue<List<Announcement>>, String>(
  (ref, classId) => ref.watch(announcementsProvider).whenData(
        (l) => sortAnnouncements(l.where(
          (a) => (a.classId == null || a.classId == classId) && a.isLive(DateTime.now()),
        )),
      ),
);

List<Announcement> sortAnnouncements(Iterable<Announcement> items) => items.toList()
  ..sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final at = a.postedAt ?? DateTime.now();
    final bt = b.postedAt ?? DateTime.now();
    return bt.compareTo(at);
  });

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchNotifications(),
);

final unreadNotificationCountProvider = Provider.autoDispose<int>(
  (ref) => (ref.watch(notificationsProvider).valueOrNull ?? const []).where((n) => !n.read).length,
);

/// Line chart data for one class, or every active class when classId is null.
final performanceChartProvider =
    FutureProvider.autoDispose.family<PerformanceChartData, PerformanceQuery>((ref, q) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final classes = await ref.watch(classesProvider.future);
  final targets = q.classId != null
      ? classes.where((c) => c.id == q.classId).toList()
      : classes.where((c) => !c.isArchived).toList();
  final buckets = q.range.buckets(DateTime.now());
  if (buckets.isEmpty || targets.isEmpty) return PerformanceChartData.empty;

  final results = await Future.wait(
    targets.map((c) => repo.fetchPerformance(c.id, buckets.first.start, buckets.last.end)),
  );
  return PerformanceChartData(
    labels: [for (final b in buckets) b.label],
    series: [
      for (var i = 0; i < targets.length; i++)
        PerformanceSeries(
          classId: targets[i].id,
          name: targets[i].name,
          colorIndex: targets[i].colorIndex,
          values: bucketAverages(buckets, results[i]),
        ),
    ],
  );
});
