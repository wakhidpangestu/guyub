import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/data/backend.dart';
import 'package:guyub_dashboard/data/models.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

FakeBackend himatif() {
  final backend = FakeBackend();
  backend.orgs['himatif'] = const Organization(id: 'himatif', name: 'HIMATIF');
  backend.addPerson('c1', role: UserRole.committee, orgId: 'himatif', name: 'Budi', email: 'budi@example.com');
  backend.addPerson('c9', role: UserRole.committee, orgId: 'bem', name: 'Other Org Member');
  return backend;
}

Future<Harness> organizerAt(WidgetTester tester, String at, {FakeBackend? backend}) =>
    Harness.signedIn(tester, role: UserRole.organizer, orgId: 'himatif', at: at, backend: backend ?? himatif());

void main() {
  group('events list', () {
    testWidgets('shows only own org events, by date', (tester) async {
      final backend = himatif()
        ..addEvent('late', 'himatif', title: 'Late Event', date: DateTime(2026, 12, 20))
        ..addEvent('early', 'himatif', title: 'Early Event', date: DateTime(2026, 12, 1))
        ..addEvent('other', 'bem', title: 'BEM Event');
      await organizerAt(tester, '/organizer/events', backend: backend);

      expect(find.text('BEM Event'), findsNothing);
      final early = tester.getTopLeft(find.text('Early Event')).dy;
      final late = tester.getTopLeft(find.text('Late Event')).dy;
      expect(early, lessThan(late));
    });

    testWidgets('empty state offers to create an event', (tester) async {
      await organizerAt(tester, '/organizer/events');
      expect(find.text('No events yet.'), findsOneWidget);
      await tester.tap(find.text('Create your first event'));
      await tester.pumpAndSettle();
      expect(find.text('Create draft'), findsOneWidget);
    });
  });

  group('event form', () {
    testWidgets('requires a title, then creates a draft and opens it', (tester) async {
      final h = await organizerAt(tester, '/organizer/events/new');

      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a title.'), findsOneWidget);
      expect(h.backend.events, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Tech Talk');
      await tester.enterText(find.widgetWithText(TextFormField, 'Capacity'), '0');
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(find.textContaining('whole number'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Capacity'), '150');
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();

      final event = h.backend.events.values.single;
      expect(event.title, 'Tech Talk');
      expect(event.capacity, 150);
      expect(event.status, EventStatus.draft);
      expect(find.text('Committee for this event'), findsOneWidget);
      expect(find.text('Capacity: 150'), findsOneWidget);
    });

    testWidgets('edits details of an existing event', (tester) async {
      final backend = himatif()..addEvent('e1', 'himatif', title: 'Old Title');
      final h = await organizerAt(tester, '/organizer/events/e1/edit', backend: backend);

      expect(find.widgetWithText(TextFormField, 'Old Title'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Old Title'), 'New Title');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(h.backend.events['e1']!.title, 'New Title');
      expect(find.text('New Title'), findsOneWidget);
    });
  });

  group('event lifecycle', () {
    testWidgets('publish, open registration, then complete', (tester) async {
      final backend = himatif()..addEvent('e1', 'himatif', title: 'Tech Talk');
      final h = await organizerAt(tester, '/organizer/events/e1', backend: backend);

      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(h.backend.events['e1']!.status, EventStatus.active);

      await tester.tap(find.text('Open registration'));
      await tester.pumpAndSettle();
      expect(h.backend.events['e1']!.registrationOpen, isTrue);
      expect(find.text('Close registration'), findsOneWidget);

      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as completed?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Mark completed'));
      await tester.pumpAndSettle();

      final done = h.backend.events['e1']!;
      expect(done.status, EventStatus.completed);
      expect(done.registrationOpen, isFalse);
      expect(find.textContaining('Registration and check-in are locked'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);
    });

    testWidgets('deleting a draft asks first and returns to the list', (tester) async {
      final backend = himatif()..addEvent('e1', 'himatif', title: 'Scratch');
      final h = await organizerAt(tester, '/organizer/events/e1', backend: backend);

      await tester.tap(find.text('Delete draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.backend.events, contains('e1'));

      await tester.tap(find.text('Delete draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(h.backend.events, isEmpty);
      expect(find.text('No events yet.'), findsOneWidget);
    });

    testWidgets('a backend error is shown, not swallowed', (tester) async {
      final backend = himatif()..addEvent('e1', 'himatif');
      final h = await organizerAt(tester, '/organizer/events/e1', backend: backend);

      h.backend.failNext = const BackendFailure('You do not have permission to do that.');
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(find.text('You do not have permission to do that.'), findsOneWidget);
      expect(h.backend.events['e1']!.status, EventStatus.draft);
    });
  });

  group('committee assignment', () {
    testWidgets('assigns and unassigns an own-org committee member', (tester) async {
      final backend = himatif()..addEvent('e1', 'himatif', status: EventStatus.active);
      final h = await organizerAt(tester, '/organizer/events/e1', backend: backend);

      expect(find.text('Nobody is assigned yet.'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Other Org Member'), findsNothing, reason: 'other orgs are never offered');
      await tester.tap(find.text('Budi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(h.backend.assignments['e1']!.keys, ['c1']);
      expect(find.text('Every committee member is assigned.'), findsOneWidget);

      await tester.tap(find.byTooltip('Unassign Budi'));
      await tester.pumpAndSettle();
      expect(h.backend.assignments['e1'], isEmpty);
    });

    testWidgets('points to the Committee page when the org has no committee', (tester) async {
      final backend = FakeBackend()..addEvent('e1', 'himatif');
      await organizerAt(tester, '/organizer/events/e1', backend: backend);
      expect(find.text('Add committee members'), findsOneWidget);
    });
  });

  group('committee page', () {
    testWidgets('adds a new email as a pending invite and an existing account directly', (tester) async {
      final backend = himatif()..addPerson('a1', role: UserRole.attendee, email: 'sari@example.com', name: 'Sari');
      final h = await organizerAt(tester, '/organizer/committee', backend: backend);

      expect(find.text('Budi'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Google account email'), 'New@Example.com ');
      await tester.tap(find.text('Add committee member'));
      await tester.pumpAndSettle();
      expect(h.backend.invites.keys, ['new@example.com']);
      expect(find.text('Waiting for first sign-in'), findsOneWidget);
      expect(find.textContaining('becomes a committee member at first sign-in'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Google account email'), 'sari@example.com');
      await tester.tap(find.text('Add committee member'));
      await tester.pumpAndSettle();
      expect(h.backend.people['a1']!.role, UserRole.committee);
      expect(find.text('Sari'), findsOneWidget);
    });

    testWidgets('rejects an invalid email before calling the server', (tester) async {
      final h = await organizerAt(tester, '/organizer/committee');
      await tester.enterText(find.widgetWithText(TextFormField, 'Google account email'), 'not-an-email');
      await tester.tap(find.text('Add committee member'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(h.backend.invites, isEmpty);
    });

    testWidgets('removing a member asks first', (tester) async {
      final backend = himatif();
      backend.assignments['e1'] = {};
      final h = await organizerAt(tester, '/organizer/committee', backend: backend);

      await tester.tap(find.byTooltip('Remove Budi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('removed from every event'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(h.backend.people['c1']!.role, UserRole.attendee);
      expect(find.text('Budi'), findsNothing);
    });
  });
}
