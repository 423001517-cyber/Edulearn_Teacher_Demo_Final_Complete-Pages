import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'classes_providers.dart';
import 'core_providers.dart';
import 'data_providers.dart';

final classworkItemProvider = StreamProvider.autoDispose.family<ClassworkItem?, String>(
  (ref, id) => ref.watch(classworkRepositoryProvider).watchItem(id),
);

final classTopicsProvider = StreamProvider.autoDispose.family<List<ClassTopic>, String>(
  (ref, classId) => ref.watch(classworkRepositoryProvider).watchTopics(classId),
);

/// Submissions waiting for a grade in one class ("Needs review").
final classNeedsReviewProvider = Provider.autoDispose.family<AsyncValue<int>, String>(
  (ref, classId) => ref
      .watch(pendingSubmissionsProvider)
      .whenData((l) => l.where((s) => s.classId == classId).length),
);

enum ClassworkSort {
  dueDate('Due date'),
  created('Date created'),
  title('Title'),
  status('Status'),
  custom('My order');

  const ClassworkSort(this.label);
  final String label;
}

/// The toolbar's search / quarter / type / status / sort choices.
class ClassworkFilters {
  const ClassworkFilters({
    this.query = '',
    this.quarter,
    this.type,
    this.status,
    this.sort = ClassworkSort.dueDate,
  });

  final String query;

  /// null = all quarters.
  final int? quarter;
  final ClassworkType? type;
  final ClassworkStatus? status;
  final ClassworkSort sort;

  bool get narrowsItems => query.trim().isNotEmpty || type != null || status != null;

  ClassworkFilters copyWith({
    String? query,
    int? quarter,
    bool allQuarters = false,
    ClassworkType? type,
    bool allTypes = false,
    ClassworkStatus? status,
    bool allStatuses = false,
    ClassworkSort? sort,
  }) =>
      ClassworkFilters(
        query: query ?? this.query,
        quarter: allQuarters ? null : (quarter ?? this.quarter),
        type: allTypes ? null : (type ?? this.type),
        status: allStatuses ? null : (status ?? this.status),
        sort: sort ?? this.sort,
      );
}

/// Pure: filters and sorts one class's classwork.
List<ClassworkItem> applyClassworkFilters(List<ClassworkItem> items, ClassworkFilters f) {
  final q = f.query.trim().toLowerCase();
  final out = items.where((w) {
    if (f.quarter != null && w.quarter != f.quarter) return false;
    if (f.type != null && w.type != f.type) return false;
    if (f.status != null && w.status != f.status) return false;
    return q.isEmpty || '${w.title} ${w.type.label} ${w.description}'.toLowerCase().contains(q);
  }).toList();
  int byDate(ClassworkItem a, ClassworkItem b) => a.dueDate.compareTo(b.dueDate);
  out.sort(switch (f.sort) {
    ClassworkSort.dueDate => byDate,
    ClassworkSort.created => (a, b) =>
        (b.createdAt ?? b.dueDate).compareTo(a.createdAt ?? a.dueDate),
    ClassworkSort.title => (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    ClassworkSort.status => (a, b) {
        final s = a.status.index.compareTo(b.status.index);
        return s != 0 ? s : byDate(a, b);
      },
    ClassworkSort.custom => (a, b) {
        final p = a.position.compareTo(b.position);
        return p != 0 ? p : byDate(a, b);
      },
  });
  return out;
}

/// One topic section on the page (topic == null → "No topic").
class TopicSection {
  const TopicSection(this.topic, this.items);

  final ClassTopic? topic;
  final List<ClassworkItem> items;
}

/// Pure: groups (already filtered and sorted) items under their topics, in
/// topic order. Empty topics are kept unless the filters narrow the list;
/// "No topic" comes last and only when it has items.
List<TopicSection> groupByTopic(
  List<ClassworkItem> items,
  List<ClassTopic> topics, {
  bool keepEmpty = true,
}) {
  final known = {for (final t in topics) t.id};
  final sections = <TopicSection>[
    for (final t in topics)
      TopicSection(t, [for (final w in items) if (w.topicId == t.id) w]),
  ].where((s) => keepEmpty || s.items.isNotEmpty).toList();
  final loose = [for (final w in items) if (w.topicId == null || !known.contains(w.topicId)) w];
  if (loose.isNotEmpty) sections.add(TopicSection(null, loose));
  return sections;
}

/// "Week 1: Mga Rehiyon" in the list → "Week 1 — Mga Rehiyon" as a heading.
String topicHeading(String name) {
  final i = name.indexOf(': ');
  return i > 0 && name.substring(0, i).startsWith('Week') ? '${name.substring(0, i)} — ${name.substring(i + 2)}' : name;
}

/// Counts for the four stat cards.
({int published, int drafts, int scheduled}) classworkCounts(Iterable<ClassworkItem> items) => (
      published: items.where((w) => w.status == ClassworkStatus.published).length,
      drafts: items.where((w) => w.status == ClassworkStatus.draft).length,
      scheduled: items.where((w) => w.status == ClassworkStatus.scheduled).length,
    );

/// All of a class's classwork (the Classes module's stream, limit 150).
final classworkListProvider = Provider.autoDispose.family<AsyncValue<List<ClassworkItem>>, String>(
  (ref, classId) => ref.watch(classClassworkProvider(classId)),
);
