import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';

class OrganizationsPage extends StatelessWidget {
  const OrganizationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    return RoleShell(
      role: UserRole.admin,
      title: 'Organizations',
      child: PageBody(
        children: [
          SectionHeader(
            'Organizations',
            subtitle: 'Each organization has its own organizers, committee, and events.',
            action: FilledButton.icon(
              onPressed: () => showDialog<void>(context: context, builder: (_) => const CreateOrganizationDialog()),
              icon: const Icon(Icons.add),
              label: const Text('New organization'),
            ),
          ),
          StreamView<List<Organization>>(
            create: backend.watchOrganizations,
            isEmpty: (orgs) => orgs.isEmpty,
            empty: const EmptyNote(icon: Icons.apartment_outlined, message: 'No organizations yet. Create the first one.'),
            builder: (context, orgs) => Card(
              child: Column(
                children: [
                  for (final org in orgs)
                    ListTile(
                      leading: const Icon(Icons.apartment_outlined),
                      title: Text(org.name),
                      subtitle: Text(org.id),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/admin/organizations/${org.id}'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Name and ID for a new organization. The ID follows the name until the
/// admin edits it, and cannot change later.
class CreateOrganizationDialog extends StatefulWidget {
  const CreateOrganizationDialog({super.key});

  @override
  State<CreateOrganizationDialog> createState() => _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<CreateOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  bool _slugEdited = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final backend = BackendScope.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final slug = _slug.text.trim();

    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => backend.createOrganization(name: _name.text, slug: slug),
      success: '${_name.text.trim()} created.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      navigator.pop();
      router.go('/admin/organizations/$slug');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New organization'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'HIMATIF ITB', border: OutlineInputBorder()),
                validator: (value) => Organization.nameError(value ?? ''),
                onChanged: (value) {
                  if (!_slugEdited) _slug.text = slugify(value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'ID',
                  helperText: 'Used in links. Cannot be changed later.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => Organization.slugError((value ?? '').trim()),
                onChanged: (_) => _slugEdited = true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Create')),
      ],
    );
  }
}
