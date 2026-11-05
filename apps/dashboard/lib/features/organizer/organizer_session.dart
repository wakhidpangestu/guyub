import 'package:flutter/widgets.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';

/// The organizer's organization ID from the session claims.
/// Null only if the account has an organizer claim without an org, which
/// `validateRoleInput` in Cloud Functions prevents.
String? organizerOrgId(BuildContext context) {
  final session = AuthScope.of(context).state;
  return session is SignedIn ? session.orgId : null;
}
