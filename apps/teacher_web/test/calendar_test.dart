import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_web/app/routes.dart';
import 'package:teacher_web/providers/calendar_providers.dart';

void main() {
  test('month grid starts on Sunday and covers the month', () {
    final may = monthGrid(DateTime(2026, 5));
    expect(may.first, DateTime(2026, 4, 26)); // the design's first cell
    expect(may.length, 42);
    expect(may.last, DateTime(2026, 6, 6));
    expect(monthGrid(DateTime(2026, 2)).length, 35);
    expect(weekDays(DateTime(2026, 5, 20)).first, DateTime(2026, 5, 17));
    expect(sameDay(DateTime(2026, 5, 20, 23, 59), DateTime(2026, 5, 20)), isTrue);
  });

  test('.ics export', () {
    final ics = buildIcs('EduLearn', [
      IcsEntry(uid: 'q1', title: 'Quiz: Anyong Lupa, Tubig', start: DateTime(2026, 5, 23)),
      IcsEntry(uid: 'm1', title: 'Faculty Meeting', start: DateTime(2026, 5, 27, 15), end: DateTime(2026, 5, 27, 16, 30), allDay: false),
    ], stamp: DateTime.utc(2026, 5, 1));
    expect(ics, contains('DTSTART;VALUE=DATE:20260523\r\nDTEND;VALUE=DATE:20260524'));
    expect(ics, contains('SUMMARY:Quiz: Anyong Lupa\\, Tubig'));
    expect(ics, contains('DTSTART;TZID=Asia/Manila:20260527T150000'));
    expect(ics, contains('DTEND;TZID=Asia/Manila:20260527T163000'));
    expect(ics.startsWith('BEGIN:VCALENDAR') && ics.trimRight().endsWith('END:VCALENDAR'), isTrue);
  });

  test('entries: drafts hidden, class filter, events for all classes', () {
    ClassworkItem w(String id, ClassworkType t, String classId, {ClassworkStatus status = ClassworkStatus.published}) =>
        ClassworkItem(id: id, classId: classId, className: classId, type: t, title: id, dueDate: DateTime(2026, 5, 20), status: status);
    final entries = buildEntries(
      classwork: [
        w('quest', ClassworkType.quest, 'rizal'),
        w('mat', ClassworkType.material, 'rizal'),
        w('draft', ClassworkType.quiz, 'rizal', status: ClassworkStatus.draft),
        w('boni', ClassworkType.boss, 'boni'),
      ],
      events: [CalendarEvent(id: 'ev', title: 'Faculty Meeting', start: DateTime(2026, 5, 27))],
      classes: const {},
      classId: 'rizal',
    );
    expect([for (final e in entries) e.id], ['quest', 'mat', 'ev']);
    expect(entries[1].kind, EntryKind.lesson); // materials show with lessons
    expect(entriesOn(entries, DateTime(2026, 5, 20), {EntryKind.quest}).single.id, 'quest');
    expect(NavSection.calendar.isBuilt, isTrue);
  });
}
