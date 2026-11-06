import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/data/models.dart';
import 'package:guyub_dashboard/data/ticket_code.dart';
import 'package:guyub_dashboard/features/checkin/camera_scanner.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// Stands in for the camera: a button that "scans" whatever [nextScan] holds.
String? nextScan;

FakeBackend door({UserRole role = UserRole.committee}) {
  final backend = FakeBackend()
    ..currentUid = 'door'
    ..currentRole = role
    ..currentOrgId = 'himatif'
    ..addEvent('talk', 'himatif', title: 'Tech Talk', status: EventStatus.active)
    ..addEvent('summit', 'bem', title: 'Summit', status: EventStatus.active);
  backend.assignments['talk'] = {'door': const Assignment(uid: 'door')};
  backend.addRegistration('talk', uid: 'sari', name: 'Sari Attendee');
  backend.addRegistration('talk', uid: 'budi', name: 'Budi', checkedIn: true);
  backend.addRegistration('summit', uid: 'rina', name: 'Rina');
  return backend;
}

String codeFor(FakeBackend backend, String attendanceId, {int windowOffset = 0}) =>
    ticketPayload(backend.ticketKeys[attendanceId]!, attendanceId, ticketWindowAt(DateTime.now()) + windowOffset);

Future<Harness> openScanner(WidgetTester tester, FakeBackend backend, {UserRole role = UserRole.committee}) =>
    Harness.signedIn(
      tester,
      role: role,
      orgId: 'himatif',
      uid: 'door',
      backend: backend,
      at: role == UserRole.committee ? '/committee/events/talk' : '/organizer/events/talk/scan',
    );

