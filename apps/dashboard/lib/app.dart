import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
import 'auth/auth_state.dart';
import 'routing/app_router.dart';
import 'ui/theme.dart';

class GuyubApp extends StatefulWidget {
  const GuyubApp({super.key, required this.authController, this.initialLocation});

  final AuthController authController;

  /// Overrides the browser URL. Used by tests.
  final String? initialLocation;

  @override
  State<GuyubApp> createState() => _GuyubAppState();
}

class _GuyubAppState extends State<GuyubApp> {
  late final GoRouter _router = createRouter(widget.authController, initialLocation: widget.initialLocation);

  /// Last seen session, to detect a role change for the same user.
  SignedIn? _lastSession;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_followRoleChange);
  }

  /// When an admin or organizer changes this user's role while the app is
  /// open, move to the new role's dashboard instead of showing "No access".
  void _followRoleChange() {
    final session = widget.authController.state;
    final previous = _lastSession;
    _lastSession = session is SignedIn ? session : null;
    if (session is SignedIn && previous != null && previous.uid == session.uid && previous.role != session.role) {
      _router.go(session.role.homePath);
    }
  }

  @override
  void dispose() {
    widget.authController.removeListener(_followRoleChange);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: widget.authController,
      child: MaterialApp.router(
        title: 'Guyub',
        debugShowCheckedModeBanner: false,
        theme: GuyubTheme.light(),
        darkTheme: GuyubTheme.dark(),
        routerConfig: _router,
      ),
    );
  }
}
