/// Build-time configuration.
///
/// Values come from `--dart-define-from-file=env/<name>.json`.
/// `env/emulator.json` runs against the local Firebase emulators with the
/// `demo-guyub` project, so no real Firebase project is needed for development.
abstract final class Env {
  static const useEmulators = bool.fromEnvironment('USE_EMULATORS');
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

  // Emulator ports. Defaults match firebase.json. env/e2e.json overrides them
  // to match firebase.test.json, so browser tests never touch the dev emulators.
  static const authPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
  static const firestorePort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
  static const functionsPort = int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
  static const storagePort = int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// Must match REGION in functions/src/config.ts.
  static const functionsRegion = String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'asia-southeast2');

  /// Names of required keys that were not provided at build time.
  static List<String> missingKeys() => [
        if (apiKey.isEmpty) 'FIREBASE_API_KEY',
        if (appId.isEmpty) 'FIREBASE_APP_ID',
        if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
        if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      ];
}
