import 'package:flutter/material.dart';

import '../../auth/user_role.dart';
import '../../ui/shell/role_home.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleHome(
      role: UserRole.admin,
      intro: 'Manage organizations and organizer accounts across Guyub.',
      features: [
        PlannedFeature(
          icon: Icons.apartment_outlined,
          title: 'Organizations',
          description: 'Create and disable organizations (Ormawa, communities).',
          milestone: 'M2',
        ),
        PlannedFeature(
          icon: Icons.manage_accounts_outlined,
          title: 'Organizer accounts',
          description: 'Grant the organizer role to a user for one organization.',
          milestone: 'M2',
        ),
        PlannedFeature(
          icon: Icons.insights_outlined,
          title: 'Platform metrics',
          description: 'Events, registrations, and check-ins across all organizations.',
          milestone: 'M6',
        ),
      ],
    );
  }
}
