import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/data/backend.dart';
import 'package:guyub_dashboard/data/models.dart';
import 'package:guyub_dashboard/features/attendee/rotating_ticket_qr.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

FakeBackend campus() => FakeBackend()
  ..orgs['himatif'] = const Organization(id: 'himatif', name: 'HIMATIF')
  ..orgs['bem'] = const Organization(id: 'bem', name: 'BEM KM');

Future<Harness> attendeeAt(WidgetTester tester, String at, FakeBackend backend) =>
    Harness.signedIn(tester, role: UserRole.attendee, at: at, backend: backend);

void main() {
  group('browse', () {
    testWidgets('lists upcoming published events from every org, with their state', (tester) async {
      final backend = campus()
        ..addEvent('talk', 'himatif', title: 'Tech Talk', status: EventStatus.active, registrationOpen: true, capacity: 100, registeredCount: 97, date: DateTime(2026, 11, 20))
        ..addEvent('summit', 'bem', title: 'BEM Summit', status: EventStatus.active, registrationOpen: true, capacity: 2, registeredCount: 2, date: DateTime(2026, 11, 21))
        ..addEvent('mine', 'bem', title: 'Workshop', status: EventStatus.active, date: DateTime(2026, 11, 22))
        ..addEvent('past', 'himatif', title: 'Old Event', status: EventStatus.active, date: DateTime(2026, 10, 1))
        ..addEvent('draft', 'himatif', title: 'Secret Draft', date: DateTime(2026, 12, 1));
      backend.addRegistration('mine');
      await attendeeAt(tester, '/attendee/events', backend);

      expect(find.text('Tech Talk'), findsOneWidget);
      expect(find.text('HIMATIF'), findsOneWidget);
      expect(find.text('3 spots left'), findsOneWidget);
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('Old Event'), findsNothing, reason: 'past events are hidden');
      expect(find.text('Secret Draft'), findsNothing, reason: 'drafts are never listed');
    });

    testWidgets('empty state when nothing is published', (tester) async {
      await attendeeAt(tester, '/attendee/events', campus());
      expect(find.textContaining('No upcoming events'), findsOneWidget);
    });
  });

  group('registration', () {
    testWidgets('needs privacy consent, then shows the ticket', (tester) async {
      final backend = campus()..addEvent('talk', 'himatif', title: 'Tech Talk', status: EventStatus.active, registrationOpen: true, capacity: 10);
      final h = await attendeeAt(tester, '/attendee/events/talk', backend);

      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy notice'), findsOneWidget);
      expect(find.textContaining('shared with HIMATIF'), findsOneWidget);

      final confirm = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Register'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'disabled until consent');

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(h.backend.registrations.keys, ['talk_u1']);
      expect(h.backend.events['talk']!.registeredCount, 1);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('changes every 30 seconds'), findsOneWidget);
    });

    testWidgets('closing the privacy notice does not register', (tester) async {
      final backend = campus()..addEvent('talk', 'himatif', status: EventStatus.active, registrationOpen: true);
      final h = await attendeeAt(tester, '/attendee/events/talk', backend);

      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.backend.registrations, isEmpty);
    });

    testWidgets('full and closed events offer no Register button', (tester) async {
      final backend = campus()
        ..addEvent('full', 'himatif', status: EventStatus.active, registrationOpen: true, capacity: 1, registeredCount: 1)
        ..addEvent('closed', 'himatif', status: EventStatus.active);
      await attendeeAt(tester, '/attendee/events/full', backend);
      expect(find.text('This event is full.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Register'), findsNothing);
    });

    testWidgets('a server refusal (event filled up meanwhile) is shown', (tester) async {
      final backend = campus()..addEvent('talk', 'himatif', status: EventStatus.active, registrationOpen: true);
      final h = await attendeeAt(tester, '/attendee/events/talk', backend);

      h.backend.failNext = const BackendFailure('This event is full.');
      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Register')));
      await tester.pumpAndSettle();

      expect(find.text('This event is full.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('registered attendee can open the ticket or cancel', (tester) async {
      final backend = campus()..addEvent('talk', 'himatif', status: EventStatus.active, registrationOpen: true, registeredCount: 1);
      backend.addRegistration('talk');
      final h = await attendeeAt(tester, '/attendee/events/talk', backend);

      expect(find.text('Show my ticket'), findsOneWidget);
      await tester.tap(find.text('Cancel registration'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel registration'));
      await tester.pumpAndSettle();

      expect(h.backend.registrations, isEmpty);
      expect(h.backend.events['talk']!.registeredCount, 0);
      expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);
    });

    testWidgets('an unpublished event the attendee cannot read says so', (tester) async {
      await attendeeAt(tester, '/attendee/events/ghost', campus());
      expect(find.text('This event is not available.'), findsOneWidget);
    });
  });

  group('tickets', () {
    testWidgets('lists tickets and opens one', (tester) async {
      final backend = campus()..addEvent('talk', 'himatif', title: 'Tech Talk', status: EventStatus.active);
      backend.addRegistration('talk');
      await attendeeAt(tester, '/attendee/tickets', backend);

      await tester.tap(find.text('Tech Talk'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('a checked-in ticket shows the confirmation instead of a code', (tester) async {
      final backend = campus()..addEvent('talk', 'himatif', status: EventStatus.active);
      backend.addRegistration('talk', checkedIn: true);
      await attendeeAt(tester, '/attendee/tickets/talk', backend);

      expect(find.text('Checked in'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('a ticket without a key explains how to fix it', (tester) async {
      final backend = campus()..addEvent('talk', 'himatif', status: EventStatus.active);
      backend.addRegistration('talk', withKey: false);
      await attendeeAt(tester, '/attendee/tickets/talk', backend);
      expect(find.textContaining('Cancel the registration and register again'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('empty state links to browsing', (tester) async {
      await attendeeAt(tester, '/attendee/tickets', campus());
      expect(find.text('No tickets yet.'), findsOneWidget);
      expect(find.text('Browse events'), findsOneWidget);
    });
  });

  testWidgets('the QR code rotates every 30 seconds with a countdown', (tester) async {
    var now = DateTime.fromMillisecondsSinceEpoch(59000000 * 30 * 1000 + 25 * 1000, isUtc: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RotatingTicketQr(qrToken: 'tok', attendanceId: 'e_u', clock: () => now)),
    ));
    // The widget is keyed by its payload (see RotatingTicketQr).
    String data() => (tester.widget<QrImageView>(find.byType(QrImageView)).key! as ValueKey<String>).value;

    final first = data();
    expect(first, startsWith('G1.e_u.59000000.'));
    expect(find.text('New code in 5s'), findsOneWidget);

    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(data(), isNot(first));
    expect(data(), startsWith('G1.e_u.59000001.'));
    expect(find.text('New code in 30s'), findsOneWidget);
  });
}
