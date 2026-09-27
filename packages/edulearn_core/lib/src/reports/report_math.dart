import '../dates.dart';
import '../models/attendance_day.dart';
import '../models/classwork_item.dart';
import '../models/student.dart';

/// Pure calculations behind the report detail panels (and the PDF export).

typedef DateRange = ({DateTime start, DateTime end});

/// A labelled share, e.g. ("Monday Quest", 0.9).
typedef LabelledRate = ({String label, double rate});

class CompletionBreakdown {
  const CompletionBreakdown({
    required this.completed,
    required this.ongoing,
    required this.overdue,
    required this.byActivity,
  });

  final int completed;
  final int ongoing;
  final int overdue;
  final List<LabelledRate> byActivity;
}

/// Past-due work counts as completed once 80% of the class has turned it in.
const completedThreshold = 0.8;

List<ClassworkItem> gradedInRange(Iterable<ClassworkItem> items, DateRange r) => items
    .where((w) =>
        w.type.isGraded &&
        w.status != ClassworkStatus.draft &&
        !w.dueDate.isBefore(r.start) &&
        w.dueDate.isBefore(r.end))
    .toList();

CompletionBreakdown completionBreakdown(
  Iterable<ClassworkItem> items,
  int classSize,
  DateRange range,
  DateTime now,
) {
  final graded = gradedInRange(items, range);
  final today = startOfDay(now);
  var completed = 0, ongoing = 0, overdue = 0;
  for (final w in graded) {
    if (!w.dueDate.isBefore(today)) {
      ongoing++;
    } else if (w.completionRate(classSize) >= completedThreshold) {
      completed++;
    } else {
      overdue++;
    }
  }
  return CompletionBreakdown(
    completed: completed,
    ongoing: ongoing,
    overdue: overdue,
    byActivity: _groupAverage(graded, (w) => w.completionRate(classSize)),
  );
}

/// Average score per activity type ("Monday Quest 85%", …).
List<LabelledRate> assessmentAverages(Iterable<ClassworkItem> items, DateRange range) =>
    _groupAverage(gradedInRange(items, range).where((w) => w.averageScore != null),
        (w) => w.averageScore!);

/// Lowest-scoring graded items below 75%, worst first.
List<ClassworkItem> difficultTopics(Iterable<ClassworkItem> items, DateRange range, {int limit = 3}) {
  final scored = gradedInRange(items, range)
      .where((w) => w.averageScore != null && w.averageScore! < 0.75)
      .toList()
    ..sort((a, b) => a.averageScore!.compareTo(b.averageScore!));
  return scored.take(limit).toList();
}

Map<ScoreBand, int> scoreDistribution(Iterable<Student> students) {
  final out = {for (final b in ScoreBand.values) b: 0};
  for (final s in students) {
    final band = s.band;
    if (band != null) out[band] = out[band]! + 1;
  }
  return out;
}

/// Groups by the item's headline ("Monday Quest", "Thursday Activity",
/// "Friday Boss Assessment"), ordered Monday → Friday.
List<LabelledRate> _groupAverage(Iterable<ClassworkItem> items, double Function(ClassworkItem) value) {
  final sums = <String, double>{};
  final counts = <String, int>{};
  final order = <String, int>{};
  for (final w in items) {
    final key = w.headline;
    sums[key] = (sums[key] ?? 0) + value(w);
    counts[key] = (counts[key] ?? 0) + 1;
    order[key] = w.type == ClassworkType.boss ? 99 : w.dueDate.weekday * 10 + w.type.index;
  }
  final keys = sums.keys.toList()..sort((a, b) => order[a]!.compareTo(order[b]!));
  return [for (final k in keys) (label: k, rate: sums[k]! / counts[k]!)];
}

/// The latest school day with attendance taken.
AttendanceDay? latestAttendance(List<AttendanceDay> days) {
  if (days.isEmpty) return null;
  return days.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
}

/// Monday–Friday of the week of the latest record (null where no record).
({List<String> labels, List<double?> rates}) weekTrend(List<AttendanceDay> days) {
  final latest = latestAttendance(days);
  final monday = startOfWeek(latest?.date ?? DateTime.now());
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  final rates = <double?>[
    for (var i = 0; i < 5; i++)
      () {
        final day = addDays(monday, i);
        for (final d in days) {
          if (startOfDay(d.date) == day) return d.rate;
        }
        return null;
      }(),
  ];
  return (labels: labels, rates: rates);
}
