import 'package:flutter/material.dart';

import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import '../members/members_section.dart';

class OrganizationDetailPage extends StatelessWidget {
  const OrganizationDetailPage({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final theme = Theme.of(context);
    return RoleShell(
      role: UserRole.admin,
      title: 'Organization',
      child: PageBody(
        children: [
          StreamView<Organization?>(
            streamKey: orgId,
            create: () => backend.watchOrganization(orgId),
            builder: (context, org) => org == null
                ? EmptyNote(icon: Icons.search_off, message: 'No organization with the ID "$orgId".')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(org.name, style: theme.textTheme.headlineSmall),
                      Text('ID: ${org.id}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      MembersSection(
                        orgId: org.id,
                        role: UserRole.organizer,
                        title: 'Organizers',
                        subtitle: 'Organizers create events and manage the committee for ${org.name}.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
