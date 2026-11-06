import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_role.dart';
import '../widgets/page_body.dart';
import 'role_shell.dart';

/// Landing screen of a role's area: the shell around the role's dashboard.
class RoleHome extends StatelessWidget {
  const RoleHome({super.key, required this.role, required this.child});

  final UserRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      role: role,
      child: PageBody(maxWidth: 1240, children: [child]),
    );
  }
}

/// "Welcome back, Rina" for the signed-in person.
String welcomeBack(BuildContext context) {
  final session = AuthScope.of(context).state;
  final name = session is SignedIn ? session.name.trim().split(RegExp(r'\s+')).first : '';
  return name.isEmpty ? 'Welcome back' : 'Welcome back, $name';
}
