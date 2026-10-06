import 'classwork_item.dart';
import 'model_utils.dart';
import 'submission.dart';

enum GradeCalculation {
  totalPoints('Total points', 'Overall grade is based on total points across all included assignments.'),
  weighted('Weighted by category', 'Set category weights to calculate the overall grade.'),
  none('No overall grade', 'Only show assignment scores, no overall grade.');

  const GradeCalculation(this.label, this.hint);
  final String label;
  final String hint;

  static GradeCalculation parse(Object? v) =>
      GradeCalculation.values.firstWhere((c) => c.name == v, orElse: () => GradeCalculation.totalPoints);
}

/// One row of the grading scale ("A 90–100", green).
class GradeLevel {
  const GradeLevel(this.letter, this.min, this.max, this.color);

  final String letter;
  final int min;
  final int max;

  /// ARGB, e.g. 0xFF1B6D47.
  final int color;

  factory GradeLevel.fromMap(Object? raw) {
    final d = raw is Map ? raw : const {};
    int i(String k) => d[k] is num ? (d[k] as num).toInt() : 0;
    return GradeLevel(readString(d['letter'], '?'), i('min'), i('max'), i('color'));
  }

  Json toMap() => {'letter': letter, 'min': min, 'max': max, 'color': color};

  static const defaults = [
    GradeLevel('A', 90, 100, 0xFF1B6D47),
    GradeLevel('B', 80, 89, 0xFF4CC38A),
    GradeLevel('C', 75, 79, 0xFFF6C443),
    GradeLevel('D', 70, 74, 0xFFF08A3C),
    GradeLevel('F', 0, 69, 0xFFE5484D),
  ];
}

/// `classes/{classId}/gradebook/settings` — Grade settings, the grading
/// scale and gradebook-only choices. Students' "show overall grade" lives on
/// the class (`showOverallGrade`).
class GradebookSettings {
  const GradebookSettings({
    this.calculation = GradeCalculation.totalPoints,
    this.weights = const {'quest': 25, 'activity': 25, 'quiz': 20, 'boss': 30},
    this.missingAsZero = true,
    this.roundGrades = true,
    this.autoUpdate = true,
    this.passingGrade = 75,
    this.scale = GradeLevel.defaults,
    this.showLetters = true,
    this.hiddenColumns = const [],
    this.removedColumns = const [],
    this.excludedStudents = const [],
    this.notes = const {},
  });

  final GradeCalculation calculation;

  /// Percent per classwork type name (quest, activity, quiz, boss).
  final Map<String, int> weights;
  final bool missingAsZero;
  final bool roundGrades;
  final bool autoUpdate;
  final int passingGrade;
  final List<GradeLevel> scale;
  final bool showLetters;

  /// Classwork ids left out of the overall grade ("Hide from overall grade").
  final List<String> hiddenColumns;

  /// Classwork ids removed from the gradebook ("Delete grade column").
  final List<String> removedColumns;

  /// Students left out of averages ("Exclude from overall calculation").
  final List<String> excludedStudents;

  /// Private teacher notes per student id.
  final Map<String, String> notes;

