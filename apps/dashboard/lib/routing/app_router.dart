import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/user_role.dart';
import '../features/admin/admin_home_page.dart';
import '../features/attendee/attendee_home_page.dart';
import '../features/committee/committee_home_page.dart';
import '../features/organizer/organizer_home_page.dart';
import '../ui/forbidden_page.dart';
import '../ui/login_page.dart';
import '../ui/not_found_page.dart';
import '../ui/splash_page.dart';
import 'redirect.dart';

GoRouter createRouter(AuthController auth, {String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) => resolveRedirect(auth.state, state.uri),
    errorBuilder: (context, state) => NotFoundPage(location: state.uri.toString()),
    routes: [
      // Root always redirects (to splash, login, or the role's home).
      GoRoute(path: Routes.root, builder: (context, state) => const SplashPage()),
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),
      GoRoute(
        path: Routes.forbidden,
        builder: (context, state) => ForbiddenPage(attempted: state.uri.queryParameters['from']),
      ),
      GoRoute(path: UserRole.admin.homePath, builder: (context, state) => const AdminHomePage()),
      GoRoute(path: UserRole.organizer.homePath, builder: (context, state) => const OrganizerHomePage()),
      GoRoute(path: UserRole.committee.homePath, builder: (context, state) => const CommitteeHomePage()),
      GoRoute(path: UserRole.attendee.homePath, builder: (context, state) => const AttendeeHomePage()),
    ],
  );
}
