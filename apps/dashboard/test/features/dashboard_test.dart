import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/app.dart';
import 'package:guyub_dashboard/auth/auth_controller.dart';
import 'package:guyub_dashboard/auth/auth_state.dart';
import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/data/models.dart';
import 'package:guyub_dashboard/ui/dashboard/draggable_widget_grid.dart';
import 'package:guyub_dashboard/ui/dashboard/tiles.dart';
import 'package:guyub_dashboard/ui/ui_prefs.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_backend.dart';
import '../support/harness.dart';

final _soon = DateTime.now().add(const Duration(days: 3));

FakeBackend busyOrg() {
  final backend = FakeBackend()
    ..addEvent('talk', 'himatif', title: 'Tech Talk', status: EventStatus.active, capacity: 50, registeredCount: 2, date: _soon)
    ..addEvent('draft', 'himatif', title: 'Workshop draft', status: EventStatus.draft, date: _soon);
  backend.addRegistration('talk', uid: 'a', name: 'Ayu Lestari', checkedIn: true, checkedInAt: DateTime.now());
  backend.addRegistration('talk', uid: 'b', name: 'Budi');
  backend.assignments['talk'] = {'u1': const Assignment(uid: 'u1')};
  return backend;
}

/// Pumps the app with given prefs, so a test can inspect what was saved.
Future<void> pumpSignedIn(WidgetTester tester, UserRole role, {required Size size, FakeBackend? backend, UiPrefs? prefs}) async {
  final auth = FakeAuthRepository();
  final controller = AuthController(auth);
  addTearDown(controller.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GuyubApp(authController: controller, backend: backend ?? busyOrg(), prefs: prefs));
  await tester.pump();
  auth.emit(SignedIn(uid: 'u1', role: role, orgId: role == UserRole.attendee ? null : 'himatif', displayName: 'Rina Maharani', email: 'rina@example.com'));
  await tester.pumpAndSettle();
}

