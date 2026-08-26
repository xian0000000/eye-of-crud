// Real Firebase configuration for the "eye-of-curd" project.
//
// Web values copied from Firebase Console -> Project Settings -> Web app.
// Android values copied from android/app/google-services.json.

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
    apiKey: 'AIzaSyDfxu_azbvR1DUaHjcHwc02xyJV1OJRBu0',
    appId: '1:314221901242:web:2a2decd63ee1ce2651d983',
    messagingSenderId: '314221901242',
    projectId: 'eye-of-curd',
    authDomain: 'eye-of-curd.firebaseapp.com',
    databaseURL:
        'https://eye-of-curd-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'eye-of-curd.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCYg1_TsZ9Y3rvj3FkLGwrGQ2K6EGF71rs',
    appId: '1:314221901242:android:37669012ded733ba51d983',
    messagingSenderId: '314221901242',
    projectId: 'eye-of-curd',
    databaseURL:
        'https://eye-of-curd-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'eye-of-curd.firebasestorage.app',
  );
}
