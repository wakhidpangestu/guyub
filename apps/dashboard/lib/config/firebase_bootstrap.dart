import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'env.dart';

/// Thrown when the app was built without the Firebase keys it needs.
class FirebaseConfigException implements Exception {
  const FirebaseConfigException(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() => 'Missing Firebase config: ${missingKeys.join(', ')}';
}

/// Initializes Firebase and, in emulator mode, points every SDK at the local
/// emulators. Ports match `firebase.json`.
Future<void> initFirebase() async {
  final missing = Env.missingKeys();
  if (missing.isNotEmpty) throw FirebaseConfigException(missing);

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: Env.apiKey,
      appId: Env.appId,
      messagingSenderId: Env.messagingSenderId,
      projectId: Env.projectId,
      authDomain: Env.authDomain.isEmpty ? null : Env.authDomain,
      storageBucket: Env.storageBucket.isEmpty ? null : Env.storageBucket,
    ),
  );

  if (Env.useEmulators) {
    const host = Env.emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: Env.functionsRegion).useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }
}