void main() {
  group('every dashboard fits every device', () {
    const sizes = {
      'small phone': Size(320, 640),
      'phone': Size(375, 812),
      'large phone landscape': Size(844, 390),
      'tablet': Size(768, 1024),
      'laptop': Size(1280, 800),
      'desktop': Size(1920, 1080),
    };
    for (final role in UserRole.values) {
      for (final MapEntry(key: name, value: size) in sizes.entries) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          testWidgets('${role.claim} on $name, ${mode.name}', (tester) async {
            // A layout overflow fails the test through the framework's error.
            await pumpSignedIn(tester, role, size: size, prefs: UiPrefs()..setThemeMode(mode));
            expect(find.text('Welcome back, Rina'), findsOneWidget);
            expect(find.byType(DraggableWidgetGrid), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('large text still fits on a phone', (tester) async {
      final auth = FakeAuthRepository();
      final controller = AuthController(auth);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GuyubApp(authController: controller, backend: busyOrg()));
      await tester.pump();
      auth.emit(const SignedIn(uid: 'u1', role: UserRole.organizer, orgId: 'himatif', displayName: 'Rina'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('organizer cards show real numbers', () {
    testWidgets('counts come from events and attendance', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1280, 1400));

      Finder card(String label) => find.bySemanticsLabel(RegExp('^$label, card'));
      expect(card('Upcoming events'), findsOneWidget);
      expect(find.descendant(of: find.byType(DraggableWidgetGrid), matching: find.text('1 draft waiting')), findsOneWidget);
      expect(find.text('Tech Talk'), findsWidgets);
      expect(find.textContaining('1 in · 2 registered · 48 left'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget, reason: 'one of two checked in');
      expect(find.text('Ayu Lestari'), findsNothing, reason: 'names are inside one rich text line');
      expect(find.textContaining('Ayu Lestari checked in', findRichText: true), findsOneWidget);
    });

    testWidgets('a new organization sees guidance, not invented data', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1280, 1400), backend: FakeBackend());
      expect(find.text('Nothing published yet'), findsOneWidget);
      expect(find.text('No events yet. Create your first draft.'), findsOneWidget);
      expect(find.text('Publish an event to follow its registrations here.'), findsOneWidget);
    });

    testWidgets('planned features are labelled', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1280, 1400));
      expect(find.descendant(of: find.byType(DraggableWidgetGrid), matching: find.text('Planned · M5')), findsOneWidget);
      expect(find.descendant(of: find.byType(DraggableWidgetGrid), matching: find.text('Planned · M6')), findsOneWidget);
    });

    testWidgets('the main action opens the event form', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1280, 1400));
      await tester.tap(find.text('New event'));
      await tester.pumpAndSettle();
      expect(find.text('Create draft'), findsOneWidget);
    });
  });

  group('shell', () {
    testWidgets('wide screens show a sidebar, which marks the current page', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1280, 1000));
      final sidebarEvents = find.bySemanticsLabel('Events');
      expect(sidebarEvents, findsOneWidget);
      expect(find.bySemanticsLabel('Certificates, planned for M5'), findsOneWidget);
      Finder navEntry(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label && w.properties.selected == true);
      expect(navEntry('Dashboard'), findsOneWidget);
      expect(navEntry('Events'), findsNothing);

      await tester.tap(sidebarEvents);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('the sidebar collapses to icons and remembers it', (tester) async {
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1280, 1000), prefs: prefs);
      expect(find.text('Guyub'), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse navigation'));
      await tester.pumpAndSettle();
      expect(prefs.sidebarCollapsed, isTrue);
      expect(find.text('Guyub'), findsNothing);
      expect(find.byTooltip('Expand navigation'), findsOneWidget);
    });

    testWidgets('phones get a drawer that navigates', (tester) async {
      await pumpSignedIn(tester, UserRole.attendee, size: const Size(375, 812));
      expect(find.text('My tickets'), findsNothing);

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My tickets'));
      await tester.pumpAndSettle();

      expect(find.text('No tickets yet.'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('the theme toggle switches to the dark tokens', (tester) async {
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.attendee, size: const Size(1280, 1000), prefs: prefs);
      await tester.tap(find.byTooltip('Use dark theme'));
      await tester.pumpAndSettle();
      expect(prefs.themeMode, ThemeMode.dark);
      expect(find.byTooltip('Use light theme'), findsOneWidget);
    });

    testWidgets('header actions stay at the right edge', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1440, 900));
      expect(tester.getCenter(find.byTooltip('Account')).dx, greaterThan(1380));
    });

    testWidgets('the seats bar has height', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(1280, 1400));
      final segments = find.descendant(of: find.byType(SeatsBar), matching: find.byType(ColoredBox));
      expect(segments, findsWidgets);
      expect(tester.getSize(segments.first).height, 10);
    });

    testWidgets('sub-pages keep the shell', (tester) async {
      await Harness.signedIn(tester, role: UserRole.organizer, orgId: 'himatif', at: '/organizer/committee', size: const Size(1280, 1000));
      expect(find.bySemanticsLabel('Events'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('dragging cards', () {
    const size = Size(1280, 1400);
    const key = 'u1.organizer';

    Offset centerOf(WidgetTester tester, String text) => tester.getCenter(find.text(text).first);

    testWidgets('a mouse drag moves a card and saves the new order', (tester) async {
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.organizer, size: size, prefs: prefs);

      final from = centerOf(tester, 'Upcoming events');
      final to = centerOf(tester, 'Registrations');
      final mouse = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      await mouse.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.moveTo(to);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await mouse.up();
      await tester.pumpAndSettle();

      final order = prefs.layout(key)!;
      expect(order.indexOf('registrations'), lessThan(order.indexOf('upcoming')));
      expect(centerOf(tester, 'Upcoming events').dx, greaterThan(centerOf(tester, 'Registrations').dx));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a mouse click on a card still opens its link', (tester) async {
      await pumpSignedIn(tester, UserRole.organizer, size: size);
      await tester.tap(find.text('Upcoming events'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('a touch swipe scrolls instead of dragging', (tester) async {
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.organizer, size: const Size(375, 812), prefs: prefs);
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      await tester.dragFrom(const Offset(180, 500), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(prefs.layout(key), isNull, reason: 'order unchanged');
    });

    testWidgets('touch drags after a long press', (tester) async {
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.organizer, size: size, prefs: prefs);
      final from = centerOf(tester, 'Upcoming events');
      final to = centerOf(tester, 'Registrations');

      final finger = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 400));
      await finger.moveTo(to);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await finger.up();
      await tester.pumpAndSettle();

      final order = prefs.layout(key)!;
      expect(order.indexOf('registrations'), lessThan(order.indexOf('upcoming')));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Alt and an arrow key move the focused card', (tester) async {
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.organizer, size: size, prefs: prefs);
      Focus.of(tester.element(find.text('Upcoming events'))).requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      final order = prefs.layout(key)!;
      expect(order.indexOf('registrations'), lessThan(order.indexOf('upcoming')));
    });

    testWidgets('screen readers get move actions', (tester) async {
      final handle = tester.ensureSemantics();
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.organizer, size: size, prefs: prefs);
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Upcoming events, card 2 of 11')));
      final actions = node.getSemanticsData().customSemanticsActionIds;
      expect(actions, hasLength(2));
      handle.dispose();
    });

    testWidgets('the Arrange dialog is the one-tap alternative, with reset', (tester) async {
      final prefs = UiPrefs();
      await pumpSignedIn(tester, UserRole.organizer, size: size, prefs: prefs);

      await tester.tap(find.text('Arrange'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move Registrations up'));
      await tester.pumpAndSettle();
      final order = prefs.layout(key)!;
      expect(order.indexOf('registrations'), lessThan(order.indexOf('upcoming')));

      await tester.tap(find.text('Reset order'));
      await tester.pumpAndSettle();
      expect(prefs.layout(key), isNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(centerOf(tester, 'Upcoming events').dx, lessThan(centerOf(tester, 'Registrations').dx));
    });

    testWidgets('a saved order survives a reload', (tester) async {
      final prefs = UiPrefs()..saveLayout(key, ['registrations', 'upcoming']);
      await pumpSignedIn(tester, UserRole.organizer, size: size, prefs: prefs);
      expect(centerOf(tester, 'Upcoming events').dx, greaterThan(centerOf(tester, 'Registrations').dx));
    });
  });
}
