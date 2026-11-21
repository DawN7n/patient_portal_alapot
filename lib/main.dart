import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';

// Emulators are opt-in in debug builds so normal runs use the shared Firebase project.
// Release builds will never connect to local emulators.
const bool _useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

// Default host for Chrome running on the same computer.
const String _emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect Firebase services to local emulators during development.
  if (kDebugMode && _useFirebaseEmulators) {
    // Firebase Authentication Emulator.
    await FirebaseAuth.instance.useAuthEmulator(
      _emulatorHost,
      9099,
    );

    // Cloud Firestore Emulator.
    FirebaseFirestore.instance.useFirestoreEmulator(
      _emulatorHost,
      8080,
    );

    debugPrint('========================================');
    debugPrint('ALAPOT FIREBASE LOCAL EMULATORS');
    debugPrint('Authentication: $_emulatorHost:9099');
    debugPrint('Firestore: $_emulatorHost:8080');
    debugPrint('========================================');
  }

  // Load saved preferences.
  final prefs = await SharedPreferences.getInstance();
  await ThemeController.load(prefs);

  runApp(AlapotApp(prefs: prefs));
}
