import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/app.dart';
import 'package:guyub_dashboard/auth/auth_controller.dart';
import 'package:guyub_dashboard/auth/auth_state.dart';
import 'package:guyub_dashboard/auth/user_role.dart';

import 'fake_auth_repository.dart';
import 'fake_backend.dart';

/// A running app with fake auth and data.
class Harness {
  Harness._(this.auth, this.backend, this.controller);

  final FakeAuthRepository auth;
  final FakeBackend backend;
  final AuthController controller;

  /// Pumps the app at [at], signed in as [role]. Tears down after the test.
  static Future<Harness> signedIn(
    WidgetTester tester, {
    required UserRole role,
    String? orgId,
    String at = '/',
    FakeBackend? backend,
    String uid = 'u1',
    String name = 'Rina',
  }) async {
    final auth = FakeAuthRepository();
    final controller = AuthController(auth);
    final harness = Harness._(auth, backend ?? FakeBackend(), controller);
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GuyubApp(authController: controller, backend: harness.backend, initialLocation: at));
    await tester.pump();
    auth.emit(SignedIn(uid: uid, role: role, orgId: orgId, displayName: name, email: '$uid@example.com'));
    await tester.pumpAndSettle();
    return harness;
  }
}
