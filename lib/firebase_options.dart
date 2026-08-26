// Placeholder Firebase configuration.
//
// This file must be replaced with real values before the app will work.
// Easiest way: `dart pub global activate flutterfire_cli` then run
// `flutterfire configure` in the project root (requires your own Google
// login, which this generation environment did not have). Otherwise copy
// the values by hand from Firebase Console -> Project Settings.
//
// See README.md for the full step-by-step setup.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_WEB_API_KEY',
    appId: 'REPLACE_WITH_YOUR_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    authDomain: 'REPLACE_WITH_YOUR_PROJECT_ID.firebaseapp.com',
    databaseURL: 'https://REPLACE_WITH_YOUR_PROJECT_ID-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_YOUR_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    databaseURL: 'https://REPLACE_WITH_YOUR_PROJECT_ID-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
  );
}
