import 'package:cloud_firestore/cloud_firestore.dart';

import '../dates.dart';
import 'model_utils.dart';

enum AttendanceMark {
  present('Present', 'P'),
  late('Late', 'L'),
  absent('Absent', 'A'),

  /// Absent with a parent's note. Excused days don't count for or against
  /// the attendance rate.
  excused('Excused', 'E');

  const AttendanceMark(this.label, this.letter);
  final String label;

  /// The one-letter button on the Attendance page.
  final String letter;

  /// Present or late counts as attended.
  bool get attended => this == AttendanceMark.present || this == AttendanceMark.late;

  /// Whether this mark counts toward the attendance rate.
  bool get counts => this != AttendanceMark.excused;

  static AttendanceMark? parse(Object? v) {
    for (final m in values) {
      if (m.name == v) return m;
    }
    return null;
  }
}

/// `attendance/{classId_yyyy-MM-dd}` — one document per class per school day.
class AttendanceDay {
  const AttendanceDay({
    required this.classId,
    required this.date,
    required this.marks,
    this.notes = const {},
    this.times = const {},
    this.savedAt,
  });

  final String classId;
  final DateTime date;

  /// studentId -> mark
  final Map<String, AttendanceMark> marks;

  /// studentId -> note ("Medical check-up, note received")
  final Map<String, String> notes;

  /// studentId -> when the student was marked present or late that day.
  final Map<String, DateTime> times;
  final DateTime? savedAt;

  static String docId(String classId, DateTime date) => '${classId}_${dateKey(date)}';

  factory AttendanceDay.fromDoc(Doc doc) {
    final d = dataOf(doc);
    final marks = <String, AttendanceMark>{};
    final rawMarks = d['marks'];
    if (rawMarks is Map) {
      rawMarks.forEach((k, v) {
        final mark = AttendanceMark.parse(v);
        if (k is String && mark != null) marks[k] = mark;
      });
    }
    final notes = <String, String>{};
    final rawNotes = d['notes'];
    if (rawNotes is Map) {
      rawNotes.forEach((k, v) {
        if (k is String && v is String && v.trim().isNotEmpty) notes[k] = v;
      });
    }
    final times = <String, DateTime>{};
    final rawTimes = d['times'];
    if (rawTimes is Map) {
      rawTimes.forEach((k, v) {
        final t = readDate(v);
        if (k is String && t != null) times[k] = t;
      });
    }
    return AttendanceDay(
      classId: readString(d['classId']),
      date: dateFromKey(doc.id) ?? readDate(d['date']) ?? DateTime.now(),
      marks: marks,
      notes: notes,
      times: times,
      savedAt: readDate(d['savedAt']),
    );
  }

  Json toMap({required String teacherId}) => {
        'teacherId': teacherId,
        'classId': classId,
        'date': Timestamp.fromDate(startOfDay(date)),
        'marks': {for (final e in marks.entries) e.key: e.value.name},
        'notes': {
          for (final e in notes.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        },
        'times': {for (final e in times.entries) e.key: Timestamp.fromDate(e.value)},
        'savedAt': FieldValue.serverTimestamp(),
      };

  int count(AttendanceMark m) => marks.values.where((v) => v == m).length;

  /// Present or late, out of everyone not excused.
  double get rate {
    final counted = marks.values.where((m) => m.counts).length;
    if (counted == 0) return 0;
    return marks.values.where((m) => m.attended).length / counted;
  }

  /// null when no attendance was taken (or everyone was excused).
  double? get rateOrNull => marks.values.any((m) => m.counts) ? rate : null;
}

/// One student's marks over some school days.
class AttendanceTally {
  AttendanceTally();

  int presentDays = 0;
  int lateDays = 0;
  int absentDays = 0;
  int excusedDays = 0;

  void add(AttendanceMark m) {
    switch (m) {
      case AttendanceMark.present:
        presentDays++;
      case AttendanceMark.late:
        lateDays++;
      case AttendanceMark.absent:
        absentDays++;
      case AttendanceMark.excused:
        excusedDays++;
    }
  }

  int get days => presentDays + lateDays + absentDays + excusedDays;

  /// Present or late, out of days that count (excused days are left out).
  double? get rate {
    final counted = presentDays + lateDays + absentDays;
    return counted == 0 ? null : (presentDays + lateDays) / counted;
  }

  /// Two or more absences or three or more lates.
  bool get needsFollowUp => absentDays >= 2 || lateDays >= 3;

  /// "3 absences, 1 late"
  String get summary {
    String n(int v, String one, String many) => '$v ${v == 1 ? one : many}';
    final parts = [
      if (absentDays > 0) n(absentDays, 'absence', 'absences'),
      if (lateDays > 0) n(lateDays, 'late', 'lates'),
      if (excusedDays > 0) '$excusedDays excused',
    ];
    return parts.isEmpty ? 'Perfect attendance' : parts.join(', ');
  }
}

/// studentId -> tally over [days].
Map<String, AttendanceTally> tallyByStudent(Iterable<AttendanceDay> days) {
  final out = <String, AttendanceTally>{};
  for (final d in days) {
    d.marks.forEach((id, m) => (out[id] ??= AttendanceTally()).add(m));
  }
  return out;
}

/// The days of [days] that fall in the month of [month].
List<AttendanceDay> daysInMonth(Iterable<AttendanceDay> days, DateTime month) =>
    days.where((d) => d.date.year == month.year && d.date.month == month.month).toList();

/// Present-or-late share across every mark in [days]; null without data.
double? pooledRate(Iterable<AttendanceDay> days) {
  var attended = 0, counted = 0;
  for (final d in days) {
    for (final m in d.marks.values) {
      if (!m.counts) continue;
      counted++;
      if (m.attended) attended++;
    }
  }
  return counted == 0 ? null : attended / counted;
}

typedef WeekRate = ({DateTime monday, String label, double? rate});

/// The last [weeks] school weeks ending with the week of [now], oldest first,
/// labelled "Oct 5 – 9".
List<WeekRate> weeklyRates(Iterable<AttendanceDay> days, DateTime now, {int weeks = 4}) {
  final thisMonday = startOfWeek(now);
  return [
    for (var i = weeks - 1; i >= 0; i--)
      () {
        final monday = addDays(thisMonday, -7 * i);
        final friday = addDays(monday, 4);
        final inWeek = days.where((d) => !d.date.isBefore(monday) && d.date.isBefore(addDays(monday, 5)));
        final label = monday.month == friday.month
            ? '${dayMonth(monday)} – ${friday.day}'
            : '${dayMonth(monday)} – ${dayMonth(friday)}';
        return (monday: monday, label: label, rate: pooledRate(inWeek));
      }(),
  ];
}
