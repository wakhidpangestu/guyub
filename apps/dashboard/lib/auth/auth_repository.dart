import 'auth_state.dart';

/// A sign-in failure with a message that is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Source of session state. The Firebase implementation lives in
/// `firebase_auth_repository.dart`; tests use a fake.
abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out, and every ID token refresh.
  Stream<AuthState> watch();

  /// Emits when the user's role was changed server-side, so the ID token
  /// should be refreshed to pick up new claims.
  Stream<void> roleChanged(String uid);

  /// Opens Google Sign-In. Completes normally if the user closes the popup.
  /// Throws [AuthFailure] on any other error.
  Future<void> signInWithGoogle();

  /// Forces an ID token refresh so new custom claims apply.
  Future<void> refreshClaims();

  Future<void> signOut();
}
