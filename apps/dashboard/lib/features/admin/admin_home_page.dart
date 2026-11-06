import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/dashboard/dashboard_grid.dart';
import '../../ui/dashboard/grid_layout.dart';
import '../../ui/dashboard/tiles.dart';
import '../../ui/shell/role_home.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/stream_view.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    return RoleHome(
      role: UserRole.admin,
      child: StreamView<List<Organization>>(
        create: backend.watchOrganizations,
        loading: const DashboardSkeleton(),
        builder: (context, organizations) => DashboardGrid(
          layoutName: 'admin',
          cards: [
            DashboardCard(
              id: 'hero',
              size: CardSize.wide,
              label: 'Welcome',
              builder: (context) => HeroTile(
                title: welcomeBack(context),
                intro: 'Manage organizations and organizer accounts across Guyub.',
                actionLabel: 'Manage organizations',
                actionIcon: Icons.apartment_outlined,
                onAction: () => context.go('/admin/organizations'),
              ),
            ),
            DashboardCard(
              id: 'organizations',
              size: CardSize.sm,
              label: 'Organizations',
              builder: (context) => StatTile(
                label: 'Organizations',
                value: '${organizations.length}',
                hint: 'Ormawa and communities on Guyub',
                icon: Icons.apartment_outlined,
                tone: TileTone.cyan,
                onTap: () => context.go('/admin/organizations'),
              ),
            ),
            DashboardCard(
              id: 'metrics',
              size: CardSize.sm,
              label: 'Platform metrics, planned',
              builder: (context) => const PlannedTile(
                title: 'Platform metrics',
                description: 'Events, registrations, and check-ins across organizations.',
                icon: Icons.insights_outlined,
                milestone: 'M6',
              ),
            ),
            DashboardCard(
              id: 'list',
              size: CardSize.lg,
              label: 'Organization list',
              builder: (context) => _OrganizationsCard(organizations: organizations),
            ),
            DashboardCard(
              id: 'organizers',
              size: CardSize.wide,
              label: 'Adding organizers',
              builder: (context) => const _InfoCard(
                tone: TileTone.violet,
                icon: Icons.person_add_alt,
                title: 'Adding organizers',
                body: 'Open an organization and add organizers by email. People without an account get the role at their first sign-in.',
              ),
            ),
            DashboardCard(
              id: 'retention',
              size: CardSize.wide,
              label: 'Data retention',
              builder: (context) => const _InfoCard(
                tone: TileTone.orchid,
                icon: Icons.shield_outlined,
                title: 'Data retention',
                body: 'Attendance records and ticket keys are deleted automatically 12 months after each event.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.tone, required this.icon, required this.title, required this.body});

  final TileTone tone;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tile(
      tone: tone,
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TileHeader(title, icon: icon),
              const SizedBox(height: 8),
              Expanded(
                child: Text(body, overflow: TextOverflow.fade, style: theme.textTheme.bodyMedium?.copyWith(color: colors.ink)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrganizationsCard extends StatelessWidget {
  const _OrganizationsCard({required this.organizations});

  final List<Organization> organizations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    return Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Organization list', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium)),
              TextButton(onPressed: () => context.go('/admin/organizations'), child: const Text('View all')),
            ],
          ),
          SizedBox(height: tokens.sp(1)),
          Expanded(
            child: organizations.isEmpty
                ? Center(
                    child: Text('Nothing here yet. Create the first organization to get started.',
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground)),
                  )
                : FitList(
                    rowHeight: 52,
                    count: organizations.length,
                    builder: (context, i) {
                      final organization = organizations[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(tokens.radius * 0.75),
                        onTap: () => context.go('/admin/organizations/${organization.id}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: [
                              InitialsAvatar(organization.name),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(organization.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                                    Text(organization.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: tokens.mutedForeground),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
