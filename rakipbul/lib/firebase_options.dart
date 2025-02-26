// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCM00LAnwSgRKdny-6dUhYvL1Up_eAA3_M',
    appId: '1:125996850771:web:aba1f7598acaed246e70a6',
    messagingSenderId: '125996850771',
    projectId: 'rakipbul-c86d3',
    authDomain: 'rakipbul-c86d3.firebaseapp.com',
    storageBucket: 'rakipbul-c86d3.firebasestorage.app',
    measurementId: 'G-CGSK0QRJHX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDu1XF0p9X04m_uXBpSlMCf-diGo2SIVxM',
    appId: '1:125996850771:android:ef8dc2ac4c98df3f6e70a6',
    messagingSenderId: '125996850771',
    projectId: 'rakipbul-c86d3',
    storageBucket: 'rakipbul-c86d3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDlh7UnJ2lobUTbJ6epjffg6T559pwh6aI',
    appId: '1:125996850771:ios:b3ff624e94b546166e70a6',
    messagingSenderId: '125996850771',
    projectId: 'rakipbul-c86d3',
    storageBucket: 'rakipbul-c86d3.firebasestorage.app',
    iosBundleId: 'com.example.rakipbul',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDlh7UnJ2lobUTbJ6epjffg6T559pwh6aI',
    appId: '1:125996850771:ios:b3ff624e94b546166e70a6',
    messagingSenderId: '125996850771',
    projectId: 'rakipbul-c86d3',
    storageBucket: 'rakipbul-c86d3.firebasestorage.app',
    iosBundleId: 'com.example.rakipbul',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCM00LAnwSgRKdny-6dUhYvL1Up_eAA3_M',
    appId: '1:125996850771:web:cb7405c21935b97d6e70a6',
    messagingSenderId: '125996850771',
    projectId: 'rakipbul-c86d3',
    authDomain: 'rakipbul-c86d3.firebaseapp.com',
    storageBucket: 'rakipbul-c86d3.firebasestorage.app',
    measurementId: 'G-45DEQFZZQ8',
  );
}
