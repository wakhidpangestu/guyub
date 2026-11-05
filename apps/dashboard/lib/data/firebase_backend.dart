import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/user_role.dart';
import '../config/env.dart';
import 'backend.dart';
import 'models.dart';

typedef _Doc = DocumentSnapshot<Map<String, dynamic>>;

class FirebaseBackend implements Backend {
  FirebaseBackend({FirebaseFirestore? firestore, FirebaseFunctions? functions, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: Env.functionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _orgs => _db.collection('organizations');
  CollectionReference<Map<String, dynamic>> get _events => _db.collection('events');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const BackendFailure('Your session ended. Please sign in again.');
    return uid;
  }

  // ---- Organizations ------------------------------------------------------

  @override
  Stream<List<Organization>> watchOrganizations() =>
      _orgs.orderBy('name').snapshots().map((s) => s.docs.map(_organization).toList()).mapErrors();

  @override
  Stream<Organization?> watchOrganization(String orgId) =>
      _orgs.doc(orgId).snapshots().map((d) => d.exists ? _organization(d) : null).mapErrors();

  @override
  Future<void> createOrganization({required String name, required String slug}) => _guard(() async {
        final ref = _orgs.doc(slug);
        await _db.runTransaction((tx) async {
          if ((await tx.get(ref)).exists) {
            throw BackendFailure('An organization with the ID "$slug" already exists.');
          }
          tx.set(ref, {
            'name': name.trim(),
            'slug': slug,
            'status': 'active',
            'created_by': _uid,
            'created_at': FieldValue.serverTimestamp(),
          });
        });
      });

  // ---- Members and invites ------------------------------------------------

  @override
  Stream<List<Member>> watchMembers(String orgId, UserRole role) => _db
      .collection('users')
      .where('organization_id', isEqualTo: orgId)
      .where('role', isEqualTo: role.claim)
      .snapshots()
      .map((s) => s.docs.map(_member).toList()..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase())))
      .mapErrors();

  @override
  Stream<List<Invite>> watchInvites(String orgId, UserRole role) => _db
      .collection('invites')
      .where('organization_id', isEqualTo: orgId)
      .where('role', isEqualTo: role.claim)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Invite(email: d.id, role: role, orgId: orgId))
          .toList()
        ..sort((a, b) => a.email.compareTo(b.email)))
      .mapErrors();

  @override
  Future<InviteOutcome> inviteMember({required String email, required UserRole role, required String orgId}) =>
      _guard(() async {
        final result = await _functions
            .httpsCallable('inviteMember')
            .call<Map<String, dynamic>>({'email': email, 'role': role.claim, 'orgId': orgId});
        return result.data['status'] == 'granted' ? InviteOutcome.granted : InviteOutcome.invited;
      });

  @override
  Future<void> removeMember(String uid) =>
      _guard(() => _functions.httpsCallable('removeMember').call<Map<String, dynamic>>({'uid': uid}));

  @override
  Future<void> cancelInvite(String email) => _guard(() => _db.collection('invites').doc(email).delete());

  // ---- Events -------------------------------------------------------------

  @override
  Stream<List<GuyubEvent>> watchEvents(String orgId) => _events
      .where('organization_id', isEqualTo: orgId)
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map(_event).toList())
      .mapErrors();

  @override
  Stream<GuyubEvent?> watchEvent(String eventId) =>
      _events.doc(eventId).snapshots().map((d) => d.exists ? _event(d) : null).mapErrors();

  @override
  Future<String> createEvent(String orgId, EventDraft draft) => _guard(() async {
        final ref = await _events.add({
          ..._draftFields(draft),
          'organization_id': orgId,
          'status': EventStatus.draft.name,
          'registration_open': false,
          'created_by': _uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        return ref.id;
      });

  @override
  Future<void> updateEvent(String eventId, EventDraft draft) => _guard(
        () => _events.doc(eventId).update({..._draftFields(draft), 'updated_at': FieldValue.serverTimestamp()}),
      );

  @override
  Future<void> setEventStatus(String eventId, EventStatus status, {required bool registrationOpen}) => _guard(
        () => _events.doc(eventId).update({
          'status': status.name,
          'registration_open': registrationOpen,
          'updated_at': FieldValue.serverTimestamp(),
        }),
      );

  /// Firestore does not delete subcollections, so assignments go in the same
  /// batch. The batch fails as a whole if the event is no longer a draft.
  @override
  Future<void> deleteEvent(String eventId) => _guard(() async {
        final event = _events.doc(eventId);
        final assignments = await event.collection('committees').get();
        final batch = _db.batch();
        for (final doc in assignments.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(event);
        await batch.commit();
      });

  Map<String, dynamic> _draftFields(EventDraft draft) => {
        'title': draft.title.trim(),
        'description': draft.description.trim(),
        'location': draft.location.trim(),
        'date': Timestamp.fromDate(draft.date),
        'capacity': draft.capacity,
      };

  // ---- Committee assignment -----------------------------------------------

  @override
  Stream<List<Assignment>> watchAssignments(String eventId) => _events
      .doc(eventId)
      .collection('committees')
      .snapshots()
      .map((s) => s.docs
          .map((d) => Assignment(
                uid: d.id,
                displayName: d.data()['display_name'] as String?,
                email: d.data()['email'] as String?,
              ))
          .toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase())))
      .mapErrors();

  @override
  Future<void> assignCommittee(String eventId, Member member) => _guard(
        () => _events.doc(eventId).collection('committees').doc(member.uid).set({
          'uid': member.uid,
          'organization_id': member.orgId,
          'display_name': member.displayName,
          'email': member.email,
          'assigned_by': _uid,
          'assigned_at': FieldValue.serverTimestamp(),
        }),
      );

  @override
  Future<void> unassignCommittee(String eventId, String uid) =>
      _guard(() => _events.doc(eventId).collection('committees').doc(uid).delete());

  /// Assignment documents live under each event; their parent is the event.
  /// An event that cannot be read (deleted, or access lost) is skipped.
  @override
  Stream<List<GuyubEvent>> watchAssignedEvents(String uid) => _db
      .collectionGroup('committees')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .asyncMap((snapshot) async {
        final events = await Future.wait(snapshot.docs.map((doc) async {
          try {
            final event = await doc.reference.parent.parent!.get();
            return event.exists ? _event(event) : null;
          } on FirebaseException {
            return null;
          }
        }));
        return events.whereType<GuyubEvent>().toList()..sort((a, b) => a.date.compareTo(b.date));
      })
      .mapErrors();

  // ---- Attendee -----------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _attendance => _db.collection('attendance');

  /// Needs the (status, date) composite index in firestore.indexes.json.
  @override
  Stream<List<GuyubEvent>> watchUpcomingEvents() {
    final startOfToday = startOfTodayWib(DateTime.now());
    return _events
        .where('status', isEqualTo: EventStatus.active.name)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .orderBy('date')
        .snapshots()
        .map((s) => s.docs.map(_event).toList())
        .mapErrors();
  }

  /// A query, not a document read: reading a ticket that does not exist is
  /// denied by the rules (there is no owner to compare against), while a
  /// query filtered on the caller's uid is allowed and returns nothing.
  @override
  Stream<Registration?> watchRegistration(String eventId, String uid) => _attendance
      .where('user_id', isEqualTo: uid)
      .where('event_id', isEqualTo: eventId)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : _registration(s.docs.first))
      .mapErrors();

  @override
  Stream<String?> watchTicketKey(String eventId, String uid) => _db
      .collection('attendance_secrets')
      .doc('${eventId}_$uid')
      .snapshots()
      .map((d) => d.exists ? d.data()!['qr_token'] as String? : null)
      .mapErrors();

  @override
  Stream<List<Ticket>> watchTickets(String uid) => _attendance
      .where('user_id', isEqualTo: uid)
      .snapshots()
      .asyncMap((snapshot) async {
        final tickets = await Future.wait(snapshot.docs.map((doc) async {
          final registration = _registration(doc);
          try {
            final event = await _events.doc(registration.eventId).get();
            return event.exists ? Ticket(registration, _event(event)) : null;
          } on FirebaseException {
            return null;
          }
        }));
        return tickets.whereType<Ticket>().toList()..sort((a, b) => a.event.date.compareTo(b.event.date));
      })
      .mapErrors();

  @override
  Future<RegistrationOutcome> register(String eventId) => _guard(() async {
        final result = await _functions
            .httpsCallable('registerForEvent')
            .call<Map<String, dynamic>>({'eventId': eventId, 'privacyConsent': true});
        return result.data['status'] == 'existing' ? RegistrationOutcome.existing : RegistrationOutcome.registered;
      });

  @override
  Future<void> cancelRegistration(String eventId) =>
      _guard(() => _functions.httpsCallable('cancelRegistration').call<Map<String, dynamic>>({'eventId': eventId}));

  // ---- Mapping ------------------------------------------------------------

  static Registration _registration(_Doc d) {
    final data = d.data()!;
    DateTime? time(Object? value) => value is Timestamp ? value.toDate() : null;
    return Registration(
      eventId: data['event_id'] as String,
      userId: data['user_id'] as String,
      attendeeName: data['attendee_name'] as String?,
      isCheckedIn: data['is_checked_in'] == true,
      registeredAt: time(data['registered_at']),
      checkedInAt: time(data['checked_in_at']),
    );
  }

  static Organization _organization(_Doc d) {
    final data = d.data()!;
    return Organization(id: d.id, name: data['name'] as String? ?? d.id, status: data['status'] as String? ?? 'active');
  }

  static Member _member(_Doc d) {
    final data = d.data()!;
    return Member(
      uid: d.id,
      role: UserRole.fromClaim(data['role']),
      orgId: data['organization_id'] as String?,
      email: data['email'] as String?,
      displayName: data['display_name'] as String?,
    );
  }

  static GuyubEvent _event(_Doc d) {
    final data = d.data()!;
    final date = data['date'];
    return GuyubEvent(
      id: d.id,
      orgId: data['organization_id'] as String,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      date: date is Timestamp ? date.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      capacity: (data['capacity'] as num?)?.toInt(),
      status: EventStatus.parse(data['status']),
      registrationOpen: data['registration_open'] == true,
      registeredCount: (data['registered_count'] as num?)?.toInt() ?? 0,
    );
  }

  // ---- Errors -------------------------------------------------------------

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw toBackendFailure(error);
    }
  }
}

/// Maps Firebase errors to messages a user can act on.
/// Cloud Functions errors already carry a readable message.
BackendFailure toBackendFailure(Object error) {
  if (error is BackendFailure) return error;
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'permission-denied' || 'failed-precondition' || 'invalid-argument' || 'not-found' =>
        BackendFailure(error.message ?? 'The request was rejected.'),
      'unauthenticated' => const BackendFailure('Your session ended. Please sign in again.'),
      'unavailable' || 'deadline-exceeded' => const BackendFailure('The server is not reachable. Try again.'),
      _ => const BackendFailure('Something went wrong on the server. Try again.'),
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => const BackendFailure('You do not have permission to do that.'),
      'not-found' => const BackendFailure('This item no longer exists.'),
      'unavailable' => const BackendFailure('No connection to the database. Check your network.'),
      _ => BackendFailure('Database error (${error.code}). Try again.'),
    };
  }
  return const BackendFailure('Something went wrong. Please try again.');
}

extension _MapErrors<T> on Stream<T> {
  Stream<T> mapErrors() => transform(StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) => sink.addError(toBackendFailure(error), stackTrace),
      ));
}
