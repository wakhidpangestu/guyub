import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
import '../tokens.dart';
import '../ui_prefs.dart';
import 'draggable_widget_grid.dart';
import 'grid_layout.dart';

/// A card on a role's dashboard.
class DashboardCard {
  const DashboardCard({required this.id, required this.size, required this.label, required this.builder});

  /// Stable: saved card orders refer to it.
  final String id;
  final CardSize size;

  /// Accessible name, also shown in the Arrange dialog.
  final String label;
  final WidgetBuilder builder;
}

/// A role's draggable cards, with the order saved per person on this device.
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({super.key, required this.layoutName, required this.cards});

  /// Usually the role, for example "organizer".
  final String layoutName;
  final List<DashboardCard> cards;

  @override
  Widget build(BuildContext context) {
    final prefs = UiPrefsScope.of(context);
    final session = AuthScope.of(context).state;
    final key = '${session is SignedIn ? session.uid : 'anonymous'}.$layoutName';
    final items = [for (final card in cards) GridItem(id: card.id, size: card.size, label: card.label)];
    final byId = {for (final card in cards) card.id: card};
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Drag a card to move it. On touch screens, press and hold first.',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _ArrangeDialog(prefs: prefs, layoutKey: key, items: items),
              ),
              icon: const Icon(Icons.swap_vert, size: 18),
              label: const Text('Arrange'),
            ),
          ],
        ),
        SizedBox(height: tokens.sp(2)),
        DraggableWidgetGrid(
          items: items,
          order: prefs.layout(key),
          onReorder: (ids) => prefs.saveLayout(key, ids),
          itemBuilder: (context, item) => byId[item.id]!.builder(context),
        ),
      ],
    );
  }
}

/// The alternative to dragging: one tap or key press per move (WCAG 2.5.7).
class _ArrangeDialog extends StatefulWidget {
  const _ArrangeDialog({required this.prefs, required this.layoutKey, required this.items});

  final UiPrefs prefs;
  final String layoutKey;
  final List<GridItem> items;

  @override
  State<_ArrangeDialog> createState() => _ArrangeDialogState();
}

class _ArrangeDialogState extends State<_ArrangeDialog> {
  late List<GridItem> _order = mergeOrder(widget.items, widget.prefs.layout(widget.layoutKey));

  void _move(int from, int to) {
    setState(() => _order = moveToIndex(_order, _order[from].id, to));
    widget.prefs.saveLayout(widget.layoutKey, [for (final item in _order) item.id]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Arrange cards'),
      content: SizedBox(
        width: 420,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _order.length,
          itemBuilder: (context, i) {
            final item = _order[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move ${item.label} up',
                    onPressed: i == 0 ? null : () => _move(i, i - 1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Move ${item.label} down',
                    onPressed: i == _order.length - 1 ? null : () => _move(i, i + 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.prefs.resetLayout(widget.layoutKey);
            setState(() => _order = widget.items);
          },
          child: const Text('Reset order'),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}

/// Reserves the space of the cards while their data loads.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = GuyubTokens.of(context);
    final gap = tokens.sp(3);
    return Semantics(
      label: 'Loading your dashboard',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = columnsFor(constraints.maxWidth, cellSize: 240, maxColumns: 4);
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Padding(
            padding: const EdgeInsets.only(top: 52),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < 8; i++)
                  Container(
                    width: width,
                    height: 176,
                    decoration: BoxDecoration(color: tokens.muted, borderRadius: BorderRadius.circular(tokens.radius * 1.5)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
