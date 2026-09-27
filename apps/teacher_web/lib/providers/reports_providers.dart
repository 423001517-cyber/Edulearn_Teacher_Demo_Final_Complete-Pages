import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

final monthlyStatsProvider = StreamProvider.autoDispose.family<List<MonthlyStat>, String>(
  (ref, classId) => ref.watch(reportsRepositoryProvider).watchMonthlyStats(classId),
);

final reportSummaryProvider =
    Provider.autoDispose.family<AsyncValue<ReportSummary>, (String, ReportPeriod)>(
  (ref, args) => ref
      .watch(monthlyStatsProvider(args.$1))
      .whenData((stats) => ReportSummary.compute(stats, args.$2, DateTime.now())),
);

final missingWorkProvider = StreamProvider.autoDispose.family<List<MissingWork>, String>(
  (ref, classId) => ref.watch(reportsRepositoryProvider).watchMissingWork(classId),
);

/// The last ~3 months of attendance for one class.
final attendanceProvider = StreamProvider.autoDispose.family<List<AttendanceDay>, String>((ref, classId) {
  final now = DateTime.now();
  return ref
      .watch(reportsRepositoryProvider)
      .watchAttendance(classId, DateTime(now.year, now.month - 3, now.day));
});
