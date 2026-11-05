import 'package:flutter/material.dart';

import '../../auth/user_role.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import '../members/members_section.dart';
import 'organizer_session.dart';

class CommitteePage extends StatelessWidget {
  const CommitteePage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgId = organizerOrgId(context);
    return RoleShell(
      role: UserRole.organizer,
      title: 'Committee',
      child: PageBody(
        children: [
          if (orgId == null)
            const ErrorNote('Your account has no organization. Ask a Guyub admin to fix your organizer access.')
          else
            MembersSection(
              orgId: orgId,
              role: UserRole.committee,
              title: 'Committee members',
              subtitle: 'Committee members only see and scan the events you assign them to.',
            ),
        ],
      ),
    );
  }
}
