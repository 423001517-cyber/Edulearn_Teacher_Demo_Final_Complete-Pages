import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/classes_repository.dart';
import '../data/dashboard_repository.dart';
import '../data/reports_repository.dart';
import '../data/storage_repository.dart';

// Firebase SDK singletons (override these in tests).
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Only read inside the signed-in shell (the router guarantees a user).
final uidProvider = Provider.autoDispose<String>((ref) {
  final user =
      ref.watch(authStateProvider).valueOrNull ?? ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw StateError('uidProvider read while signed out');
  return user.uid;
});

final dashboardRepositoryProvider = Provider.autoDispose<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(firestoreProvider), ref.watch(uidProvider)),
);

final classesRepositoryProvider = Provider.autoDispose<ClassesRepository>(
  (ref) => ClassesRepository(
    ref.watch(firestoreProvider),
    ref.watch(storageProvider),
    ref.watch(uidProvider),
  ),
);

final reportsRepositoryProvider = Provider.autoDispose<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(firestoreProvider), ref.watch(uidProvider)),
);

final storageRepositoryProvider = Provider.autoDispose<StorageRepository>(
  (ref) => StorageRepository(ref.watch(storageProvider), ref.watch(uidProvider)),
);

final reportExporterProvider = Provider.autoDispose<ReportExporter>(
  (ref) => ReportExporter(ref.watch(storageProvider), ref.watch(uidProvider)),
);

final teacherProvider = StreamProvider.autoDispose<Teacher?>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchTeacher(),
);
