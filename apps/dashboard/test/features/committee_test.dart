import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guyub_dashboard/auth/user_role.dart';
import 'package:guyub_dashboard/data/models.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  testWidgets('lists only the events the member is assigned to', (tester) async {
    final backend = FakeBackend()
      ..addEvent('mine', 'himatif', title: 'Tech Talk', status: EventStatus.active)
      ..addEvent('not-mine', 'himatif', title: 'Workshop', status: EventStatus.active);
    backend.assignments['mine'] = {'u1': const Assignment(uid: 'u1')};
    backend.assignments['not-mine'] = {'someone-else': const Assignment(uid: 'someone-else')};

    await Harness.signedIn(tester, role: UserRole.committee, orgId: 'himatif', backend: backend);

    expect(find.text('Your events'), findsOneWidget);
    expect(find.text('Tech Talk'), findsWidgets);
    expect(find.text('Workshop'), findsNothing);
    expect(find.text('Planned · M4'), findsNothing, reason: 'the scanner is built now');
  });

  testWidgets('explains an empty assignment list', (tester) async {
    await Harness.signedIn(tester, role: UserRole.committee, orgId: 'himatif');
    expect(find.textContaining('No events assigned yet'), findsOneWidget);
  });

  testWidgets('cannot open organizer pages', (tester) async {
    await Harness.signedIn(tester, role: UserRole.committee, orgId: 'himatif');
    GoRouter.of(tester.element(find.text('Your events'))).go('/organizer/events/new');
    await tester.pumpAndSettle();
    expect(find.text('No access to this area'), findsOneWidget);
    expect(find.text('Create draft'), findsNothing);
  });
}
