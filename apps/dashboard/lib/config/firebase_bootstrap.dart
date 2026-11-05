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
/// emulators. Ports come from [Env] (defaults match `firebase.json`).
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
    await FirebaseAuth.instance.useAuthEmulator(host, Env.authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, Env.firestorePort);
    FirebaseFunctions.instanceFor(region: Env.functionsRegion).useFunctionsEmulator(host, Env.functionsPort);
    await FirebaseStorage.instance.useStorageEmulator(host, Env.storagePort);
  }
}
