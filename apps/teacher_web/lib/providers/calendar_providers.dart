import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'classes_providers.dart';
import 'core_providers.dart';
import 'data_providers.dart';
import 'reports_providers.dart';

/// The legend's types.
enum EntryKind {
  lesson('Lessons', 'Lesson', Icons.article_rounded, Tone.blue),
  quest('Quests', 'Quest', Icons.emoji_events_rounded, Tone.green),
  activity('Activities', 'Activity', Icons.auto_stories_rounded, Tone.amber),
  quiz('Quizzes', 'Quiz', Icons.quiz_rounded, Tone.purple),
  boss('Friday Boss', 'Friday Boss', Icons.workspace_premium_rounded, Tone.amber),
  school('School events', 'School event', Icons.event_rounded, Tone.neutral);

  const EntryKind(this.legend, this.label, this.icon, this.tone);
  final String legend;
  final String label;
  final IconData icon;
  final Tone tone;

  static EntryKind of(ClassworkType t) => switch (t) {
        ClassworkType.lesson || ClassworkType.material => EntryKind.lesson,
        ClassworkType.quest => EntryKind.quest,
        ClassworkType.activity => EntryKind.activity,
        ClassworkType.quiz => EntryKind.quiz,
        ClassworkType.boss => EntryKind.boss,
      };
}

/// One thing on the calendar: a classwork date or an event.
class CalendarEntry {
  const CalendarEntry({
    required this.kind,
    required this.date,
    required this.title,
    this.className = '',
    this.item,
    this.event,
  });

  final EntryKind kind;
  final DateTime date;
  final String title;
  final String className;
  final ClassworkItem? item;
  final CalendarEvent? event;

  String get id => item?.id ?? event?.id ?? title;
}

/// Pure: classwork (not drafts) + events → entries, oldest first.
List<CalendarEntry> buildEntries({
  required Iterable<ClassworkItem> classwork,
  required Iterable<CalendarEvent> events,
  required Map<String, ClassRoom> classes,
  String? classId,
}) {
  final out = <CalendarEntry>[
    for (final w in classwork)
      if (w.status != ClassworkStatus.draft && (classId == null || w.classId == classId))
        CalendarEntry(
          kind: EntryKind.of(w.type),
          date: w.dueDate,
          title: w.title,
          className: classes[w.classId]?.name ?? w.className,
          item: w,
        ),
    for (final e in events)
      if (classId == null || e.classId == null || e.classId == classId)
        CalendarEntry(
          kind: EntryKind.school,
          date: e.start,
          title: e.title,
          className: e.classId == null ? e.kind.label : (classes[e.classId]?.name ?? e.kind.label),
          event: e,
        ),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Pure: entries on one day, in [visible] kinds.
List<CalendarEntry> entriesOn(List<CalendarEntry> all, DateTime day, Set<EntryKind> visible) =>
    [for (final e in all) if (visible.contains(e.kind) && sameDay(e.date, day)) e];

final calendarEventsProvider = StreamProvider.autoDispose<List<CalendarEvent>>(
  (ref) => ref.watch(calendarRepositoryProvider).watchEvents(),
);

/// Every active class's classwork and the teacher's events (null = all classes).
final calendarEntriesProvider = Provider.autoDispose.family<AsyncValue<List<CalendarEntry>>, String?>((ref, classId) {
  final classesValue = ref.watch(activeClassesProvider);
  final events = ref.watch(calendarEventsProvider);
  if (classesValue.hasError) return AsyncError(classesValue.error!, classesValue.stackTrace ?? StackTrace.current);
  if (events.hasError) return AsyncError(events.error!, events.stackTrace ?? StackTrace.current);
  if (!classesValue.hasValue || !events.hasValue) return const AsyncLoading();
  final classes = classesValue.requireValue.where((c) => classId == null || c.id == classId).toList();
  final work = <ClassworkItem>[];
  for (final c in classes) {
    final v = ref.watch(classClassworkProvider(c.id));
    if (!v.hasValue) return const AsyncLoading();
    work.addAll(v.requireValue);
  }
  return AsyncData(buildEntries(
    classwork: work,
    events: events.requireValue,
    classes: {for (final c in classesValue.requireValue) c.id: c},
    classId: classId,
  ));
});

/// Overdue work with missing students, most overdue first.
class OverdueItem {
  const OverdueItem(this.classworkId, this.title, this.type, this.dueDate, this.missing, this.classId);

  final String classworkId;
  final String title;
  final ClassworkType type;
  final DateTime dueDate;
  final int missing;
  final String classId;
}

final missingDeadlinesProvider = Provider.autoDispose.family<List<OverdueItem>, String?>((ref, classId) {
  final classes = (ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[])
      .where((c) => classId == null || c.id == classId);
  final byItem = <String, OverdueItem>{};
  for (final c in classes) {
    for (final m in ref.watch(missingWorkProvider(c.id)).valueOrNull ?? const <MissingWork>[]) {
      final prev = byItem[m.classworkId];
      byItem[m.classworkId] = OverdueItem(m.classworkId, m.classworkTitle, m.classworkType, m.dueDate,
          (prev?.missing ?? 0) + 1, m.classId);
    }
  }
  return byItem.values.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
});
