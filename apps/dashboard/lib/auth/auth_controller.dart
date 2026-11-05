import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'auth_state.dart';

/// Holds the current session for the UI and the router.
///
/// Also watches the user's profile document. Cloud Functions mirror the role
/// there after changing claims. When the profile's role differs from the
/// ID token's claims, the token is stale, so the controller refreshes it and
/// the new dashboard opens without signing out.
///
/// Comparing values (instead of reacting to "a change happened") also covers
/// a role applied before the app subscribed, such as an invite picked up at
/// first sign-in.
class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    _stateSub = _repository.watch().listen(_onState, onError: _onStreamError);
  }

  final AuthRepository _repository;
  StreamSubscription<AuthState>? _stateSub;
  StreamSubscription<ProfileRole>? _roleSub;
  String? _watchedUid;
  ProfileRole? _refreshedFor;
  bool _disposed = false;

  AuthState _state = const AuthLoading();
  AuthState get state => _state;

  bool _busy = false;

  /// True while a sign-in, sign-out, or refresh request is running.
  bool get busy => _busy;

  String? _error;

  /// Last user-facing error, cleared when the next action starts.
  String? get error => _error;

  void _onState(AuthState next) {
    _state = next;
    final uid = next is SignedIn ? next.uid : null;
    if (uid != _watchedUid) {
      _roleSub?.cancel();
      _refreshedFor = null;
      _roleSub = uid == null
          ? null
          // A failed listener must not break the session; claims still
          // refresh on the hourly token rotation.
          : _repository.watchProfileRole(uid).listen(_onProfile, onError: (Object _) {});
      _watchedUid = uid;
    }
    _notify();
  }

  void _onProfile(ProfileRole profile) {
    final session = _state;
    if (session is! SignedIn) return;
    if (profile == ProfileRole(session.role, session.orgId)) return;
    // Refresh once per target value. If claims and profile stay apart (for
    // example a failed write), this avoids a refresh loop.
    if (profile == _refreshedFor) return;
    _refreshedFor = profile;
    unawaited(_repository.refreshClaims().catchError((Object _) {}));
  }

  void _onStreamError(Object error) {
    _state = const SignedOut();
    _error = 'Could not load your session. Please sign in again.';
    _notify();
  }

  Future<void> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<void> refreshClaims() => _run(_repository.refreshClaims);

  Future<void> signOut() => _run(_repository.signOut);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
    } on AuthFailure catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _roleSub?.cancel();
    super.dispose();
  }
}
