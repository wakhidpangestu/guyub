import 'package:flutter/widgets.dart';

import 'auth_scope.dart';
import 'auth_state.dart';

/// The signed-in session, or null while loading or signed out.
/// Pages under a role's area always have one (the router guarantees it).
SignedIn? currentSession(BuildContext context) {
  final state = AuthScope.of(context).state;
  return state is SignedIn ? state : null;
}
