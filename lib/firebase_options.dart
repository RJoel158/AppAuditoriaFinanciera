// File generated or configured for Firebase initialization.
// Puedes generar este archivo automáticamente ejecutando:
//   flutterfire configure
// O reemplazando los valores de tu consola de Firebase.

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
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSy-YOUR_WEB_API_KEY',
    appId: '1:1234567890:web:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'tu-proyecto-firebase',
    authDomain: 'tu-proyecto-firebase.firebaseapp.com',
    storageBucket: 'tu-proyecto-firebase.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy-YOUR_ANDROID_API_KEY',
    appId: '1:1234567890:android:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'tu-proyecto-firebase',
    storageBucket: 'tu-proyecto-firebase.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSy-YOUR_IOS_API_KEY',
    appId: '1:1234567890:ios:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'tu-proyecto-firebase',
    storageBucket: 'tu-proyecto-firebase.firebasestorage.app',
    iosBundleId: 'com.example.appAuditoriaFinanciera',
  );
}