  factory GradebookSettings.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const GradebookSettings();
    List<String> strings(String k) => d[k] is List ? [for (final x in d[k] as List) '$x'] : const [];
    return GradebookSettings(
      calculation: GradeCalculation.parse(d['calculation']),
      weights: d['weights'] is Map
          ? {for (final e in (d['weights'] as Map).entries) if (e.value is num) '${e.key}': (e.value as num).toInt()}
          : const GradebookSettings().weights,
      missingAsZero: d['missingAsZero'] != false,
      roundGrades: d['roundGrades'] != false,
      autoUpdate: d['autoUpdate'] != false,
      passingGrade: d['passingGrade'] is num ? (d['passingGrade'] as num).toInt() : 75,
      scale: d['scale'] is List && (d['scale'] as List).isNotEmpty
          ? (d['scale'] as List).map(GradeLevel.fromMap).toList()
          : GradeLevel.defaults,
      showLetters: d['showLetters'] != false,
      hiddenColumns: strings('hiddenColumns'),
      removedColumns: strings('removedColumns'),
      excludedStudents: strings('excludedStudents'),
      notes: d['notes'] is Map ? {for (final e in (d['notes'] as Map).entries) '${e.key}': '${e.value}'} : const {},
    );
  }

  Json toMap() => {
        'calculation': calculation.name,
        'weights': weights,
        'missingAsZero': missingAsZero,
        'roundGrades': roundGrades,
        'autoUpdate': autoUpdate,
        'passingGrade': passingGrade,
        'scale': [for (final g in scale) g.toMap()],
        'showLetters': showLetters,
        'hiddenColumns': hiddenColumns,
        'removedColumns': removedColumns,
        'excludedStudents': excludedStudents,
        'notes': notes,
      };

  GradebookSettings copyWith({
    GradeCalculation? calculation,
    Map<String, int>? weights,
    bool? missingAsZero,
    bool? roundGrades,
    bool? autoUpdate,
    int? passingGrade,
    List<GradeLevel>? scale,
    bool? showLetters,
    List<String>? hiddenColumns,
    List<String>? removedColumns,
    List<String>? excludedStudents,
    Map<String, String>? notes,
  }) =>
      GradebookSettings(
        calculation: calculation ?? this.calculation,
        weights: weights ?? this.weights,
        missingAsZero: missingAsZero ?? this.missingAsZero,
        roundGrades: roundGrades ?? this.roundGrades,
        autoUpdate: autoUpdate ?? this.autoUpdate,
        passingGrade: passingGrade ?? this.passingGrade,
        scale: scale ?? this.scale,
        showLetters: showLetters ?? this.showLetters,
        hiddenColumns: hiddenColumns ?? this.hiddenColumns,
        removedColumns: removedColumns ?? this.removedColumns,
        excludedStudents: excludedStudents ?? this.excludedStudents,
        notes: notes ?? this.notes,
      );

  /// The scale row for a percentage (0–100), or null.
  GradeLevel? letterFor(double percent) {
    final p = percent.round();
    for (final g in scale) {
      if (p >= g.min && p <= g.max) return g;
    }
    return null;
  }
}

/// Problems with a grading scale, or null when it's valid: whole numbers,
/// min ≤ max, no overlaps, and together covering 0–100.
String? validateScale(List<GradeLevel> scale) {
  if (scale.isEmpty) return 'Add at least one grade level.';
  final sorted = [...scale]..sort((a, b) => a.min.compareTo(b.min));
  for (final g in sorted) {
    if (g.letter.trim().isEmpty) return 'Every level needs a letter.';
    if (g.min < 0 || g.max > 100 || g.min > g.max) return '${g.letter}: the range must be between 0 and 100, min ≤ max.';
  }
  if (sorted.first.min != 0) return 'The lowest level must start at 0.';
  if (sorted.last.max != 100) return 'The highest level must end at 100.';
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].min - sorted[i - 1].max;
    if (gap < 1) return '${sorted[i - 1].letter} and ${sorted[i].letter} overlap.';
    if (gap > 1) return 'There is a gap between ${sorted[i - 1].letter} and ${sorted[i].letter}.';
  }
  return null;
}

/// A student's overall grade as a percentage (null = nothing to grade yet
/// or "No overall grade"). [submissions] are this student's, keyed by
/// classwork id.
double? overallGrade(
  GradebookSettings settings,
  List<ClassworkItem> columns,
  Map<String, Submission> submissions,
  DateTime now,
) {
  if (settings.calculation == GradeCalculation.none) return null;
  final earned = <String, double>{};
  final possible = <String, double>{};
  for (final w in columns) {
    if (settings.hiddenColumns.contains(w.id) || w.points <= 0) continue;
    final s = submissions[w.id];
    double? score;
    if (s?.score != null) {
      score = s!.score!.toDouble();
    } else if (s == null && w.dueDate.isBefore(now) && settings.missingAsZero) {
      score = 0;
    }
    if (score == null) continue; // not due yet, turned in but ungraded, or missing excluded
    final key = settings.calculation == GradeCalculation.weighted ? w.type.name : 'all';
    earned[key] = (earned[key] ?? 0) + score;
    possible[key] = (possible[key] ?? 0) + w.points;
  }
  if (possible.isEmpty) return null;
  double result;
  if (settings.calculation == GradeCalculation.totalPoints) {
    result = earned['all']! / possible['all']! * 100;
  } else {
    var weightSum = 0.0;
    var total = 0.0;
    for (final k in possible.keys) {
      final weight = (settings.weights[k] ?? 0).toDouble();
      if (weight <= 0) continue;
      total += earned[k]! / possible[k]! * 100 * weight;
      weightSum += weight;
    }
    if (weightSum == 0) return null;
    result = total / weightSum;
  }
  result = result.clamp(0, 100).toDouble();
  return settings.roundGrades ? result.roundToDouble() : (result * 10).round() / 10;
}
