import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';

/// Calendar → Add event (`calendarEvents`).
class CalendarRepository {
  CalendarRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Json> get _events => _db.collection('calendarEvents');

  Stream<List<CalendarEvent>> watchEvents() => _events
      .where('teacherId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(CalendarEvent.fromDoc).toList());

  Future<void> save(CalendarEvent e) async {
    final data = {...e.toMap(), 'teacherId': uid};
    if (e.id.isEmpty) {
      await _events.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _events.doc(e.id).update(data);
    }
  }

  Future<void> delete(String id) => _events.doc(id).delete();
}
