import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_role.dart';
import '../dashboard/tiles.dart';
import '../tokens.dart';
import '../ui_prefs.dart';

/// From this width the sidebar is permanent. Below it, it is a drawer.
const sidebarBreakpoint = 960.0;

/// A sidebar entry. Built features have a [route]. Features not built yet have
/// a [milestone]: the handbook requires them to be labelled as planned.
class NavEntry {
  const NavEntry(this.icon, this.label, {this.route, this.milestone})
      : assert((route == null) != (milestone == null), 'An entry has either a route or a milestone.');

  final IconData icon;
  final String label;
  final String? route;

  /// Milestone from docs/SPEC.md §7, for example "M5".
  final String? milestone;
}

List<NavEntry> navEntriesFor(UserRole role) => switch (role) {
      UserRole.admin => const [
          NavEntry(Icons.dashboard_outlined, 'Dashboard', route: '/admin'),
          NavEntry(Icons.apartment_outlined, 'Organizations', route: '/admin/organizations'),
          NavEntry(Icons.insights_outlined, 'Platform metrics', milestone: 'M6'),
        ],
      UserRole.organizer => const [
          NavEntry(Icons.dashboard_outlined, 'Dashboard', route: '/organizer'),
          NavEntry(Icons.event_outlined, 'Events', route: '/organizer/events'),
          NavEntry(Icons.groups_outlined, 'Committee', route: '/organizer/committee'),
          NavEntry(Icons.workspace_premium_outlined, 'Certificates', milestone: 'M5'),
          NavEntry(Icons.table_chart_outlined, 'Sheets export', milestone: 'M6'),
        ],
      UserRole.committee => const [
          NavEntry(Icons.dashboard_outlined, 'Dashboard', route: '/committee'),
        ],
      UserRole.attendee => const [
          NavEntry(Icons.dashboard_outlined, 'Dashboard', route: '/attendee'),
          NavEntry(Icons.explore_outlined, 'Browse events', route: '/attendee/events'),
          NavEntry(Icons.confirmation_number_outlined, 'My tickets', route: '/attendee/tickets'),
          NavEntry(Icons.workspace_premium_outlined, 'Certificates', milestone: 'M5'),
          NavEntry(Icons.photo_filter_outlined, 'Twibbon', milestone: 'M6'),
        ],
    };

/// The longest route that is a prefix of [path], which marks the current entry.
String? activeRoute(List<NavEntry> entries, String path) {
  String? best;
  for (final entry in entries) {
    final route = entry.route;
    if (route == null) continue;
    final matches = path == route || path.startsWith('$route/');
    if (matches && route.length > (best?.length ?? 0)) best = route;
  }
  return best;
}

