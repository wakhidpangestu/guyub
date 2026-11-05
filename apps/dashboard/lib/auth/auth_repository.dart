import 'auth_state.dart';
import 'user_role.dart';

/// A sign-in failure with a message that is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Role and organization as mirrored in `users/{uid}` by Cloud Functions.
/// When this differs from the ID token's claims, the token is stale.
class ProfileRole {
  const ProfileRole(this.role, this.orgId);

  final UserRole role;
  final String? orgId;

  @override
  bool operator ==(Object other) => other is ProfileRole && other.role == role && other.orgId == orgId;

  @override
  int get hashCode => Object.hash(role, orgId);
}

/// Source of session state. The Firebase implementation lives in
/// `firebase_auth_repository.dart`; tests use a fake.
abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out, and every ID token refresh.
  Stream<AuthState> watch();

  /// Emits the role stored in the user's profile document, including the
  /// current value on subscribe.
  Stream<ProfileRole> watchProfileRole(String uid);

  /// Opens Google Sign-In. Completes normally if the user closes the popup.
  /// Throws [AuthFailure] on any other error.
  Future<void> signInWithGoogle();

  /// Forces an ID token refresh so new custom claims apply.
  Future<void> refreshClaims();

  Future<void> signOut();
}
