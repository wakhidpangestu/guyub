import 'dart:async';

import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/data/backend.dart';
import 'package:guyub_dashboard/data/models.dart';

/// In-memory [Backend] for widget tests. Every write notifies all watchers.
/// Mirrors the server rules that the UI relies on (status transitions,
/// draft-only delete, duplicate org IDs, invite vs. grant).
class FakeBackend implements Backend {
  final orgs = <String, Organization>{};
  final events = <String, GuyubEvent>{};

  /// Everyone with a profile, by uid. Attendees have no orgId.
  final people = <String, Member>{};
  final invites = <String, Invite>{};

  /// eventId -> uid -> assignment.
  final assignments = <String, Map<String, Assignment>>{};

  /// attendanceId (`eventId_uid`) -> registration.
  final registrations = <String, Registration>{};

  /// attendanceId -> QR signing key (attendance_secrets).
  final ticketKeys = <String, String>{};

  /// The signed-in user for [register]. Must match the Harness uid and role.
  String currentUid = 'u1';
  UserRole currentRole = UserRole.attendee;

  /// "Today" for [watchUpcomingEvents].
  DateTime today = DateTime(2026, 11, 5);

  /// When set, the next write throws it.
  BackendFailure? failNext;

  final _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  void _changed() => _changes.add(null);

  void _maybeFail() {
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
  }

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  // ---- Seeding helpers for tests -------------------------------------------

  void addPerson(String uid, {required UserRole role, String? orgId, String? email, String? name}) {
    people[uid] = Member(uid: uid, role: role, orgId: orgId, email: email ?? '$uid@example.com', displayName: name);
  }

  GuyubEvent addEvent(
    String id,
    String orgId, {
    String title = 'Event',
    EventStatus status = EventStatus.draft,
    DateTime? date,
    bool registrationOpen = false,
    int? capacity,
    int registeredCount = 0,
  }) {
    final event = GuyubEvent(
      id: id,
      orgId: orgId,
      title: title,
      date: date ?? DateTime(2026, 12, 1, 9),
      status: status,
      registrationOpen: registrationOpen,
      capacity: capacity,
      registeredCount: registeredCount,
    );
    events[id] = event;
    return event;
  }

  Registration addRegistration(String eventId, {String? uid, bool checkedIn = false, bool withKey = true, String? name}) {
    final registration = Registration(
      eventId: eventId,
      userId: uid ?? currentUid,
      attendeeName: name,
      isCheckedIn: checkedIn,
    );
    registrations[registration.attendanceId] = registration;
    if (withKey) ticketKeys[registration.attendanceId] = 'token-$eventId';
    return registration;
  }

  // ---- Organizations -------------------------------------------------------

