import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
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

  @override
  void dispose() {
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
