import 'dart:async';

import 'package:guyub_dashboard/auth/auth_repository.dart';
import 'package:guyub_dashboard/auth/auth_state.dart';

/// In-memory [AuthRepository]. Tests push states with [emit] and profile
/// roles with [emitProfile].
class FakeAuthRepository implements AuthRepository {
  final _states = StreamController<AuthState>.broadcast();
  final _profiles = StreamController<ProfileRole>.broadcast();

  int signInCalls = 0;
  int refreshCalls = 0;
  int signOutCalls = 0;

  /// When set, [signInWithGoogle] throws it.
  AuthFailure? signInFailure;

  /// Value the profile already has when the app subscribes.
  ProfileRole? initialProfile;

  /// Uid passed to the most recent [watchProfileRole] subscription.
  String? watchedProfileUid;

  void emit(AuthState state) => _states.add(state);

  void emitProfile(ProfileRole profile) => _profiles.add(profile);

  @override
  Stream<AuthState> watch() => _states.stream;

  /// Not an async* generator: those schedule work in the zone that subscribed,
  /// which can be outside the widget test's fake-async zone.
  @override
  Stream<ProfileRole> watchProfileRole(String uid) {
    watchedProfileUid = uid;
    final initial = initialProfile;
    return Stream<ProfileRole>.multi((controller) {
      if (initial != null) controller.add(initial);
      final sub = _profiles.stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
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
