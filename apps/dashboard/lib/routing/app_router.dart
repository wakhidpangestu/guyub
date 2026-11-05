import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/user_role.dart';
import '../features/admin/admin_home_page.dart';
import '../features/admin/organization_detail_page.dart';
import '../features/admin/organizations_page.dart';
import '../features/attendee/attendee_home_page.dart';
import '../features/committee/committee_home_page.dart';
import '../features/organizer/committee_page.dart';
import '../features/organizer/event_detail_page.dart';
import '../features/organizer/event_form_page.dart';
import '../features/organizer/events_page.dart';
import '../features/organizer/organizer_home_page.dart';
import '../ui/forbidden_page.dart';
import '../ui/login_page.dart';
import '../ui/not_found_page.dart';
import '../ui/splash_page.dart';
import 'redirect.dart';

/// Nested routes stack their pages, so sub-pages get a back button that
/// returns to the parent (for example event detail back to the event list).
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
      GoRoute(
        path: UserRole.admin.homePath,
        builder: (context, state) => const AdminHomePage(),
        routes: [
          GoRoute(
            path: 'organizations',
            builder: (context, state) => const OrganizationsPage(),
            routes: [
              GoRoute(
                path: ':orgId',
                builder: (context, state) => OrganizationDetailPage(orgId: state.pathParameters['orgId']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: UserRole.organizer.homePath,
        builder: (context, state) => const OrganizerHomePage(),
        routes: [
          GoRoute(
            path: 'events',
            builder: (context, state) => const EventsPage(),
            routes: [
              // Listed before ':eventId' so "new" is not read as an ID.
              GoRoute(path: 'new', builder: (context, state) => const EventFormPage()),
              GoRoute(
                path: ':eventId',
                builder: (context, state) => EventDetailPage(eventId: state.pathParameters['eventId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => EventFormPage(eventId: state.pathParameters['eventId']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: 'committee', builder: (context, state) => const CommitteePage()),
        ],
      ),
      GoRoute(path: UserRole.committee.homePath, builder: (context, state) => const CommitteeHomePage()),
      GoRoute(path: UserRole.attendee.homePath, builder: (context, state) => const AttendeeHomePage()),
    ],
  );
}