  @override
  Stream<List<Organization>> watchOrganizations() =>
      _watch(() => orgs.values.toList()..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Stream<Organization?> watchOrganization(String orgId) => _watch(() => orgs[orgId]);

  @override
  Future<void> createOrganization({required String name, required String slug}) async {
    _maybeFail();
    if (orgs.containsKey(slug)) throw BackendFailure('An organization with the ID "$slug" already exists.');
    orgs[slug] = Organization(id: slug, name: name.trim());
    _changed();
  }

  // ---- Members -------------------------------------------------------------

  @override
  Stream<List<Member>> watchMembers(String orgId, UserRole role) =>
      _watch(() => people.values.where((m) => m.orgId == orgId && m.role == role).toList());

  @override
  Stream<List<Invite>> watchInvites(String orgId, UserRole role) =>
      _watch(() => invites.values.where((i) => i.orgId == orgId && i.role == role).toList());

  @override
  Future<InviteOutcome> inviteMember({required String email, required UserRole role, required String orgId}) async {
    _maybeFail();
    final existing = people.values.where((m) => m.email == email).firstOrNull;
    if (existing != null) {
      people[existing.uid] =
          Member(uid: existing.uid, role: role, orgId: orgId, email: existing.email, displayName: existing.displayName);
      _changed();
      return InviteOutcome.granted;
    }
    invites[email] = Invite(email: email, role: role, orgId: orgId);
    _changed();
    return InviteOutcome.invited;
  }

  @override
  Future<void> removeMember(String uid) async {
    _maybeFail();
    final member = people[uid]!;
    people[uid] = Member(uid: uid, role: UserRole.attendee, email: member.email, displayName: member.displayName);
    for (final perEvent in assignments.values) {
      perEvent.remove(uid);
    }
    _changed();
  }

  @override
  Future<void> cancelInvite(String email) async {
    _maybeFail();
    invites.remove(email);
    _changed();
  }

  // ---- Events --------------------------------------------------------------

  @override
  Stream<List<GuyubEvent>> watchEvents(String orgId) =>
      _watch(() => events.values.where((e) => e.orgId == orgId).toList()..sort((a, b) => a.date.compareTo(b.date)));

  @override
  Stream<GuyubEvent?> watchEvent(String eventId) => _watch(() => events[eventId]);

  @override
  Future<String> createEvent(String orgId, EventDraft draft) async {
    _maybeFail();
    final id = 'evt${_nextId++}';
    events[id] = GuyubEvent(
      id: id,
      orgId: orgId,
      title: '',
      date: draft.date,
      status: EventStatus.draft,
      registrationOpen: false,
    ).withDraft(draft);
    _changed();
    return id;
  }

  @override
  Future<void> updateEvent(String eventId, EventDraft draft) async {
    _maybeFail();
    events[eventId] = events[eventId]!.withDraft(draft);
    _changed();
  }

  @override
  Future<void> setEventStatus(String eventId, EventStatus status, {required bool registrationOpen}) async {
    _maybeFail();
    final event = events[eventId]!;
    if (!event.status.canBecome(status)) throw const BackendFailure('You do not have permission to do that.');
    events[eventId] = event.withStatus(status, registrationOpen: registrationOpen);
    _changed();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _maybeFail();
    final event = events[eventId];
    if (event?.status != EventStatus.draft || event!.registeredCount > 0) {
      throw const BackendFailure('You do not have permission to do that.');
    }
    events.remove(eventId);
    assignments.remove(eventId);
    _changed();
  }

  // ---- Committee assignment ------------------------------------------------

  @override
  Stream<List<Assignment>> watchAssignments(String eventId) =>
      _watch(() => (assignments[eventId] ?? const {}).values.toList());

  @override
  Future<void> assignCommittee(String eventId, Member member) async {
    _maybeFail();
    assignments.putIfAbsent(eventId, () => {})[member.uid] =
        Assignment(uid: member.uid, displayName: member.displayName, email: member.email);
    _changed();
  }

  @override
  Future<void> unassignCommittee(String eventId, String uid) async {
    _maybeFail();
    assignments[eventId]?.remove(uid);
    _changed();
  }

  @override
  Stream<List<GuyubEvent>> watchAssignedEvents(String uid) => _watch(() => [
        for (final entry in assignments.entries)
          if (entry.value.containsKey(uid) && events.containsKey(entry.key)) events[entry.key]!,
      ]..sort((a, b) => a.date.compareTo(b.date)));

  // ---- Attendee ------------------------------------------------------------

  @override
  Stream<List<GuyubEvent>> watchUpcomingEvents() => _watch(() {
        final start = DateTime(today.year, today.month, today.day);
        return events.values.where((e) => e.status == EventStatus.active && !e.date.isBefore(start)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      });

  @override
  Stream<Registration?> watchRegistration(String eventId, String uid) => _watch(() => registrations['${eventId}_$uid']);

  @override
  Stream<String?> watchTicketKey(String eventId, String uid) => _watch(() => ticketKeys['${eventId}_$uid']);

  @override
  Stream<List<Ticket>> watchTickets(String uid) => _watch(() => [
        for (final registration in registrations.values)
          if (registration.userId == uid && events.containsKey(registration.eventId))
            Ticket(registration, events[registration.eventId]!),
      ]..sort((a, b) => a.event.date.compareTo(b.event.date)));

  /// Same decisions as decideRegistration in functions/src/registration.ts.
  @override
  Future<RegistrationOutcome> register(String eventId) async {
    _maybeFail();
    if (currentRole != UserRole.attendee) throw const BackendFailure('Only attendee accounts can register for events.');
    final id = '${eventId}_$currentUid';
    if (registrations.containsKey(id)) return RegistrationOutcome.existing;
    final event = events[eventId];
    if (event == null || event.status != EventStatus.active || !event.registrationOpen) {
      throw const BackendFailure('Registration for this event is closed.');
    }
    if (event.isFull) throw const BackendFailure('This event is full.');
    addRegistration(eventId);
    events[eventId] = event.withRegisteredCount(event.registeredCount + 1);
    _changed();
    return RegistrationOutcome.registered;
  }

  @override
  Future<void> cancelRegistration(String eventId) async {
    _maybeFail();
    final id = '${eventId}_$currentUid';
    final registration = registrations[id];
    if (registration == null) throw const BackendFailure('You are not registered for this event.');
    if (registration.isCheckedIn) {
      throw const BackendFailure('You have already checked in, so the registration cannot be cancelled.');
    }
    registrations.remove(id);
    ticketKeys.remove(id);
    final event = events[eventId];
    if (event != null) events[eventId] = event.withRegisteredCount(event.registeredCount - 1);
    _changed();
  }
}
