import 'package:intl/intl.dart';

import '../dates.dart';
import 'model_utils.dart';

/// `classes/{classId}/dailyPerformance/{yyyy-MM-dd}` — average score (0–1)
/// of work returned that day. Written by the `nightlyRollup` function.
class PerformancePoint {
  const PerformancePoint(this.date, this.score);

  final DateTime date;
  final double score;

  factory PerformancePoint.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return PerformancePoint(
      dateFromKey(doc.id) ?? readDate(d['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      readDouble(d['score']),
    );
  }
}

enum RangeKind { week, month, quarter, custom }

/// The "This Week / This Month / This Quarter / Custom Range" selector.
class PerformanceRange {
  const PerformanceRange(this.kind, {this.customStart, this.customEnd});

  final RangeKind kind;
  final DateTime? customStart;
  final DateTime? customEnd;

  @override
  bool operator ==(Object other) =>
      other is PerformanceRange &&
      other.kind == kind &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(kind, customStart, customEnd);

  String get label => switch (kind) {
        RangeKind.week => 'This Week',
        RangeKind.month => 'This Month',
        RangeKind.quarter => 'This Quarter',
        RangeKind.custom => customStart == null || customEnd == null
            ? 'Custom Range'
            : '${dayMonth(customStart!)} – ${dayMonth(customEnd!)}',
      };

  static String labelFor(RangeKind kind) => switch (kind) {
        RangeKind.week => 'This Week',
        RangeKind.month => 'This Month',
        RangeKind.quarter => 'This Quarter',
        RangeKind.custom => 'Custom Range',
      };

  /// X-axis buckets for the chart. Each bucket's end is exclusive.
  List<ChartBucket> buckets(DateTime now) => switch (kind) {
        RangeKind.week => _week(now),
        RangeKind.month => _month(now),
        RangeKind.quarter => _quarter(now),
        RangeKind.custom => _custom(now),
      };

  // Mon–Fri of the current school week.
  List<ChartBucket> _week(DateTime now) {
    final monday = startOfWeek(now);
    return [
      for (var i = 0; i < 5; i++)
        ChartBucket.day(addDays(monday, i), DateFormat('E').format(addDays(monday, i))),
    ];
  }

  List<ChartBucket> _month(DateTime now) => _chunks(
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1),
        7,
        (i, _) => 'Wk ${i + 1}',
      );

  List<ChartBucket> _quarter(DateTime now) {
    final firstMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    return [
      for (var m = 0; m < 3; m++)
        ChartBucket(
          DateFormat('MMM').format(DateTime(now.year, firstMonth + m, 1)),
          DateTime(now.year, firstMonth + m, 1),
          DateTime(now.year, firstMonth + m + 1, 1),
        ),
    ];
  }

  // Daily buckets for short ranges, otherwise ~12 evenly sized buckets.
  List<ChartBucket> _custom(DateTime now) {
    final start = startOfDay(customStart ?? startOfWeek(now));
    final endExclusive = addDays(startOfDay(customEnd ?? now), 1);
    final days = (endExclusive.difference(start).inHours / 24).round();
    final step = days <= 14 ? 1 : (days / 12).ceil();
    return _chunks(start, endExclusive, step, (_, s) => DateFormat('MMM d').format(s));
  }
}

List<ChartBucket> _chunks(
  DateTime start,
  DateTime endExclusive,
  int stepDays,
  String Function(int index, DateTime start) label,
) {
  final out = <ChartBucket>[];
  var cursor = start;
  var i = 0;
  while (cursor.isBefore(endExclusive)) {
    var next = addDays(cursor, stepDays);
    if (next.isAfter(endExclusive)) next = endExclusive;
    out.add(ChartBucket(label(i, cursor), cursor, next));
    cursor = next;
    i++;
  }
  return out;
}

class ChartBucket {
  const ChartBucket(this.label, this.start, this.end);

  ChartBucket.day(DateTime day, this.label)
      : start = startOfDay(day),
        end = addDays(startOfDay(day), 1);

  final String label;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// Average score per bucket; `null` where no data exists (drawn as a gap).
List<double?> bucketAverages(List<ChartBucket> buckets, List<PerformancePoint> points) => [
      for (final b in buckets)
        _mean(points.where((p) => b.contains(p.date)).map((p) => p.score)),
    ];

double? _mean(Iterable<double> xs) {
  var n = 0;
  var sum = 0.0;
  for (final x in xs) {
    sum += x;
    n++;
  }
  return n == 0 ? null : sum / n;
}

class PerformanceSeries {
  const PerformanceSeries({
    required this.classId,
    required this.name,
    required this.colorIndex,
    required this.values,
  });

  final String classId;
  final String name;
  final int colorIndex;

  /// One value per bucket, 0.0 – 1.0, or null for "no data".
  final List<double?> values;
}

class PerformanceChartData {
  const PerformanceChartData({required this.labels, required this.series});

  static const empty = PerformanceChartData(labels: [], series: []);

  final List<String> labels;
  final List<PerformanceSeries> series;

  bool get hasData => series.any((s) => s.values.any((v) => v != null));
}

/// Family key for the performance chart: one class, or all active classes.
class PerformanceQuery {
  const PerformanceQuery({this.classId, required this.range});

  final String? classId;
  final PerformanceRange range;

  @override
  bool operator ==(Object other) =>
      other is PerformanceQuery && other.classId == classId && other.range == range;

  @override
  int get hashCode => Object.hash(classId, range);
}
