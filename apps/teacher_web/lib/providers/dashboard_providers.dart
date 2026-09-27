import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data_providers.dart';

/// The header's class selector. null = "All Classes".
/// Not auto-disposed, so the choice survives a trip to the Classes page.
final selectedClassIdProvider = StateProvider<String?>((ref) => null);

final performanceRangeProvider =
    StateProvider<PerformanceRange>((ref) => const PerformanceRange(RangeKind.week));

/// True for class ids the dashboard should show: active classes, narrowed to
/// the selected class if there is one.
final _inScopeProvider = Provider.autoDispose<bool Function(String? classId)>((ref) {
  final selected = ref.watch(selectedClassIdProvider);
  final active = ref.watch(activeClassesProvider).valueOrNull;
  final activeIds = active == null ? null : {for (final c in active) c.id};
  return (classId) {
    if (classId == null) return true; // e.g. announcements to all classes
    if (activeIds != null && !activeIds.contains(classId)) return false;
    return selected == null || selected == classId;
  };
});

AsyncValue<List<T>> _scoped<T>(
  AsyncValue<List<T>> source,
  bool Function(String?) inScope,
  String? Function(T) classOf,
) =>
    source.whenData((l) => l.where((e) => inScope(classOf(e))).toList());

final visibleClassesProvider = Provider.autoDispose<AsyncValue<List<ClassRoom>>>((ref) {
  final inScope = ref.watch(_inScopeProvider);
  return _scoped(ref.watch(activeClassesProvider), inScope, (c) => c.id);
});

final visibleStudentsProvider = Provider.autoDispose<AsyncValue<List<Student>>>(
  (ref) => _scoped(ref.watch(studentsProvider), ref.watch(_inScopeProvider), (s) => s.classId),
);

final visibleClassworkProvider = Provider.autoDispose<AsyncValue<List<ClassworkItem>>>(
  (ref) =>
      _scoped(ref.watch(classworkFromWeekProvider), ref.watch(_inScopeProvider), (c) => c.classId),
);

final upcomingProvider = Provider.autoDispose<AsyncValue<List<ClassworkItem>>>((ref) {
  final today = startOfDay(DateTime.now());
  return ref
      .watch(visibleClassworkProvider)
      .whenData((l) => l.where((c) => !c.dueDate.isBefore(today)).toList());
});

/// Graded, non-draft work due this week — the "Active Quests" card.
final activeQuestCountProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  final weekStart = startOfWeek(DateTime.now());
  final weekEnd = addDays(weekStart, 7);
  return ref.watch(visibleClassworkProvider).whenData((l) => l
      .where((c) =>
          c.type.isGraded &&
          c.status != ClassworkStatus.draft &&
          !c.dueDate.isBefore(weekStart) &&
          c.dueDate.isBefore(weekEnd))
      .length);
});

final visiblePendingSubmissionsProvider = Provider.autoDispose<AsyncValue<List<Submission>>>(
  (ref) =>
      _scoped(ref.watch(pendingSubmissionsProvider), ref.watch(_inScopeProvider), (s) => s.classId),
);

final missingWorkCountProvider = Provider.autoDispose<AsyncValue<int>>(
  (ref) => ref.watch(visibleStudentsProvider).whenData((l) => l.where((s) => s.missingCount > 0).length),
);

typedef FlaggedStudent = ({Student student, SupportFlag flag});

List<FlaggedStudent> flagStudents(Iterable<Student> students, DateTime now) {
  final out = <FlaggedStudent>[
    for (final s in students)
      if (s.supportFlag(now) case final flag?) (student: s, flag: flag),
  ];
  out.sort((a, b) {
    final p = b.flag.priority.compareTo(a.flag.priority);
    return p != 0 ? p : a.student.name.compareTo(b.student.name);
  });
  return out;
}

final studentsNeedingSupportProvider = Provider.autoDispose<AsyncValue<List<FlaggedStudent>>>(
  (ref) => ref.watch(visibleStudentsProvider).whenData((l) => flagStudents(l, DateTime.now())),
);

final visibleAnnouncementsProvider = Provider.autoDispose<AsyncValue<List<Announcement>>>((ref) {
  final inScope = ref.watch(_inScopeProvider);
  return ref
      .watch(announcementsProvider)
      .whenData((l) => sortAnnouncements(l.where((a) => inScope(a.classId))));
});

final dashboardPerformanceProvider = Provider.autoDispose<AsyncValue<PerformanceChartData>>((ref) {
  final query = PerformanceQuery(
    classId: ref.watch(selectedClassIdProvider),
    range: ref.watch(performanceRangeProvider),
  );
  return ref.watch(performanceChartProvider(query));
});
