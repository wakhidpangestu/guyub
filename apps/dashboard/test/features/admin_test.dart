import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/data/models.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

Future<Harness> adminAt(WidgetTester tester, String at, {FakeBackend? backend}) =>
    Harness.signedIn(tester, role: UserRole.admin, at: at, backend: backend);

void main() {
  testWidgets('home links to organizations', (tester) async {
    await adminAt(tester, '/admin');
    await tester.tap(find.text('Organizations'));
    await tester.pumpAndSettle();
    expect(find.text('No organizations yet. Create the first one.'), findsOneWidget);
  });

  testWidgets('creates an organization; the ID follows the name', (tester) async {
    final h = await adminAt(tester, '/admin/organizations');

    await tester.tap(find.text('New organization'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'HIMATIF ITB');
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'himatif-itb'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(h.backend.orgs['himatif-itb']!.name, 'HIMATIF ITB');
    // Opens the new organization's page.
    expect(find.text('ID: himatif-itb'), findsOneWidget);
    expect(find.text('Organizers'), findsOneWidget);
  });

  testWidgets('an edited ID is kept and validated', (tester) async {
    final h = await adminAt(tester, '/admin/organizations');

    await tester.tap(find.text('New organization'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'ID'), 'Bad ID');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'BEM KM');
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'Bad ID'), findsOneWidget, reason: 'manual ID is not overwritten');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lowercase letters'), findsOneWidget);
    expect(h.backend.orgs, isEmpty);
  });

  testWidgets('a taken ID is reported', (tester) async {
    final backend = FakeBackend()..orgs['bem'] = const Organization(id: 'bem', name: 'BEM');
    await adminAt(tester, '/admin/organizations', backend: backend);

    await tester.tap(find.text('New organization'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'BEM');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsOneWidget);
  });

  testWidgets('adds an organizer by email on the organization page', (tester) async {
    final backend = FakeBackend()
      ..orgs['himatif'] = const Organization(id: 'himatif', name: 'HIMATIF')
      ..addPerson('p1', role: UserRole.attendee, email: 'rina@example.com', name: 'Rina Organizer');
    final h = await adminAt(tester, '/admin/organizations/himatif', backend: backend);

    await tester.enterText(find.widgetWithText(TextFormField, 'Google account email'), 'rina@example.com');
    await tester.tap(find.text('Add organizer'));
    await tester.pumpAndSettle();

    expect(h.backend.people['p1']!.role, UserRole.organizer);
    expect(h.backend.people['p1']!.orgId, 'himatif');
    expect(find.text('Rina Organizer'), findsOneWidget);
    expect(find.text('rina@example.com is now an organizer.'), findsOneWidget);
  });

  testWidgets('unknown organization ID shows a clear message', (tester) async {
    await adminAt(tester, '/admin/organizations/ghost');
    expect(find.textContaining('No organization with the ID "ghost"'), findsOneWidget);
  });
}
