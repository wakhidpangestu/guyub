import 'user_role.dart';

/// Session state as the UI sees it.
sealed class AuthState {
  const AuthState();
}

/// Firebase has not reported the session yet (first frame after load).
final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class SignedOut extends AuthState {
  const SignedOut();
}

final class SignedIn extends AuthState {
  const SignedIn({
    required this.uid,
    required this.role,
    this.orgId,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final UserRole role;

  /// Organization from the `orgId` claim. Only organizer and committee have one.
  final String? orgId;

  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// Best label for the signed-in person.
  String get name => (displayName?.isNotEmpty ?? false) ? displayName! : (email ?? 'Guyub user');
}
