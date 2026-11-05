import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';
import 'auth_state.dart';
import 'user_role.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<AuthState> watch() => _auth.idTokenChanges().asyncMap(_toState);

  Future<AuthState> _toState(User? user) async {
    if (user == null) return const SignedOut();
    final token = await user.getIdTokenResult();
    final claims = token.claims ?? const <String, dynamic>{};
    final orgId = claims['orgId'];
    return SignedIn(
      uid: user.uid,
      role: UserRole.fromClaim(claims['role']),
      orgId: orgId is String ? orgId : null,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  /// `applyRole` in Cloud Functions writes `users/{uid}.updated_at` after it
  /// sets claims. A change after the first snapshot means the role changed.
  @override
  Stream<void> roleChanged(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.data()?['updated_at'])
      .distinct()
      .skip(1);

  @override
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    try {
      await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      final message = _messageFor(e.code);
      if (message != null) throw AuthFailure(message);
    }
  }

  @override
  Future<void> refreshClaims() async {
    await _auth.currentUser?.getIdToken(true);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Returns null when the user cancelled, so the UI shows nothing.
  static String? _messageFor(String code) => switch (code) {
        'popup-closed-by-user' || 'cancelled-popup-request' || 'user-cancelled' => null,
        'popup-blocked' => 'Your browser blocked the sign-in popup. Allow popups for this site and try again.',
        'network-request-failed' => 'No connection to the sign-in service. Check your network and try again.',
        'unauthorized-domain' => 'This domain is not allowed to sign in. Add it under Firebase Authentication > Settings > Authorized domains.',
        'operation-not-allowed' => 'Google Sign-In is not enabled for this Firebase project.',
        'user-disabled' => 'This account has been disabled. Contact the Guyub administrator.',
        _ => 'Sign-in failed ($code). Please try again.',
      };
}
