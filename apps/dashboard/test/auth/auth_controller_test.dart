import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/auth/auth_controller.dart';
import 'package:guyub_dashboard/auth/auth_repository.dart';
import 'package:guyub_dashboard/auth/auth_state.dart';
import 'package:guyub_dashboard/auth/user_role.dart';

import '../support/fake_auth_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAuthRepository repo;
  late AuthController controller;

  setUp(() {
    repo = FakeAuthRepository();
    controller = AuthController(repo);
  });

  tearDown(() => controller.dispose());

  test('starts loading, then follows the repository', () async {
    expect(controller.state, isA<AuthLoading>());

    repo.emit(const SignedIn(uid: 'u1', role: UserRole.organizer, orgId: 'himatif'));
    await flush();

    final state = controller.state as SignedIn;
    expect(state.role, UserRole.organizer);
    expect(state.orgId, 'himatif');
  });

  test('refreshes claims when the role changes server-side', () async {
    repo.emit(const SignedIn(uid: 'u1', role: UserRole.attendee));
    await flush();
    expect(repo.watchedRoleUid, 'u1');

    repo.emitRoleChanged();
    await flush();
    expect(repo.refreshCalls, 1);
  });

  test('stops watching role changes after sign-out', () async {
    repo.emit(const SignedIn(uid: 'u1', role: UserRole.attendee));
    await flush();
    repo.emit(const SignedOut());
    await flush();

    repo.emitRoleChanged();
    await flush();
    expect(repo.refreshCalls, 0);
  });

  test('shows a sign-in failure and clears busy', () async {
    repo.signInFailure = const AuthFailure('Popup blocked.');

    await controller.signInWithGoogle();

    expect(controller.error, 'Popup blocked.');
    expect(controller.busy, isFalse);
  });

  test('clears the previous error on the next attempt', () async {
    repo.signInFailure = const AuthFailure('Popup blocked.');
    await controller.signInWithGoogle();

    repo.signInFailure = null;
    await controller.signInWithGoogle();

    expect(controller.error, isNull);
    expect(repo.signInCalls, 2);
  });
}
