import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guyub_dashboard/app.dart';
import 'package:guyub_dashboard/auth/auth_controller.dart';
import 'package:guyub_dashboard/auth/auth_state.dart';
import 'package:guyub_dashboard/auth/user_role.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late AuthController controller;

  setUp(() {
    repo = FakeAuthRepository();
    controller = AuthController(repo);
  });

  tearDown(() => controller.dispose());

  Future<void> pumpApp(WidgetTester tester, {String? at}) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GuyubApp(authController: controller, initialLocation: at));
    await tester.pump();
  }

  Future<void> signIn(WidgetTester tester, UserRole role) async {
    repo.emit(SignedIn(uid: 'u1', role: role, orgId: 'himatif', displayName: 'Rina', email: 'rina@example.com'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a loading screen until the session is known', (tester) async {
    await pumpApp(tester);
    expect(find.text('Loading your session…'), findsOneWidget);
  });

  testWidgets('signed-out user sees Google sign-in', (tester) async {
    await pumpApp(tester);
    repo.emit(const SignedOut());
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(repo.signInCalls, 1);
  });

  for (final role in UserRole.values) {
    testWidgets('${role.claim} lands on own dashboard', (tester) async {
      await pumpApp(tester);
      await signIn(tester, role);

      expect(find.text('Welcome, Rina'), findsOneWidget);
      expect(find.widgetWithText(Chip, role.label), findsOneWidget);
    });
  }

  testWidgets('organizer opening the admin area is blocked', (tester) async {
    await pumpApp(tester);
    await signIn(tester, UserRole.organizer);

    GoRouter.of(tester.element(find.text('Welcome, Rina'))).go('/admin');
    await tester.pumpAndSettle();

    expect(find.text('No access to this area'), findsOneWidget);
    expect(find.textContaining('You are signed in as Organizer.'), findsOneWidget);

    await tester.tap(find.text('Go to my dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Rina'), findsOneWidget);
  });

  // Shared committee laptops: after sign-out the login URL still remembers the
  // previous user's area. The next user must land on their own dashboard.
  testWidgets('remembered target of another role opens own dashboard instead', (tester) async {
    await pumpApp(tester, at: '/admin');
    await signIn(tester, UserRole.organizer);

    expect(find.widgetWithText(Chip, 'Organizer'), findsOneWidget);
    expect(find.text('No access to this area'), findsNothing);
  });

  testWidgets('deep link survives sign-in', (tester) async {
    await pumpApp(tester, at: '/committee');
    repo.emit(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);

    await signIn(tester, UserRole.committee);
    expect(find.widgetWithText(Chip, 'Committee'), findsOneWidget);
  });

  testWidgets('role granted server-side opens the new dashboard without sign-out', (tester) async {
    await pumpApp(tester);
    await signIn(tester, UserRole.attendee);
    expect(find.widgetWithText(Chip, 'Attendee'), findsOneWidget);

    // Server sets the committee claim; the refreshed token arrives.
    repo.emitRoleChanged();
    await tester.pumpAndSettle();
    expect(repo.refreshCalls, 1);
    repo.emit(const SignedIn(uid: 'u1', role: UserRole.committee, orgId: 'himatif', displayName: 'Rina'));
    await tester.pumpAndSettle();

    // Moves straight to the new role's dashboard, no "No access" detour.
    expect(find.text('No access to this area'), findsNothing);
    expect(find.widgetWithText(Chip, 'Committee'), findsOneWidget);
  });

  testWidgets('a different user signing in does not trigger the role-change jump', (tester) async {
    await pumpApp(tester);
    await signIn(tester, UserRole.attendee);
    GoRouter.of(tester.element(find.text('Welcome, Rina'))).go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('No access to this area'), findsOneWidget);

    // Same role, same user: stays on the forbidden page.
    repo.emit(const SignedIn(uid: 'u1', role: UserRole.attendee, displayName: 'Rina'));
    await tester.pumpAndSettle();
    expect(find.text('No access to this area'), findsOneWidget);
  });

  testWidgets('sign-out returns to login', (tester) async {
    await pumpApp(tester);
    await signIn(tester, UserRole.attendee);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(repo.signOutCalls, 1);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
