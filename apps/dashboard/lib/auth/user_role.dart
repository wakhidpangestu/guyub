/// Platform roles. The `claim` value matches the `role` custom claim set by
/// the `setUserClaims` Cloud Function and read by Firestore/Storage rules.
enum UserRole {
  admin('admin', '/admin', 'Administrator'),
  organizer('organizer', '/organizer', 'Organizer'),
  committee('committee', '/committee', 'Committee'),
  attendee('attendee', '/attendee', 'Attendee');

  const UserRole(this.claim, this.homePath, this.label);

  final String claim;

  /// Root path of this role's area. Every route under it belongs to this role.
  final String homePath;

  final String label;

  /// Users without a role claim are attendees (fresh Google sign-ups).
  /// This matches the `token.get('role', 'attendee')` default in the rules.
  static UserRole fromClaim(Object? value) =>
      values.firstWhere((role) => role.claim == value, orElse: () => UserRole.attendee);

  /// The role that owns [path], or null for shared paths such as /login.
  static UserRole? owningArea(String path) {
    for (final role in values) {
      if (path == role.homePath || path.startsWith('${role.homePath}/')) return role;
    }
    return null;
  }
}
