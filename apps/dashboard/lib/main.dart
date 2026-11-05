import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'auth/auth_controller.dart';
import 'auth/firebase_auth_repository.dart';
import 'config/firebase_bootstrap.dart';
import 'data/firebase_backend.dart';
import 'ui/config_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs (/organizer instead of /#/organizer). Firebase Hosting
  // rewrites every path to index.html, see firebase.json.
  usePathUrlStrategy();

  try {
    await initFirebase();
  } on FirebaseConfigException catch (e) {
    runApp(ConfigErrorApp(missingKeys: e.missingKeys));
    return;
  }

  runApp(GuyubApp(authController: AuthController(FirebaseAuthRepository()), backend: FirebaseBackend()));
}
