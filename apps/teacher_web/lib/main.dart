import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'providers/core_providers.dart' show functionsRegion;

/// The app talks to the local Firebase emulators when the project is the
/// demo project ("demo-…", see firebase_options.dart) or when started with
///   flutter run -d chrome --dart-define=USE_EMULATORS=true
const _forceEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs on the web (/classes/abc instead of /#/classes/abc).
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final useEmulators =
      _forceEmulators || DefaultFirebaseOptions.currentPlatform.projectId.startsWith('demo-');
  if (useEmulators) {
    // Android emulators reach the host machine through 10.0.2.2.
    // 127.0.0.1 (not "localhost"): the emulators listen on IPv4, and on
    // Windows "localhost" can resolve to IPv6 first. Android emulators reach
    // the computer through 10.0.2.2.
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(host, 5001);
  }

  // Wait for Firebase to restore a saved session so deep links like
  // /classes/rizal-4a don't bounce through the login page on refresh.
  await FirebaseAuth.instance.authStateChanges().first;

  runApp(const ProviderScope(child: EduLearnApp()));
}
