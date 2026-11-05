import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/auth/auth_state.dart';
import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/routing/redirect.dart';

String? go(AuthState auth, String location) => resolveRedirect(auth, Uri.parse(location));

SignedIn as(UserRole role) => SignedIn(uid: 'u1', role: role, orgId: 'himatif');

/// Checks path and `from` query separately, so encoding does not matter.
void expectTarget(String? actual, String path, {String? from}) {
  expect(actual, isNotNull, reason: 'expected a redirect to $path');
  final uri = Uri.parse(actual!);
  expect(uri.path, path);
  expect(uri.queryParameters['from'], from);
}

void main() {
  group('while loading', () {
    test('waits on splash and remembers the target', () {
      expectTarget(go(const AuthLoading(), '/organizer'), '/splash', from: '/organizer');
    });

    test('stays on splash', () {
      expect(go(const AuthLoading(), '/splash?from=/organizer'), isNull);
    });

    test('root goes to splash without a target', () {
      expectTarget(go(const AuthLoading(), '/'), '/splash');
    });
  });

  group('signed out', () {
    test('protected page goes to login with the target', () {
      expectTarget(go(const SignedOut(), '/admin'), '/login', from: '/admin');
    });

    test('target survives the splash step', () {
      expectTarget(go(const SignedOut(), '/splash?from=/committee'), '/login', from: '/committee');
    });

    test('stays on login', () {
      expect(go(const SignedOut(), '/login'), isNull);
    });

    test('forbidden page is not remembered as a target', () {
      expectTarget(go(const SignedOut(), '/forbidden?from=/admin'), '/login');
    });
  });

  group('signed in', () {
    for (final role in UserRole.values) {
      test('${role.claim} lands on ${role.homePath} from root', () {
        expect(go(as(role), '/'), role.homePath);
      });

      test('${role.claim} may open own area', () {
        expect(go(as(role), role.homePath), isNull);
        expect(go(as(role), '${role.homePath}/anything'), isNull);
      });

      for (final other in UserRole.values.where((r) => r != role)) {
        test('${role.claim} is blocked from ${other.homePath}', () {
          expectTarget(go(as(role), other.homePath), '/forbidden', from: other.homePath);
        });
      }
    }

    test('returns to the remembered target after login', () {
      expect(go(as(UserRole.organizer), '/login?from=/organizer/events'), '/organizer/events');
    });

    test('ignores a remembered target owned by another role', () {
      expect(go(as(UserRole.organizer), '/login?from=/admin'), '/organizer');
    });

    test('ignores an off-site target', () {
      expect(go(as(UserRole.attendee), '/login?from=//evil.example'), '/attendee');
    });

    test('stays on the forbidden page', () {
      expect(go(as(UserRole.committee), '/forbidden?from=/admin'), isNull);
    });

    test('unknown paths fall through to the not-found page', () {
      expect(go(as(UserRole.attendee), '/does-not-exist'), isNull);
    });
  });
}
