import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// School days of one class for the month of [key.$2], plus the five weeks
/// before it (for "Weekly attendance" early in a month).
final attendanceMonthProvider =
    StreamProvider.autoDispose.family<List<AttendanceDay>, (String, DateTime)>((ref, key) {
  final (classId, month) = key;
  final start = DateTime(month.year, month.month, 1);
  return ref
      .watch(attendanceRepositoryProvider)
      .watchDays(classId, addDays(start, -35), DateTime(month.year, month.month + 1, 1));
});
