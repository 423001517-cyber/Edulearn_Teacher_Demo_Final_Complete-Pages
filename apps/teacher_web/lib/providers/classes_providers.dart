import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';
import 'data_providers.dart';

enum ClassListStatus {
  active('Active Classes'),
  archived('Archived Classes'),
  all('All Classes');

  const ClassListStatus(this.label);
  final String label;
}

enum ClassSort {
  name('Class name'),
  grade('Grade level'),
  completion('Completion'),
  students('Students');

  const ClassSort(this.label);
  final String label;
}

enum ClassViewMode { grid, list }

class ClassesFilter {
  const ClassesFilter({
    this.query = '',
    this.grade,
    this.status = ClassListStatus.active,
    this.sort = ClassSort.name,
    this.view = ClassViewMode.grid,
  });

  final String query;
  final int? grade; // null = All Grades
  final ClassListStatus status;
  final ClassSort sort;
  final ClassViewMode view;

  ClassesFilter copyWith({
    String? query,
    int? Function()? grade,
    ClassListStatus? status,
    ClassSort? sort,
    ClassViewMode? view,
  }) =>
      ClassesFilter(
        query: query ?? this.query,
        grade: grade != null ? grade() : this.grade,
        status: status ?? this.status,
        sort: sort ?? this.sort,
        view: view ?? this.view,
      );
}

/// Kept alive so filters survive opening a class and coming back.
final classesFilterProvider = StateProvider<ClassesFilter>((ref) => const ClassesFilter());

final filteredClassesProvider = Provider.autoDispose<AsyncValue<List<ClassRoom>>>((ref) {
  final f = ref.watch(classesFilterProvider);
  final q = f.query.trim().toLowerCase();
  return ref.watch(classesProvider).whenData((list) {
    final out = list.where((c) {
      if (f.status == ClassListStatus.active && c.isArchived) return false;
      if (f.status == ClassListStatus.archived && !c.isArchived) return false;
      if (f.grade != null && c.gradeLevel != f.grade) return false;
      if (q.isNotEmpty &&
          !'${c.name} ${c.subject} ${c.classCode}'.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    final int Function(ClassRoom, ClassRoom) compare = switch (f.sort) {
      ClassSort.name => (a, b) => a.name.compareTo(b.name),
      ClassSort.grade => (a, b) => a.gradeLevel.compareTo(b.gradeLevel),
      ClassSort.completion => (a, b) => b.completionRate.compareTo(a.completionRate),
      ClassSort.students => (a, b) => b.studentCount.compareTo(a.studentCount),
    };
    out.sort(compare);
    return out;
  });
});

final archivedClassesProvider = Provider.autoDispose<AsyncValue<List<ClassRoom>>>(
  (ref) => ref.watch(classesProvider).whenData((l) => l.where((c) => c.isArchived).toList()),
);

final gradeLevelsProvider = Provider.autoDispose<List<int>>((ref) {
  final grades = {
    for (final c in ref.watch(classesProvider).valueOrNull ?? const <ClassRoom>[]) c.gradeLevel,
  }.toList()
    ..sort();
  return grades;
});

final classClassworkProvider = StreamProvider.autoDispose.family<List<ClassworkItem>, String>(
  (ref, classId) => ref.watch(classesRepositoryProvider).watchClassClasswork(classId),
);

final classActivityProvider = StreamProvider.autoDispose.family<List<ActivityEntry>, String>(
  (ref, classId) => ref.watch(classesRepositoryProvider).watchActivity(classId),
);
