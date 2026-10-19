import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Settings page: profile, preferences, password and sign-out.
class SettingsRepository {
  SettingsRepository(this._db, this._auth, this._storage, this._functions, this.uid);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final String uid;

  DocumentReference<Json> get _teacher => _db.collection('teachers').doc(uid);
  DocumentReference<Json> get _prefs => _teacher.collection('settings').doc('preferences');

  Stream<TeacherPreferences> watchPreferences() =>
      _prefs.snapshots().map((d) => TeacherPreferences.fromMap(d.data()));

  Future<void> savePreferences(TeacherPreferences p) => _prefs.set(p.toMap());

  Stream<SchoolSettings> watchSchool() =>
      _db.collection('settings').doc('school').snapshots().map(SchoolSettings.fromDoc);

  Future<void> saveProfile({
    required String displayName,
    required String titleName,
    required String subject,
    required List<int> gradeLevels,
    required String bio,
  }) async {
    final name = displayName.trim();
    await _teacher.update({
      'displayName': name,
      'titleName': titleName.trim(),
      'subject': subject.trim(),
      'gradeLevels': ([...gradeLevels]..sort()),
      'bio': bio.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final user = _auth.currentUser;
    if (user != null && user.displayName != name) await user.updateDisplayName(name);
  }

  /// Uploads a profile photo (JPG/PNG, under 2 MB) and saves its URL.
  Future<void> uploadPhoto({required Uint8List bytes, required String fileName}) async {
    final ext = fileName.split('.').last.toLowerCase();
    final type = ext == 'png' ? 'image/png' : 'image/jpeg';
    final ref = _storage.ref('profile-photos/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: type));
    final url = await ref.getDownloadURL();
    await _teacher.update({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> removePhoto() =>
      _teacher.update({'photoUrl': null, 'updatedAt': FieldValue.serverTimestamp()});

  User? get user => _auth.currentUser;

  /// Re-checks the current password, then sets the new one.
  Future<void> changePassword({required String current, required String next}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw StateError('Not signed in with email.');
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: current));
    await user.updatePassword(next);
  }

  /// Ends every session (other browsers and phones), then this one.
  Future<void> signOutEverywhere() async {
    await _functions.httpsCallable('signOutEverywhere').call<void>();
    await _auth.signOut();
  }
}
