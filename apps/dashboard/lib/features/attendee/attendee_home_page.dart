import 'package:flutter/material.dart';

import '../../auth/user_role.dart';
import '../../ui/shell/role_home.dart';

class AttendeeHomePage extends StatelessWidget {
  const AttendeeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleHome(
      role: UserRole.attendee,
      intro: 'Find events, keep your tickets, and collect your certificates.',
      features: [
        PlannedFeature(
          icon: Icons.explore_outlined,
          title: 'Browse events',
          description: 'See active events from every organization on Guyub.',
          milestone: 'M3',
        ),
        PlannedFeature(
          icon: Icons.confirmation_number_outlined,
          title: 'My tickets',
          description: 'Your QR ticket for each event you registered for.',
          milestone: 'M3',
        ),
        PlannedFeature(
          icon: Icons.workspace_premium_outlined,
          title: 'Certificates',
          description: 'Certificates arrive here and by email after check-in.',
          milestone: 'M5',
        ),
        PlannedFeature(
          icon: Icons.photo_filter_outlined,
          title: 'Twibbon',
          description: 'Frame your photo with the event overlay, right in your browser.',
          milestone: 'M6',
        ),
      ],
    );
  }
}
