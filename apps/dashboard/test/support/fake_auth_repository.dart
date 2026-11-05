import 'dart:async';

import 'package:guyub_dashboard/auth/auth_repository.dart';
import 'package:guyub_dashboard/auth/auth_state.dart';

/// In-memory [AuthRepository]. Tests push states with [emit].
class FakeAuthRepository implements AuthRepository {
  final _states = StreamController<AuthState>.broadcast();
  final _roleChanges = StreamController<void>.broadcast();

  int signInCalls = 0;
  int refreshCalls = 0;
  int signOutCalls = 0;

  /// When set, [signInWithGoogle] throws it.
  AuthFailure? signInFailure;

  /// Uid passed to the most recent [roleChanged] subscription.
  String? watchedRoleUid;

  void emit(AuthState state) => _states.add(state);

  void emitRoleChanged() => _roleChanges.add(null);

  @override
  Stream<AuthState> watch() => _states.stream;

  @override
  Stream<void> roleChanged(String uid) {
    watchedRoleUid = uid;
    return _roleChanges.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    signInCalls++;
    if (signInFailure case final failure?) throw failure;
  }

  @override
  Future<void> refreshClaims() async => refreshCalls++;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(const SignedOut());
  }
}
