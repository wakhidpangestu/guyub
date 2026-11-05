// Domain models. Pure Dart: Firestore mapping lives in firebase_backend.dart.
// Field limits mirror isValidEvent / organizations rules in firestore.rules.

import '../auth/user_role.dart';

class Organization {
  const Organization({required this.id, required this.name, this.status = 'active'});

  /// Also the slug.
  final String id;
  final String name;
  final String status;

  static const nameMin = 2;
  static const nameMax = 80;
  static final slugPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,39}$');

  static String? nameError(String value) {
    final name = value.trim();
    if (name.length < nameMin) return 'Enter at least $nameMin characters.';
    if (name.length > nameMax) return 'Use at most $nameMax characters.';
    return null;
  }

  static String? slugError(String value) {
    if (!slugPattern.hasMatch(value)) {
      return 'Use 2 to 40 lowercase letters, numbers, or dashes. Start with a letter or number.';
    }
    return null;
  }
}

/// Midnight today in WIB (UTC+7, no daylight saving), as a UTC instant.
/// "Upcoming" uses this boundary for every viewer, so attendees in WITA or
/// WIT, or with a wrong device clock zone, see the same list (audit L5).
DateTime startOfTodayWib(DateTime now) {
  const offset = Duration(hours: 7);
  final wib = now.toUtc().add(offset);
  return DateTime.utc(wib.year, wib.month, wib.day).subtract(offset);
}

/// Turns a display name into an organization ID, for example
/// "HIMATIF ITB 2026" becomes "himatif-itb-2026".
String slugify(String name) {
  var slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 40) slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  return slug;
}

enum EventStatus {
  draft('Draft'),
  active('Published'),
  completed('Completed');

  const EventStatus(this.label);

  final String label;

  static EventStatus parse(Object? value) =>
      values.firstWhere((status) => status.name == value, orElse: () => EventStatus.draft);

  /// draft <-> active, active -> completed. Completed is final.
  /// Same rule as isValidTransition in firestore.rules.
  bool canBecome(EventStatus next) =>
      next == this ||
      (this == draft && next == active) ||
      (this == active && (next == draft || next == completed));
}

class GuyubEvent {
  const GuyubEvent({
    required this.id,
    required this.orgId,
    required this.title,
    required this.date,
    required this.status,
    required this.registrationOpen,
    this.description = '',
    this.location = '',
    this.capacity,
    this.registeredCount = 0,
  });

  final String id;
  final String orgId;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final int? capacity;
  final EventStatus status;
  final bool registrationOpen;

  /// Maintained by the registerForEvent and cancelRegistration functions.
  final int registeredCount;

  bool get isFull => capacity != null && registeredCount >= capacity!;

  /// Null when there is no capacity limit.
  int? get spotsLeft => capacity == null ? null : (capacity! - registeredCount).clamp(0, capacity!);

  /// Whether a new attendee could register right now (the server decides for real).
  bool get acceptsRegistrations => status == EventStatus.active && registrationOpen && !isFull;

  EventDraft toDraft() =>
      EventDraft(title: title, description: description, location: location, date: date, capacity: capacity);

  /// Applies edited details, keeping status and registration.
  GuyubEvent withDraft(EventDraft draft) => GuyubEvent(
        id: id,
        orgId: orgId,
        title: draft.title.trim(),
        description: draft.description.trim(),
        location: draft.location.trim(),
        date: draft.date,
        capacity: draft.capacity,
        status: status,
        registrationOpen: registrationOpen,
        registeredCount: registeredCount,
      );

  GuyubEvent withStatus(EventStatus next, {required bool registrationOpen}) => GuyubEvent(
        id: id,
        orgId: orgId,
        title: title,
        description: description,
        location: location,
        date: date,
        capacity: capacity,
        status: next,
        registrationOpen: registrationOpen,
        registeredCount: registeredCount,
      );

  GuyubEvent withRegisteredCount(int count) => GuyubEvent(
        id: id,
        orgId: orgId,
        title: title,
        description: description,
        location: location,
        date: date,
        capacity: capacity,
        status: status,
        registrationOpen: registrationOpen,
        registeredCount: count,
      );
}

/// An attendee's registration for one event.
///
/// The QR signing key is not here: it lives in attendance_secrets, readable
/// only by the ticket owner (see [Backend.watchTicketKey], audit H2).
class Registration {
  const Registration({
    required this.eventId,
    required this.userId,
    this.attendeeName,
    this.isCheckedIn = false,
    this.registeredAt,
    this.checkedInAt,
  });

  final String eventId;
  final String userId;
  final String? attendeeName;
  final bool isCheckedIn;
  final DateTime? registeredAt;
  final DateTime? checkedInAt;

  String get attendanceId => '${eventId}_$userId';

  String get label => (attendeeName?.isNotEmpty ?? false) ? attendeeName! : 'Attendee';
}

/// A registration with its event, for the ticket list.
class Ticket {
  const Ticket(this.registration, this.event);

  final Registration registration;
  final GuyubEvent event;
}

enum RegistrationOutcome {
  registered,

  /// Already registered: the server returned the existing ticket.
  existing,
}

/// The fields an organizer edits. Status and registration change through
/// dedicated actions, never through the form.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.date,
    this.description = '',
    this.location = '',
    this.capacity,
  });

  final String title;
  final String description;
  final String location;
  final DateTime date;
  final int? capacity;

  static const titleMax = 120;
  static const descriptionMax = 5000;
  static const locationMax = 200;
  static const capacityMax = 100000;

  static String? titleError(String value) {
    final title = value.trim();
    if (title.isEmpty) return 'Enter a title.';
    if (title.length > titleMax) return 'Use at most $titleMax characters.';
    return null;
  }

  static String? descriptionError(String value) =>
      value.trim().length > descriptionMax ? 'Use at most $descriptionMax characters.' : null;

  static String? locationError(String value) =>
      value.trim().length > locationMax ? 'Use at most $locationMax characters.' : null;

  /// Empty means no limit.
  static String? capacityError(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null || number < 1 || number > capacityMax) {
      return 'Enter a whole number from 1 to $capacityMax, or leave it empty.';
    }
    return null;
  }

  static int? parseCapacity(String value) {
    final text = value.trim();
    return text.isEmpty ? null : int.parse(text);
  }
}

/// A person with a role in an organization (organizer or committee).
class Member {
  const Member({required this.uid, required this.role, this.orgId, this.email, this.displayName});

  final String uid;
  final UserRole role;
  final String? orgId;
  final String? email;
  final String? displayName;

  String get label => (displayName?.isNotEmpty ?? false) ? displayName! : (email ?? uid);
}

/// A role waiting for someone who has not signed in yet.
class Invite {
  const Invite({required this.email, required this.role, required this.orgId});

  final String email;
  final UserRole role;
  final String orgId;
}

/// A committee member assigned to one event.
class Assignment {
  const Assignment({required this.uid, this.displayName, this.email});

  final String uid;
  final String? displayName;
  final String? email;

  String get label => (displayName?.isNotEmpty ?? false) ? displayName! : (email ?? uid);
}

enum InviteOutcome {
  /// The account existed; the role applies now.
  granted,

  /// No account yet; the role applies at first sign-in.
  invited,
}
