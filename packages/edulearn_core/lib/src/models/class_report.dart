import 'package:intl/intl.dart';

import 'model_utils.dart';

/// The period selector on the Class Reports page.
enum ReportPeriod {
  thisQuarter('This Quarter', 'from last quarter'),
  lastQuarter('Last Quarter', 'from the quarter before'),
  thisYear('This Year', 'from last year');

  const ReportPeriod(this.label, this.comparisonLabel);
  final String label;
  final String comparisonLabel;

  static ReportPeriod parse(String? v) => ReportPeriod.values
      .firstWhere((p) => p.name == v, orElse: () => ReportPeriod.thisQuarter);

  /// [start, end) of this period.
  ({DateTime start, DateTime end}) range(DateTime now) {
    final q = (now.month - 1) ~/ 3; // 0..3
    return switch (this) {
      ReportPeriod.thisQuarter =>
        (start: DateTime(now.year, q * 3 + 1), end: DateTime(now.year, q * 3 + 4)),
      ReportPeriod.lastQuarter =>
        (start: DateTime(now.year, q * 3 - 2), end: DateTime(now.year, q * 3 + 1)),
      ReportPeriod.thisYear => (start: DateTime(now.year), end: DateTime(now.year + 1)),
    };
  }

  /// The equally long period right before [range], for "+12% from last quarter".
  ({DateTime start, DateTime end}) previousRange(DateTime now) {
    final r = range(now);
    final months = (r.end.year - r.start.year) * 12 + r.end.month - r.start.month;
    return (start: DateTime(r.start.year, r.start.month - months), end: r.start);
  }
}

/// `classes/{classId}/monthlyStats/{yyyy-MM}` — written by `nightlyRollup`.
class MonthlyStat {
  const MonthlyStat({
    required this.month,
    required this.completion,
    required this.averageScore,
    required this.attendance,
    required this.missingWork,
  });

  final DateTime month; // first day of the month
  final double completion;
  final double averageScore;
  final double attendance;

  /// Students with missing work at the end of the month.
  final int missingWork;

  factory MonthlyStat.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return MonthlyStat(
      month: dateFromKey(doc.id) ?? readDate(d['month']) ?? DateTime.now(),
      completion: readDouble(d['completion']),
      averageScore: readDouble(d['averageScore']),
      attendance: readDouble(d['attendance']),
      missingWork: readInt(d['missingWork']),
    );
  }
}

class MetricSummary {
  const MetricSummary(this.value, this.delta);

  final double? value;

  /// Change vs the previous period (null when there's nothing to compare).
  final double? delta;
}

/// Everything the four stat cards and the trend chart need.
class ReportSummary {
  const ReportSummary({
    required this.completion,
    required this.averageScore,
    required this.attendance,
    required this.missingWork,
    required this.trend,
  });

  final MetricSummary completion;
  final MetricSummary averageScore;
  final MetricSummary attendance;
  final MetricSummary missingWork;

  /// Up to six months ending with the period, oldest first.
  final List<MonthlyStat> trend;

  static ReportSummary compute(List<MonthlyStat> stats, ReportPeriod period, DateTime now) {
    final cur = period.range(now);
    final prev = period.previousRange(now);
    bool inRange(MonthlyStat s, ({DateTime start, DateTime end}) r) =>
        !s.month.isBefore(r.start) && s.month.isBefore(r.end);

    final current = stats.where((s) => inRange(s, cur)).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
    final previous = stats.where((s) => inRange(s, prev)).toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    MetricSummary avgOf(double Function(MonthlyStat) f) {
      final c = _avg(current.map(f));
      final p = _avg(previous.map(f));
      return MetricSummary(c, c != null && p != null ? c - p : null);
    }

    final lastCur = current.isEmpty ? null : current.last.missingWork.toDouble();
    final lastPrev = previous.isEmpty ? null : previous.last.missingWork.toDouble();

    final trendEnd = cur.end.isAfter(now) ? DateTime(now.year, now.month + 1) : cur.end;
    final trendStart = DateTime(trendEnd.year, trendEnd.month - 6);
    final trend = stats
        .where((s) => !s.month.isBefore(trendStart) && s.month.isBefore(trendEnd))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    return ReportSummary(
      completion: avgOf((s) => s.completion),
      averageScore: avgOf((s) => s.averageScore),
      attendance: avgOf((s) => s.attendance),
      missingWork: MetricSummary(
        lastCur,
        lastCur != null && lastPrev != null ? lastCur - lastPrev : null,
      ),
      trend: trend,
    );
  }
}

double? _avg(Iterable<double> xs) {
  var n = 0;
  var sum = 0.0;
  for (final x in xs) {
    sum += x;
    n++;
  }
  return n == 0 ? null : sum / n;
}

String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
