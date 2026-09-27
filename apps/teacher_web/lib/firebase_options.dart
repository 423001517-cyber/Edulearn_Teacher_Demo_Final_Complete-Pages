// DEMO SETTINGS — the app runs on your computer with the Firebase emulators
// (project "demo-edulearn"). No Firebase account or internet project needed.
//
// When you're ready to go live with a real Firebase project, run this in
// this app's folder and it will replace this whole file with your keys:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// (Pick the same Firebase project for the teacher and admin websites.)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-edulearn',
    authDomain: 'demo-edulearn.firebaseapp.com',
    storageBucket: 'demo-edulearn.appspot.com',
  );
}
