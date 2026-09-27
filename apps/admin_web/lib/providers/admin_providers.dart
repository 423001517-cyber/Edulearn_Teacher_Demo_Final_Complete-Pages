import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

// ---------------------------------------------------------- live streams
// Kept alive while signed in, so moving between pages is instant.

final teachersProvider = StreamProvider.autoDispose<List<Teacher>>(
  (ref) => ref.watch(adminRepositoryProvider).watchTeachers(),
);

final classesProvider = StreamProvider.autoDispose<List<ClassRoom>>(
  (ref) => ref.watch(adminRepositoryProvider).watchClasses(),
);

final studentsProvider = StreamProvider.autoDispose<List<Student>>(
  (ref) => ref.watch(adminRepositoryProvider).watchStudents(),
);

final requestsProvider = StreamProvider.autoDispose<List<ClassRequest>>(
  (ref) => ref.watch(adminRepositoryProvider).watchRequests(),
);

final adminsProvider = StreamProvider.autoDispose<List<AdminUser>>(
  (ref) => ref.watch(adminRepositoryProvider).watchAdmins(),
);

final settingsProvider = StreamProvider.autoDispose<SchoolSettings>(
  (ref) => ref.watch(adminRepositoryProvider).watchSettings(),
);

final monthlyStatsProvider = StreamProvider.autoDispose.family<List<MonthlyStat>, String>(
  (ref, classId) => ref.watch(adminRepositoryProvider).watchMonthlyStats(classId),
);

final reportSummaryProvider =
    Provider.autoDispose.family<AsyncValue<ReportSummary>, (String, ReportPeriod)>(
  (ref, args) => ref
      .watch(monthlyStatsProvider(args.$1))
      .whenData((s) => ReportSummary.compute(s, args.$2, DateTime.now())),
);

// ---------------------------------------------------------- lookups

final teacherByIdProvider = Provider.autoDispose<Map<String, Teacher>>((ref) => {
      for (final t in ref.watch(teachersProvider).valueOrNull ?? const <Teacher>[]) t.uid: t,
    });

final classByIdProvider = Provider.autoDispose<Map<String, ClassRoom>>((ref) => {
      for (final c in ref.watch(classesProvider).valueOrNull ?? const <ClassRoom>[]) c.id: c,
    });

final activeClassesProvider = Provider.autoDispose<AsyncValue<List<ClassRoom>>>(
  (ref) => ref.watch(classesProvider).whenData((l) => l.where((c) => !c.isArchived).toList()),
);

/// Active classes per teacher uid.
final classesByTeacherProvider = Provider.autoDispose<Map<String, List<ClassRoom>>>((ref) {
  final out = <String, List<ClassRoom>>{};
  for (final c in ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[]) {
    out.putIfAbsent(c.teacherId, () => []).add(c);
  }
  return out;
});

/// Students per class id.
final studentsByClassProvider = Provider.autoDispose<Map<String, List<Student>>>((ref) {
  final out = <String, List<Student>>{};
  for (final s in ref.watch(studentsProvider).valueOrNull ?? const <Student>[]) {
    out.putIfAbsent(s.classId, () => []).add(s);
  }
  return out;
});

final pendingRequestCountProvider = Provider.autoDispose<int>(
  (ref) => (ref.watch(requestsProvider).valueOrNull ?? const <ClassRequest>[])
      .where((r) => r.isPending)
      .length,
);

/// The signed-in admin's profile (falls back to the Auth display name).
final currentAdminProvider = Provider.autoDispose<AdminUser?>((ref) {
  final user = ref.watch(adminSessionProvider).user;
  if (user == null) return null;
  for (final a in ref.watch(adminsProvider).valueOrNull ?? const <AdminUser>[]) {
    if (a.uid == user.uid) return a;
  }
  return AdminUser(uid: user.uid, displayName: user.displayName ?? 'Administrator', email: user.email ?? '');
});

/// Next free student number in a class ("0021").
String nextStudentNumber(Iterable<Student> classStudents) {
  var max = 0;
  for (final s in classStudents) {
    final n = int.tryParse(s.studentNumber) ?? 0;
    if (n > max) max = n;
  }
  return '${max + 1}'.padLeft(4, '0');
}
