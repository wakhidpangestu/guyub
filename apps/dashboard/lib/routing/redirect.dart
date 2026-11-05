import '../auth/auth_state.dart';
import '../auth/user_role.dart';

abstract final class Routes {
  static const root = '/';
  static const splash = '/splash';
  static const login = '/login';
  static const forbidden = '/forbidden';

  /// Paths that never make sense as a "return to" target.
  static const _transient = {root, splash, login, forbidden};
}

/// Decides where navigation should go for the current session.
///
/// Pure function so every case is unit-tested (see test/routing).
/// The router is a UX guard only. Firestore and Storage rules enforce access.
///
/// - Loading: wait on /splash, remember the target in `?from=`.
/// - Signed out: go to /login, remember the target.
/// - Signed in on /, /splash, or /login: go to the remembered target if this
///   role may open it, else to the role's home.
/// - Signed in on another role's area: go to /forbidden.
String? resolveRedirect(AuthState auth, Uri uri) {
  final path = uri.path;
  return switch (auth) {
    AuthLoading() => path == Routes.splash ? null : _withFrom(Routes.splash, _intended(uri)),
    SignedOut() => path == Routes.login ? null : _withFrom(Routes.login, _intended(uri)),
    SignedIn(:final role) => _signedIn(role, uri),
  };
}

String? _signedIn(UserRole role, Uri uri) {
  final path = uri.path;

  if (path == Routes.root || path == Routes.splash || path == Routes.login) {
    final from = _safeTarget(uri.queryParameters['from']);
    if (from != null) {
      final owner = UserRole.owningArea(Uri.parse(from).path);
      if (owner == role) return from;
    }
    return role.homePath;
  }

  final owner = UserRole.owningArea(path);
  if (owner != null && owner != role) return _withFrom(Routes.forbidden, uri.toString());
  return null;
}

/// The location the user was trying to reach, carried across splash/login.
String? _intended(Uri uri) {
  if (uri.path == Routes.splash || uri.path == Routes.login) {
    return _safeTarget(uri.queryParameters['from']);
  }
  return _safeTarget(uri.toString());
}

/// Only same-app absolute paths. Rejects `//host` (open redirect) and
/// transient pages, which would cause loops.
String? _safeTarget(String? target) {
  if (target == null || !target.startsWith('/') || target.startsWith('//')) return null;
  if (Routes._transient.contains(Uri.parse(target).path)) return null;
  return target;
}

String _withFrom(String path, String? from) =>
    from == null ? path : Uri(path: path, queryParameters: {'from': from}).toString();
