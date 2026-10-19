import '../dates.dart';
import '../models/class_topic.dart';
import '../models/classwork_item.dart';
import '../models/gradebook.dart';
import '../models/performance.dart';
import '../models/student.dart';
import 'report_math.dart';

/// The Analytics page's "This week / This month / This quarter" switch.
enum AnalyticsRange {
  week('This week', RangeKind.week, 'vs last week'),
  month('This month', RangeKind.month, 'vs last month'),
  quarter('This quarter', RangeKind.quarter, 'vs last quarter');

  const AnalyticsRange(this.label, this.kind, this.comparison);
  final String label;
  final RangeKind kind;

  /// Caption for the change, e.g. "+3% vs last month".
  final String comparison;

  PerformanceRange get chartRange => PerformanceRange(kind);

  DateRange range(DateTime now) {
    final b = chartRange.buckets(now);
    return (start: b.first.start, end: b.last.end);
  }

  /// The same stretch of time just before [range].
  DateRange previous(DateTime now) {
    final r = range(now);
    return switch (this) {
      AnalyticsRange.week => (start: addDays(r.start, -7), end: addDays(r.end, -7)),
      AnalyticsRange.month => (start: DateTime(r.start.year, r.start.month - 1, 1), end: r.start),
      AnalyticsRange.quarter => (start: DateTime(r.start.year, r.start.month - 3, 1), end: r.start),
    };
  }

  static AnalyticsRange parse(String? v) =>
      AnalyticsRange.values.firstWhere((r) => r.name == v, orElse: () => AnalyticsRange.month);
}

/// Average score of returned work, weighted by how many students were scored.
double? weightedAverage(Iterable<ClassworkItem> items) {
  var sum = 0.0;
  var n = 0;
  for (final w in items) {
    sum += w.scoreSum;
    n += w.scoredCount;
  }
  return n == 0 ? null : sum / n;
}

/// Mean share of the class that turned in each past-due item.
double? averageCompletion(Iterable<ClassworkItem> items, Map<String, int> classSizes, DateTime now) {
  final rates = [
    for (final w in items)
      if (w.dueDate.isBefore(now) && (classSizes[w.classId] ?? 0) > 0) w.completionRate(classSizes[w.classId]!),
  ];
  if (rates.isEmpty) return null;
  return rates.reduce((a, b) => a + b) / rates.length;
}

typedef TypeScore = ({ClassworkType type, double? average, double? completion, int items});

/// Quests, activities, quizzes and Friday Boss, in that order.
List<TypeScore> scoreByType(Iterable<ClassworkItem> items, Map<String, int> classSizes, DateTime now) => [
      for (final t in const [ClassworkType.quest, ClassworkType.activity, ClassworkType.quiz, ClassworkType.boss])
        () {
          final of = items.where((w) => w.type == t).toList();
          return (
            type: t,
            average: weightedAverage(of),
            completion: averageCompletion(of, classSizes, now),
            items: of.length,
          );
        }(),
    ];

class TopicMastery {
  const TopicMastery({required this.topicId, required this.name, required this.average, required this.items, this.position = 0});

  final String topicId;

  /// "Mga Rehiyon ng Pilipinas" (the "Week 3:" prefix is dropped).
  final String name;
  final double average;
  final int items;
  final double position;
}

/// "Week 3: Klima at Panahon" -> "Klima at Panahon".
String topicLabel(String name) => name.replaceFirst(RegExp(r'^\s*(week|linggo)\s*\d+\s*[:–-]\s*', caseSensitive: false), '');

/// Average score per topic, newest topics first, at most [limit].
List<TopicMastery> topicMastery(Iterable<ClassworkItem> items, List<ClassTopic> topics, {int limit = 6}) {
  final byId = {for (final t in topics) t.id: t};
  final groups = <String, List<ClassworkItem>>{};
  for (final w in items) {
    final id = w.topicId;
    if (id == null || byId[id] == null) continue;
    (groups[id] ??= []).add(w);
  }
  final out = <TopicMastery>[];
  groups.forEach((id, list) {
    final avg = weightedAverage(list);
    if (avg == null) return;
    out.add(TopicMastery(
      topicId: id,
      name: topicLabel(byId[id]!.name),
      average: avg,
      items: list.length,
      position: byId[id]!.position,
    ));
  });
  out.sort((a, b) => b.position.compareTo(a.position));
  return out.take(limit).toList();
}

typedef LetterCount = ({GradeLevel level, int count});

/// Students per letter grade (from their average score), A first.
List<LetterCount> letterDistribution(Iterable<Student> students, GradebookSettings settings) {
  final counts = <String, int>{};
  for (final s in students) {
    final avg = s.averageScore;
    if (avg == null) continue;
    final level = settings.letterFor(avg * 100);
    if (level != null) counts[level.letter] = (counts[level.letter] ?? 0) + 1;
  }
  final levels = [...settings.scale]..sort((a, b) => b.min.compareTo(a.min));
  return [for (final g in levels) (level: g, count: counts[g.letter] ?? 0)];
}

/// Scored items with the lowest class average, worst first.
List<ClassworkItem> lowestScoring(Iterable<ClassworkItem> items, {int limit = 5}) {
  final scored = items.where((w) => w.averageScore != null).toList()
    ..sort((a, b) => a.averageScore!.compareTo(b.averageScore!));
  return scored.take(limit).toList();
}

typedef Improvement = ({Student student, double gain});

/// Students whose last three scores beat their quarter average, biggest gain first.
List<Improvement> mostImproved(Iterable<Student> students, {int limit = 5}) {
  final out = <Improvement>[
    for (final s in students)
      if (s.recentScore != null && s.averageScore != null && s.recentScore! - s.averageScore! > 0.005)
        (student: s, gain: s.recentScore! - s.averageScore!),
  ]..sort((a, b) => b.gain.compareTo(a.gain));
  return out.take(limit).toList();
}

/// Change between the first and last week that has data (null if fewer than two).
double? seriesGain(List<double?> values) {
  final known = values.whereType<double>().toList();
  if (known.length < 2) return null;
  return known.last - known.first;
}

/// Students who haven't opened EduLearn for [days] days or more.
List<Student> inactiveStudents(Iterable<Student> students, DateTime now, {int days = 7}) =>
    students.where((s) => s.lastActiveAt != null && s.inactiveDays(now) >= days).toList();
