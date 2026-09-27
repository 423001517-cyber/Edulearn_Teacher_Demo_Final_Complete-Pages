import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_functions.dart';
import '../data/admin_repository.dart';
import '../data/admin_session.dart';

/// Must match setGlobalOptions({ region }) in firebase/functions/src/shared.ts.
const functionsRegion = 'asia-southeast1';

/// Created in main() (after the first auth check) and injected here.
final adminSessionProvider = Provider<AdminSession>(
  (ref) => throw UnimplementedError('adminSessionProvider is overridden in main()'),
);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(firestoreProvider)),
);

final adminFunctionsProvider = Provider<AdminFunctions>(
  (ref) => AdminFunctions(FirebaseFunctions.instanceFor(region: functionsRegion)),
);

final reportExporterProvider = Provider.autoDispose<ReportExporter>((ref) {
  final uid = ref.watch(adminSessionProvider).user?.uid;
  if (uid == null) throw StateError('Signed out');
  return ReportExporter(FirebaseStorage.instance, uid);
});