/// Frame shared by every role's area: sidebar and a header with the account
/// menu. The role's home passes no [title]. Sub-pages pass one and get a back
/// button from the router's page stack.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.role, required this.child, this.title});

  final UserRole role;
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final tokens = GuyubTokens.of(context);
    final path = GoRouterState.of(context).uri.path;
    final permanent = MediaQuery.sizeOf(context).width >= sidebarBreakpoint;
    final collapsed = permanent && UiPrefsScope.of(context).sidebarCollapsed;

    return Scaffold(
      backgroundColor: tokens.background,
      drawer: permanent ? null : Drawer(child: SafeArea(child: _Sidebar(role: role, path: path, collapsed: false, inDrawer: true))),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (permanent) _Sidebar(role: role, path: path, collapsed: collapsed, inDrawer: false),
            // Expanded also stops wide content from pushing past the viewport.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(role: role, title: title, permanentSidebar: permanent),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.role, required this.title, required this.permanentSidebar});

  final UserRole role;
  final String? title;
  final bool permanentSidebar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    final prefs = UiPrefsScope.of(context);
    final canPop = Navigator.of(context).canPop();
    final dark = theme.brightness == Brightness.dark;
    final isHome = title == null;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          if (permanentSidebar)
            IconButton(
              tooltip: prefs.sidebarCollapsed ? 'Expand navigation' : 'Collapse navigation',
              onPressed: prefs.toggleSidebar,
              icon: const Icon(Icons.view_sidebar_outlined),
            )
          else if (!canPop || isHome)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
          if (canPop && !isHome) const BackButton(),
          const SizedBox(width: 4),
          // One Expanded, so the actions stay at the right edge and the title
          // and role chip share only the room that is left.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title ?? 'Dashboard',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
                    ),
                  ),
                ),
                if (isHome) ...[
                  const SizedBox(width: 8),
                  Flexible(child: Chip(label: Text(role.label, maxLines: 1, overflow: TextOverflow.ellipsis), visualDensity: VisualDensity.compact)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: dark ? 'Use light theme' : 'Use dark theme',
            onPressed: () => prefs.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          const _AccountMenu(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.role, required this.path, required this.collapsed, required this.inDrawer});

  final UserRole role;
  final String path;
  final bool collapsed;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    final entries = navEntriesFor(role);
    final active = activeRoute(entries, path);
    final built = entries.where((entry) => entry.route != null).toList();
    final planned = entries.where((entry) => entry.route == null).toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
          alignment: collapsed ? Alignment.center : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(colors: [tokens.chart1, tokens.chart5], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: const Icon(Icons.diversity_3, color: Colors.white, size: 20),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Text('Guyub', style: theme.textTheme.titleLarge?.copyWith(color: tokens.sidebarForeground, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final entry in built) _NavItem(entry: entry, selected: entry.route == active, collapsed: collapsed, inDrawer: inDrawer),
              if (planned.isNotEmpty) ...[
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                    child: Text('Planned', style: theme.textTheme.labelSmall?.copyWith(color: tokens.mutedForeground)),
                  )
                else
                  const SizedBox(height: 20),
                for (final entry in planned) _NavItem(entry: entry, selected: false, collapsed: collapsed, inDrawer: inDrawer),
              ],
            ],
          ),
        ),
      ],
    );

    if (inDrawer) return content;
    return Container(
      width: collapsed ? 72 : 256,
      decoration: BoxDecoration(
        color: tokens.sidebar,
        border: Border(right: BorderSide(color: tokens.sidebarBorder)),
      ),
      child: content,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.entry, required this.selected, required this.collapsed, required this.inDrawer});

  final NavEntry entry;
  final bool selected;
  final bool collapsed;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GuyubTokens.of(context);
    final route = entry.route;
    final planned = route == null;
    final color = selected
        ? t.sidebarAccentText
        : planned
            ? t.mutedForeground
            : t.sidebarForeground;
    final name = planned ? '${entry.label}, planned for ${entry.milestone}' : entry.label;

    Widget item = Semantics(
      button: !planned,
      enabled: !planned,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? t.sidebarAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(t.radius * 0.75),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radius * 0.75),
          // A null onTap would also hide the hover state, which suits a
          // planned entry: it looks and acts as not clickable.
          onTap: planned
              ? null
              : () {
                  if (inDrawer) Scaffold.of(context).closeDrawer();
                  context.go(route);
                },
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 12),
                Icon(entry.icon, size: 20, color: color),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                    ),
                  ),
                  if (planned) TonePill(entry.milestone!, background: t.muted, foreground: t.foreground),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (collapsed) item = Tooltip(message: name, child: item);
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: item);
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final session = auth.state;
    if (session is! SignedIn) return const SizedBox.shrink();

    final tokens = GuyubTokens.of(context);
    final initial = session.name.isEmpty ? '?' : session.name.characters.first.toUpperCase();
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Account',
      onSelected: (action) => switch (action) {
        _MenuAction.refresh => auth.refreshClaims(),
        _MenuAction.signOut => auth.signOut(),
      },
      itemBuilder: (context) => [
        PopupMenuItem<_MenuAction>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session.name),
            subtitle: Text([
              if (session.email != null) session.email!,
              if (session.orgId != null) 'Org: ${session.orgId}',
            ].join('\n')),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _MenuAction.refresh, child: Text('Refresh access')),
        const PopupMenuItem(value: _MenuAction.signOut, child: Text('Sign out')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentText,
          child: Text(initial, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.accentText)),
        ),
      ),
    );
  }
}

enum _MenuAction { refresh, signOut }
