import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

enum EventKind {
  school('School event'),
  classEvent('Class event'),
  reminder('Reminder');

  const EventKind(this.label);
  final String label;

  static EventKind parse(Object? v) =>
      EventKind.values.firstWhere((k) => k.name == v, orElse: () => EventKind.school);
}

/// `calendarEvents/{id}` — something on the Calendar that isn't classwork:
/// "Faculty Meeting", a field trip, a class reminder.
class CalendarEvent {
  const CalendarEvent({
    this.id = '',
    required this.title,
    required this.start,
    this.end,
    this.allDay = true,
    this.classId,
    this.kind = EventKind.school,
    this.location = '',
    this.notes = '',
  });

  final String id;
  final String title;
  final DateTime start;

  /// Optional end (same day for timed events).
  final DateTime? end;
  final bool allDay;

  /// null = all my classes / the whole school.
  final String? classId;
  final EventKind kind;
  final String location;
  final String notes;

  factory CalendarEvent.fromDoc(Doc doc) {
    final d = dataOf(doc);
    return CalendarEvent(
      id: doc.id,
      title: readString(d['title'], 'Event'),
      start: readDate(d['start']) ?? DateTime.now(),
      end: readDate(d['end']),
      allDay: d['allDay'] != false,
      classId: readStringOrNull(d['classId']),
      kind: EventKind.parse(d['kind']),
      location: readString(d['location']),
      notes: readString(d['notes']),
    );
  }

  Json toMap() => {
        'title': title.trim(),
        'start': Timestamp.fromDate(start),
        'end': end == null ? null : Timestamp.fromDate(end!),
        'allDay': allDay,
        'classId': classId,
        'kind': kind.name,
        'location': location.trim(),
        'notes': notes.trim(),
      };
}
