import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_web/app/routes.dart';
import 'package:teacher_web/providers/classwork_providers.dart';

/// Classwork page logic (no Firebase needed).
void main() {
  ClassworkItem item(String id, ClassworkType type, {String? topic, int quarter = 1, int day = 1,
          ClassworkStatus status = ClassworkStatus.published, double position = 0}) =>
      ClassworkItem(
        id: id, classId: 'rizal-4a', className: 'Grade 4 – Rizal', type: type, title: id,
        dueDate: DateTime(2026, 9, day), status: status, topicId: topic, quarter: quarter, position: position,
      );

  final topics = [
    const ClassTopic(id: 't1', name: 'Week 1: Mga Rehiyon', position: 1),
    const ClassTopic(id: 't2', name: 'Week 2: Anyong Lupa at Tubig', position: 2),
    const ClassTopic(id: 't3', name: 'Week 3: Kasaysayan ng Pilipinas', position: 3),
  ];
  final items = [
    item('quest', ClassworkType.quest, topic: 't1', day: 20, position: 2),
    item('lesson', ClassworkType.lesson, topic: 't1', day: 18, position: 1),
    item('draft', ClassworkType.activity, topic: 't1', day: 22, status: ClassworkStatus.draft, position: 3),
    item('quiz', ClassworkType.quiz, topic: 't2', day: 23, status: ClassworkStatus.scheduled),
    item('q2-boss', ClassworkType.boss, topic: 't2', day: 24, quarter: 2),
    item('loose', ClassworkType.material, day: 25),
  ];

  test('school quarters start in June', () {
    expect(schoolQuarter(DateTime(2026, 6, 15)), 1);
    expect(schoolQuarter(DateTime(2026, 9, 26)), 2);
    expect(schoolQuarter(DateTime(2027, 1, 5)), 3);
    expect(schoolQuarter(DateTime(2027, 5, 31)), 4);
  });

  test('quarter, type, status and search filters', () {
    List<String> ids(ClassworkFilters f) => [for (final w in applyClassworkFilters(items, f)) w.id];
    expect(ids(const ClassworkFilters(quarter: 2)), ['q2-boss']);
    expect(ids(const ClassworkFilters(type: ClassworkType.quiz)), ['quiz']);
    expect(ids(const ClassworkFilters(status: ClassworkStatus.draft)), ['draft']);
    expect(ids(const ClassworkFilters(query: 'LESS')), ['lesson']);
    expect(ids(const ClassworkFilters(quarter: 1, sort: ClassworkSort.custom)), ['quiz', 'loose', 'lesson', 'quest', 'draft']);
    expect(ids(const ClassworkFilters(sort: ClassworkSort.title)).first, 'draft');
  });

  test('grouping keeps topic order, empty topics and a last "No topic"', () {
    final sorted = applyClassworkFilters(items, const ClassworkFilters(sort: ClassworkSort.custom));
    final sections = groupByTopic(sorted, topics);
    expect([for (final s in sections) s.topic?.id], ['t1', 't2', 't3', null]);
    expect([for (final w in sections.first.items) w.id], ['lesson', 'quest', 'draft']);
    expect(sections[2].items, isEmpty);
    expect(groupByTopic(sorted, topics, keepEmpty: false).map((s) => s.topic?.id), ['t1', 't2', null]);
  });

  test('stat counts, headings and links', () {
    final c = classworkCounts(items);
    expect((c.published, c.drafts, c.scheduled), (4, 1, 1));
    expect(topicHeading('Week 1: Mga Rehiyon'), 'Week 1 — Mga Rehiyon');
    expect(topicHeading('Yamang Likas'), 'Yamang Likas');
    expect(Routes.classwork(classId: 'rizal-4a', item: 'quiz'), '/classwork?classId=rizal-4a&item=quiz');
    expect(NavSection.classwork.isBuilt, isTrue);
  });

  test('simple editors keep topic, quarter and game settings', () {
    final stored = ClassworkItem(
      id: 'x', classId: 'c', className: 'C', type: ClassworkType.quest, title: 'Old', dueDate: DateTime(2026, 9, 1),
      topicId: 't1', quarter: 2, xpReward: 100, coinReward: 25, attachments: const [PostAttachment(name: 'map.pdf')],
    );
    final edited = ClassworkItem(
      id: 'x', classId: 'c', className: 'C', type: ClassworkType.quest, title: 'New', dueDate: DateTime(2026, 9, 2),
    ).withSettingsFrom(stored);
    expect(edited.title, 'New');
    expect((edited.topicId, edited.quarter, edited.xpReward, edited.coinReward), ('t1', 2, 100, 25));
    expect(edited.attachments.single.name, 'map.pdf');
    expect(ClassworkType.material.isGraded, isFalse);
    expect(ClassworkType.boss.hasQuestions, isTrue);
  });
}
