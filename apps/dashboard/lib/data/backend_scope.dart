import 'package:flutter/widgets.dart';

import 'backend.dart';

/// Makes the [Backend] available to every page.
class BackendScope extends InheritedWidget {
  const BackendScope({super.key, required this.backend, required super.child});

  final Backend backend;

  static Backend of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<BackendScope>();
    assert(scope != null, 'No BackendScope above this widget.');
    return scope!.backend;
  }

  @override
  bool updateShouldNotify(BackendScope oldWidget) => backend != oldWidget.backend;
}
