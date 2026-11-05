import 'package:flutter/material.dart';

import '../../auth/user_role.dart';
import '../../ui/shell/role_home.dart';

class CommitteeHomePage extends StatelessWidget {
  const CommitteeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleHome(
      role: UserRole.committee,
      intro: 'Check in attendees for the events you are assigned to.',
      features: [
        PlannedFeature(
          icon: Icons.qr_code_scanner,
          title: 'QR scanner',
          description: 'Scan an attendee ticket with your phone camera to check them in.',
          milestone: 'M4',
        ),
        PlannedFeature(
          icon: Icons.event_available_outlined,
          title: 'Assigned events',
          description: 'Only events your organizer assigned you to appear here.',
          milestone: 'M4',
        ),
      ],
    );
  }
}
