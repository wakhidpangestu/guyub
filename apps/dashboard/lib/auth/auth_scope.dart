import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Makes the [AuthController] available to every page.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({super.key, required AuthController controller, required super.child})
      : super(notifier: controller);

  /// Returns the controller and rebuilds the caller when the session changes.
  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope above this widget.');
    return scope!.notifier!;
  }

  /// Returns the controller without subscribing. Use in callbacks.
  static AuthController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope above this widget.');
    return scope!.notifier!;
  }
}
