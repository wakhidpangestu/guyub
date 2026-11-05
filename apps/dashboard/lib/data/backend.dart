import '../auth/user_role.dart';
import 'models.dart';

/// An error with a message that is safe to show to the user.
class BackendFailure implements Exception {
  const BackendFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the dashboards read and write. The Firebase implementation is
/// `FirebaseBackend`; widget tests use an in-memory fake.
///
/// Security is enforced server-side by Firestore rules and Cloud Functions.
/// This interface only shapes the calls.
abstract interface class Backend {
  // ---- Organizations (admin) ----------------------------------------
  Stream<List<Organization>> watchOrganizations();

  Stream<Organization?> watchOrganization(String orgId);

  /// Throws [BackendFailure] if the slug is taken.
  Future<void> createOrganization({required String name, required String slug});

  // ---- Members and invites --------------------------------------------
  /// People with [role] in [orgId], sorted by name.
  Stream<List<Member>> watchMembers(String orgId, UserRole role);

  /// Pending invites for [role] in [orgId].
  Stream<List<Invite>> watchInvites(String orgId, UserRole role);

  /// Adds a person by email. See the inviteMember Cloud Function.
  Future<InviteOutcome> inviteMember({required String email, required UserRole role, required String orgId});

  /// Returns the person to the attendee role and removes their assignments.
  Future<void> removeMember(String uid);

  Future<void> cancelInvite(String email);

  // ---- Events (organizer) ---------------------------------------------
  /// Events of [orgId], by date.
  Stream<List<GuyubEvent>> watchEvents(String orgId);

  Stream<GuyubEvent?> watchEvent(String eventId);

  /// Creates a draft and returns its ID.
  Future<String> createEvent(String orgId, EventDraft draft);

  Future<void> updateEvent(String eventId, EventDraft draft);

  Future<void> setEventStatus(String eventId, EventStatus status, {required bool registrationOpen});

  /// Drafts only.
  Future<void> deleteEvent(String eventId);

  // ---- Committee assignment -------------------------------------------
  Stream<List<Assignment>> watchAssignments(String eventId);

  Future<void> assignCommittee(String eventId, Member member);

  Future<void> unassignCommittee(String eventId, String uid);

  /// Events the committee member [uid] is assigned to, by date.
  Stream<List<GuyubEvent>> watchAssignedEvents(String uid);

  // ---- Attendee (M3) --------------------------------------------------
  /// Published events from every organization, from today on, by date.
  Stream<List<GuyubEvent>> watchUpcomingEvents();

  /// The attendee's registration for one event, or null.
  Stream<Registration?> watchRegistration(String eventId, String uid);

  /// The ticket owner's QR signing key, or null if there is none.
  /// Only the owner can read it (attendance_secrets rules).
  Stream<String?> watchTicketKey(String eventId, String uid);

  /// The attendee's tickets with their events, by event date.
  Stream<List<Ticket>> watchTickets(String uid);

  /// Registers the signed-in attendee. The caller must have shown the
  /// privacy notice and received consent.
  Future<RegistrationOutcome> register(String eventId);

  Future<void> cancelRegistration(String eventId);
}
