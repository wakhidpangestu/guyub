/// Build-time configuration.
///
/// Values come from `--dart-define-from-file=env/<name>.json`.
/// `env/emulator.json` runs against the local Firebase emulators with the
/// `demo-guyub` project, so no real Firebase project is needed for development.
abstract final class Env {
  static const useEmulators = bool.fromEnvironment('USE_EMULATORS');
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

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
