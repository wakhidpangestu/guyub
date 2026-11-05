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
        PlannedFeature(
          icon: Icons.event_outlined,
          title: 'Events',
          description: 'Create drafts, publish events, and open registration.',
          milestone: 'M2',
        ),
        PlannedFeature(
          icon: Icons.groups_outlined,
          title: 'Committee',
          description: 'Assign committee members to each event for QR check-in.',
          milestone: 'M2',
        ),
        PlannedFeature(
          icon: Icons.workspace_premium_outlined,
          title: 'Certificates',
          description: 'Upload a certificate template. Certificates are emailed on check-in.',
          milestone: 'M5',
        ),
        PlannedFeature(
          icon: Icons.table_chart_outlined,
          title: 'Export to Google Sheets',
          description: 'Send registrations and attendance to a Google Sheet.',
          milestone: 'M6',
        ),
      ],
    );
  }
}
