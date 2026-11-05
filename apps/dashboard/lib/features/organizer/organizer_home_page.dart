import 'package:flutter/material.dart';

import '../../auth/user_role.dart';
import '../../ui/shell/role_home.dart';

class OrganizerHomePage extends StatelessWidget {
  const OrganizerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleHome(
      role: UserRole.organizer,
      intro: 'Plan events, assign your committee, and track attendance.',
      features: [
        Feature(
          icon: Icons.event_outlined,
          title: 'Events',
          description: 'Create drafts, publish events, and open registration.',
          route: '/organizer/events',
        ),
        Feature(
          icon: Icons.groups_outlined,
          title: 'Committee',
          description: 'Add committee members by email. Assign them to events for QR check-in.',
          route: '/organizer/committee',
        ),
        Feature(
          icon: Icons.workspace_premium_outlined,
          title: 'Certificates',
          description: 'Upload a certificate template. Certificates are emailed on check-in.',
          milestone: 'M5',
        ),
        Feature(
          icon: Icons.table_chart_outlined,
          title: 'Export to Google Sheets',
          description: 'Send registrations and attendance to a Google Sheet.',
          milestone: 'M6',
        ),
      ],
    );
  }
}
