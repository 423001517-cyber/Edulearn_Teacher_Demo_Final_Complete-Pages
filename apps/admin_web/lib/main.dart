import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'data/admin_session.dart';
import 'firebase_options.dart';
import 'providers/core_providers.dart';

/// The app talks to the local Firebase emulators when the project is the
/// demo project ("demo-…", see firebase_options.dart) or when started with
///   flutter run -d chrome --dart-define=USE_EMULATORS=true
const _forceEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final useEmulators =
      _forceEmulators || DefaultFirebaseOptions.currentPlatform.projectId.startsWith('demo-');
  if (useEmulators) {
    // 127.0.0.1 (not "localhost"): the emulators listen on IPv4, and on
    // Windows "localhost" can resolve to IPv6 first. Android emulators reach
    // the computer through 10.0.2.2.
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(host, 5001);
  }

  // Resolve "signed in? and an admin?" before the first frame, so deep links
  // like /classes?teacher=… don't bounce through the login page.
  final session = AdminSession(FirebaseAuth.instance);
  await session.ready;

  runApp(ProviderScope(
    overrides: [adminSessionProvider.overrideWithValue(session)],
    child: const AdminApp(),
  ));
}
