import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication (email/password + Google) and the teacher profile.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _ensureProfile(cred.user!);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(name.trim());
    await _ensureProfile(cred.user!, name: name.trim());
  }

  /// Popup on web; native provider flow on Android/iOS.
  /// Enable "Google" under Authentication > Sign-in method first.
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..addScope('email');
    final cred = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    await _ensureProfile(cred.user!);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Creates `teachers/{uid}` on first sign-in.
  Future<void> _ensureProfile(User user, {String? name}) async {
    final ref = _db.collection('teachers').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'displayName': name ?? user.displayName ?? user.email?.split('@').first ?? 'Teacher',
      'email': user.email,
      'photoUrl': user.photoURL,
      'role': 'teacher',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