Future<void> scan(WidgetTester tester, String code) async {
  nextScan = code;
  await tester.tap(find.text('Fake scan'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    CameraScanner.debugBuilder = (onCode) => TextButton(onPressed: () => onCode(nextScan!), child: const Text('Fake scan'));
  });
  tearDown(() => CameraScanner.debugBuilder = null);

  group('scanner', () {
    testWidgets('a valid code checks the person in and updates the count', (tester) async {
      final backend = door();
      await openScanner(tester, backend);
      expect(find.text('1 of 2 checked in'), findsOneWidget);

      await scan(tester, codeFor(backend, 'talk_sari'));

      expect(find.text('Checked in'), findsOneWidget);
      expect(find.text('Sari Attendee'), findsWidgets);
      expect(backend.registrations['talk_sari']!.isCheckedIn, isTrue);
      expect(find.text('2 of 2 checked in'), findsOneWidget);
    });

    testWidgets('each refusal has its own message', (tester) async {
      final backend = door();
      await openScanner(tester, backend);

      await scan(tester, codeFor(backend, 'talk_budi'));
      expect(find.text('Already checked in'), findsOneWidget);
      expect(find.textContaining('First came in at'), findsOneWidget);

      await scan(tester, codeFor(backend, 'talk_sari', windowOffset: -5));
      expect(find.text('Code expired'), findsOneWidget);
      expect(backend.registrations['talk_sari']!.isCheckedIn, isFalse);

      await scan(tester, 'G1.talk_sari.1.0123456789abcdef');
      expect(find.text('Not a valid ticket'), findsOneWidget);

      await scan(tester, codeFor(backend, 'summit_rina'));
      expect(find.text('Ticket for another event'), findsOneWidget);

      await scan(tester, 'hello world');
      expect(find.text('Not a valid ticket'), findsOneWidget);
    });

    testWidgets('the camera reading the same ticket repeatedly sends one request', (tester) async {
      final backend = door();
      await openScanner(tester, backend);

      await scan(tester, codeFor(backend, 'talk_sari'));
      await scan(tester, codeFor(backend, 'talk_sari'));
      // The code rotated, but it is still the same person in front of the camera.
      await scan(tester, codeFor(backend, 'talk_sari', windowOffset: 1));
      expect(backend.checkInCalls, hasLength(1));
      expect(find.text('Checked in'), findsOneWidget, reason: 'the screen keeps the green result');
    });

    testWidgets('after "Code expired", the person can retry with a fresh code at once', (tester) async {
      final backend = door();
      await openScanner(tester, backend);

      await scan(tester, codeFor(backend, 'talk_sari', windowOffset: -5));
      expect(find.text('Code expired'), findsOneWidget);
      await scan(tester, codeFor(backend, 'talk_sari'));
      expect(find.text('Checked in'), findsOneWidget);
      expect(backend.checkInCalls, hasLength(2));
    });

    testWidgets('a different ticket right after is checked at once', (tester) async {
      final backend = door();
      backend.addRegistration('talk', uid: 'tono', name: 'Tono');
      await openScanner(tester, backend);

      await scan(tester, codeFor(backend, 'talk_sari'));
      await scan(tester, codeFor(backend, 'talk_tono'));
      expect(backend.checkInCalls, hasLength(2));
      expect(find.text('Tono'), findsWidgets);
    });

    testWidgets('a typed or pasted code works like a scan (USB scanners too)', (tester) async {
      final backend = door();
      await openScanner(tester, backend);

      await tester.enterText(find.widgetWithText(TextField, 'Ticket code'), codeFor(backend, 'talk_sari'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Checked in'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ticket code'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty, reason: 'cleared for the next person');
    });

    testWidgets('a completed event says check-in is closed', (tester) async {
      final backend = door();
      backend.events['talk'] = backend.events['talk']!.withStatus(EventStatus.completed, registrationOpen: false);
      await openScanner(tester, backend);

      expect(find.textContaining('Check-in is closed'), findsOneWidget);
      await scan(tester, codeFor(backend, 'talk_sari'));
      expect(find.text('Check-in is closed'), findsOneWidget);
      expect(backend.registrations['talk_sari']!.isCheckedIn, isFalse);
    });

    testWidgets('an unassigned committee member is refused', (tester) async {
      final backend = door()..assignments['talk'] = {};
      await openScanner(tester, backend);

      await scan(tester, codeFor(backend, 'talk_sari'));
      expect(find.text('You are not assigned to check people in at this event.'), findsOneWidget);
      expect(backend.registrations['talk_sari']!.isCheckedIn, isFalse);
    });

    testWidgets('committee home opens the scanner for an assigned event', (tester) async {
      final backend = door();
      await Harness.signedIn(tester, role: UserRole.committee, orgId: 'himatif', uid: 'door', backend: backend);

      await tester.tap(find.text('Tech Talk').first);
      await tester.pumpAndSettle();
      expect(find.text('Fake scan'), findsOneWidget);
      expect(find.text('1 of 2 checked in'), findsOneWidget);
    });
  });

  group('organizer attendance', () {
    Future<Harness> openAttendance(WidgetTester tester, FakeBackend backend) => Harness.signedIn(
          tester,
          role: UserRole.organizer,
          orgId: 'himatif',
          uid: 'door',
          backend: backend,
          at: '/organizer/events/talk/attendance',
        );

    testWidgets('lists everyone with live state, searchable and filterable', (tester) async {
      final backend = door(role: UserRole.organizer);
      await openAttendance(tester, backend);

      expect(find.text('1 of 2 checked in'), findsOneWidget);
      expect(find.text('Sari Attendee'), findsOneWidget);
      expect(find.text('Budi'), findsOneWidget);

      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      expect(find.text('Budi'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Search by name'), 'bu');
      await tester.pumpAndSettle();
      expect(find.text('Sari Attendee'), findsNothing);
      expect(find.text('Budi'), findsOneWidget);
    });

    testWidgets('manual check-in asks first and marks the person', (tester) async {
      final backend = door(role: UserRole.organizer);
      await openAttendance(tester, backend);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Check in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('phone cannot show the ticket'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(backend.registrations['talk_sari']!.checkInMethod, 'manual');
      expect(find.text('2 of 2 checked in'), findsOneWidget);
      expect(find.textContaining('manually'), findsOneWidget);
    });

    testWidgets('organizer can open the scanner for an own-org event', (tester) async {
      final backend = door(role: UserRole.organizer);
      await openScanner(tester, backend, role: UserRole.organizer);
      await scan(tester, codeFor(backend, 'talk_sari'));
      expect(find.text('Checked in'), findsOneWidget);
    });
  });
}
