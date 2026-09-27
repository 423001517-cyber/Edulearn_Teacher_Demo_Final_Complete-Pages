import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum AdminAccess { unknown, signedOut, admin, notAdmin }

/// Who is signed in, and whether their ID token carries the `admin` role
/// (set by the setAdminRole Cloud Function or tools/seed). The router
/// listens to this to guard every page.
class AdminSession extends ChangeNotifier {
  AdminSession(this._auth) {
    _sub = _auth.idTokenChanges().listen(_onUser);
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _sub;
  final _ready = Completer<void>();

  AdminAccess access = AdminAccess.unknown;
  User? user;

  Future<void> get ready => _ready.future;
  bool get isAdmin => access == AdminAccess.admin;

  Future<void> _onUser(User? u) async {
    user = u;
    if (u == null) {
      access = AdminAccess.signedOut;
    } else {
      try {
        final token = await u.getIdTokenResult();
        if (_auth.currentUser?.uid != u.uid) return; // signed out meanwhile
        access = token.claims?['role'] == 'admin' ? AdminAccess.admin : AdminAccess.notAdmin;
      } catch (_) {
        access = AdminAccess.notAdmin;
      }
    }
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  /// Picks up a role that was just granted (forces a fresh ID token).
  Future<void> refreshRole() async {
    final u = _auth.currentUser;
    if (u == null) return;
    await u.getIdToken(true);
    await _onUser(u);
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
