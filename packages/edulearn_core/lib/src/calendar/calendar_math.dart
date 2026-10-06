/// Pure calendar helpers shared by the teacher website and student app.
library;

/// The 6×7 (or 5×7) grid of days shown for [month], starting on Sunday.
List<DateTime> monthGrid(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final start = first.subtract(Duration(days: first.weekday % 7)); // back to Sunday
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final cells = ((first.weekday % 7) + daysInMonth) > 35 ? 42 : 35;
  return [for (var i = 0; i < cells; i++) DateTime(start.year, start.month, start.day + i)];
}

/// Sunday–Saturday of the week containing [day].
List<DateTime> weekDays(DateTime day) {
  final start = DateTime(day.year, day.month, day.day - day.weekday % 7);
  return [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// One entry in an .ics file.
class IcsEntry {
  const IcsEntry({required this.uid, required this.title, required this.start, this.end, this.allDay = true, this.description = ''});

  final String uid;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String description;
}

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';
String _dateTime(DateTime d) => '${_date(d)}T${_two(d.hour)}${_two(d.minute)}00';

/// Escapes text for iCalendar (RFC 5545).
String icsEscape(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');

/// A whole calendar as .ics text (Asia/Manila local times).
String buildIcs(String name, Iterable<IcsEntry> entries, {DateTime? stamp}) {
  final now = stamp ?? DateTime.now().toUtc();
  final b = StringBuffer()
    ..write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//EduLearn//Teacher Calendar//EN\r\n')
    ..write('CALSCALE:GREGORIAN\r\nX-WR-CALNAME:${icsEscape(name)}\r\nX-WR-TIMEZONE:Asia/Manila\r\n');
  for (final e in entries) {
    b
      ..write('BEGIN:VEVENT\r\n')
      ..write('UID:${e.uid}@edulearn\r\n')
      ..write('DTSTAMP:${_dateTime(now)}Z\r\n');
    if (e.allDay) {
      final next = DateTime(e.start.year, e.start.month, e.start.day + 1);
      b
        ..write('DTSTART;VALUE=DATE:${_date(e.start)}\r\n')
        ..write('DTEND;VALUE=DATE:${_date(e.end ?? next)}\r\n');
    } else {
      b
        ..write('DTSTART;TZID=Asia/Manila:${_dateTime(e.start)}\r\n')
        ..write('DTEND;TZID=Asia/Manila:${_dateTime(e.end ?? e.start.add(const Duration(hours: 1)))}\r\n');
    }
    b.write('SUMMARY:${icsEscape(e.title)}\r\n');
    if (e.description.isNotEmpty) b.write('DESCRIPTION:${icsEscape(e.description)}\r\n');
    b.write('END:VEVENT\r\n');
  }
  b.write('END:VCALENDAR\r\n');
  return b.toString();
}
