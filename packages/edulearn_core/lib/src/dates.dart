import 'package:intl/intl.dart';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar-safe day arithmetic (avoids DST drift from Duration math).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

/// Monday 00:00 of the week containing [d].
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// The next [weekday] on or after [from] — e.g. the coming Friday.
DateTime nextWeekday(DateTime from, int weekday) {
  final diff = (weekday - from.weekday) % 7; // Dart % is non-negative
  return DateTime(from.year, from.month, from.day + diff);
}

/// "2026-10-19" — the Manila calendar day, used in document ids.
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Saturday or Sunday.
bool isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

/// The nearest school day (Mon–Fri) [step] days away: -1 = previous, 1 = next.
DateTime nextSchoolDay(DateTime from, int step) {
  var d = addDays(startOfDay(from), step);
  while (isWeekend(d)) {
    d = addDays(d, step);
  }
  return d;
}

/// "7:05 AM"
String clockText(DateTime d) => DateFormat('h:mm a').format(d);

String monthAbbr(DateTime d) => DateFormat('MMM').format(d);
String monthName(DateTime d) => DateFormat('MMMM').format(d);
String dayMonth(DateTime d) => DateFormat('MMM d').format(d);
String weekdayName(DateTime d) => DateFormat('EEEE').format(d);
String longDate(DateTime d) => DateFormat('EEE, MMM d, y').format(d);
String shortDate(DateTime d) => DateFormat('EEE, MMM d').format(d);
String fullDate(DateTime d) => DateFormat('MMM d, y').format(d);

/// School quarter 1–4 for a date. Philippine school years start in June:
/// Q1 Jun–Aug, Q2 Sep–Nov, Q3 Dec–Feb, Q4 Mar–May.
int schoolQuarter(DateTime d) => ((d.month - 6 + 12) % 12) ~/ 3 + 1;

String greetingFor(DateTime now) => switch (now.hour) {
      < 12 => 'Good morning',
      < 18 => 'Good afternoon',
      _ => 'Good evening',
    };

String timeAgo(DateTime then, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(then);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return _ago(diff.inMinutes, 'minute');
  if (diff.inDays < 1) return _ago(diff.inHours, 'hour');
  if (diff.inDays < 7) return _ago(diff.inDays, 'day');
  return dayMonth(then);
}

String _ago(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
