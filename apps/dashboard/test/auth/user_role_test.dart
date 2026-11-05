import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/auth/user_role.dart';

void main() {
  test('parses every claim value', () {
    for (final role in UserRole.values) {
      expect(UserRole.fromClaim(role.claim), role);
    }
  });

  test('missing or unknown claim means attendee, like the security rules', () {
    expect(UserRole.fromClaim(null), UserRole.attendee);
    expect(UserRole.fromClaim('superuser'), UserRole.attendee);
    expect(UserRole.fromClaim(42), UserRole.attendee);
  });

  test('owningArea matches the area root and its children only', () {
    expect(UserRole.owningArea('/admin'), UserRole.admin);
    expect(UserRole.owningArea('/admin/orgs'), UserRole.admin);
    expect(UserRole.owningArea('/administrator'), isNull);
    expect(UserRole.owningArea('/login'), isNull);
  });
}
