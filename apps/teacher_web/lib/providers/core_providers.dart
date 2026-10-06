import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/calendar_repository.dart';
import '../data/classes_repository.dart';
import '../data/classwork_repository.dart';
import '../data/dashboard_repository.dart';
import '../data/gradebook_repository.dart';
import '../data/reports_repository.dart';
import '../data/storage_repository.dart';
import '../data/submissions_repository.dart';
import '../data/stream_repository.dart';

// Firebase SDK singletons (override these in tests).
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

/// Must match setGlobalOptions({ region }) in firebase/functions/src/shared.ts.
const functionsRegion = 'asia-southeast1';
final functionsProvider =
    Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instanceFor(region: functionsRegion));

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
    ref.watch(functionsProvider),
    ref.watch(uidProvider),
  ),
);

final classworkRepositoryProvider = Provider.autoDispose<ClassworkRepository>(
  (ref) => ClassworkRepository(ref.watch(firestoreProvider), ref.watch(storageProvider), ref.watch(uidProvider)),
);

final submissionsRepositoryProvider = Provider.autoDispose<SubmissionsRepository>(
  (ref) => SubmissionsRepository(ref.watch(firestoreProvider), ref.watch(uidProvider)),
);

final calendarRepositoryProvider = Provider.autoDispose<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(firestoreProvider), ref.watch(uidProvider)),
);

final gradebookRepositoryProvider = Provider.autoDispose<GradebookRepository>(
  (ref) => GradebookRepository(ref.watch(firestoreProvider), ref.watch(uidProvider)),
);

final streamRepositoryProvider = Provider.autoDispose<StreamRepository>(
  (ref) => StreamRepository(ref.watch(firestoreProvider), ref.watch(storageProvider), ref.watch(uidProvider)),
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
