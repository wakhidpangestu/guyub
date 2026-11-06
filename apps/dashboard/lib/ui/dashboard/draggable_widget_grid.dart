import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'grid_layout.dart';

/// A grid of cards that can be rearranged by dragging.
///
/// - A mouse drags at once. Touch and stylus use a long press, so the page can
///   still be scrolled.
/// - Keyboard: focus a card, hold Alt, and press the arrow keys.
/// - Screen readers get "Move earlier" and "Move later" actions.
class DraggableWidgetGrid extends StatefulWidget {
  const DraggableWidgetGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.order,
    this.onReorder,
    this.maxColumns = 4,
    this.cellSize = 240,
    this.minRowHeight = 176,
    this.maxRowHeight = 216,
  });

  final List<GridItem> items;
  final Widget Function(BuildContext context, GridItem item) itemBuilder;

  /// Saved order of card IDs. Null is the order of [items].
  final List<String>? order;

  /// Called with the new order after a drop or a keyboard move.
  final ValueChanged<List<String>>? onReorder;

  final int maxColumns;

  /// Target cell width. The column count is derived from it.
  final double cellSize;

  /// Row height follows the cell width within these bounds, scaled with the
  /// user's text size so card content keeps fitting.
  final double minRowHeight;
  final double maxRowHeight;

  @override
  State<DraggableWidgetGrid> createState() => _DraggableWidgetGridState();
}

class _DraggableWidgetGridState extends State<DraggableWidgetGrid> with SingleTickerProviderStateMixin {
  static const _moveDuration = Duration(milliseconds: 380);
  static const _moveCurve = Cubic(0.34, 1.35, 0.64, 1);
  static const _settle = Duration(milliseconds: 40);
  static const _landedFor = Duration(milliseconds: 620);
  static const _longPress = Duration(milliseconds: 350);
  static const _scrollEdge = 72.0;
  static const _scrollSpeed = 14.0;

  late List<GridItem> _items = mergeOrder(widget.items, widget.order);
  late final Ticker _ticker = createTicker(_onTick);
  final _stackKey = GlobalKey();

  int _columns = 0;
  double _colStep = 0;
  double _rowStep = 0;
  double _gap = 12;
  double? _lastWidth;

  String? _dragging;
  String? _raised;
  String? _landed;
  Offset _pointer = Offset.zero;
  Offset _grab = Offset.zero;
  Offset _dragTopLeft = Offset.zero;
  List<GridItem>? _orderAtStart;
  Duration _now = Duration.zero;
  Duration _lastMove = Duration.zero;
  Timer? _landTimer;

  @override
  void didUpdateWidget(DraggableWidgetGrid old) {
    super.didUpdateWidget(old);
    final sameIds = setEquals({for (final i in old.items) i.id}, {for (final i in widget.items) i.id});
    if (!sameIds || !listEquals(old.order, widget.order)) {
      final next = mergeOrder(widget.items, widget.order);
      // The grid's own reorder comes back through [order]: nothing to do.
      if (!sameOrder(next, _items) || !sameIds) _items = next;
    } else {
      final byId = {for (final item in widget.items) item.id: item};
      _items = [for (final item in _items) byId[item.id]!];
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _landTimer?.cancel();
    super.dispose();
  }

  Rect _slot(int col, int row, int w, int h) => Rect.fromLTWH(
        col * _colStep,
        row * _rowStep,
        w * _colStep - _gap,
        h * _rowStep - _gap,
      );

  RenderBox? get _box => _stackKey.currentContext?.findRenderObject() as RenderBox?;

  void _startDrag(String id, Offset global) {
    final box = _box;
    if (box == null || _dragging != null) return;
    final place = layoutGrid(_items, _columns).firstWhere((p) => p.id == id);
    final rect = _slot(place.col, place.row, place.w, place.h);
    final local = box.globalToLocal(global);
    _landTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _dragging = id;
      _raised = id;
      _landed = null;
      _pointer = global;
      _grab = local - rect.topLeft;
      _dragTopLeft = rect.topLeft;
      _orderAtStart = _items;
      _lastMove = Duration.zero;
      _now = Duration.zero;
    });
    _ticker.start();
  }

  void _updateDrag(Offset global) {
    if (_dragging == null) return;
    _pointer = global;
    _followPointer();
  }

  void _followPointer() {
    final box = _box;
    if (box == null) return;
    setState(() => _dragTopLeft = box.globalToLocal(_pointer) - _grab);
  }

  void _endDrag() {
    final id = _dragging;
    if (id == null) return;
    _ticker.stop();
    _reorderStep(force: true);
    final before = _orderAtStart;
    setState(() {
      _dragging = null;
      _orderAtStart = null;
      _landed = id;
    });
    _landTimer = Timer(_landedFor, () {
      if (mounted) {
        setState(() {
          _landed = null;
          _raised = null;
        });
      }
    });
    if (before != null && !sameOrder(before, _items)) _publish();
  }

  void _publish() => widget.onReorder?.call([for (final item in _items) item.id]);

  /// Runs every frame during a drag, so a card held still still settles and a
  /// card held near the edge keeps scrolling.
  void _onTick(Duration elapsed) {
    _now = elapsed;
    _autoScroll();
    _reorderStep();
  }

  void _autoScroll() {
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject() as RenderBox?;
    if (scrollable == null || viewport == null) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    double delta = 0;
    if (_pointer.dy < top + _scrollEdge) {
      delta = -_scrollSpeed * ((top + _scrollEdge - _pointer.dy) / _scrollEdge).clamp(0, 1);
    } else if (_pointer.dy > bottom - _scrollEdge) {
      delta = _scrollSpeed * ((_pointer.dy - bottom + _scrollEdge) / _scrollEdge).clamp(0, 1);
    }
    if (delta == 0) return;
    final position = scrollable.position;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) {
      position.jumpTo(target);
      _followPointer();
    }
  }

  void _reorderStep({bool force = false}) {
    final id = _dragging;
    if (id == null || _columns == 0) return;
    if (!force && _now - _lastMove < _settle) return;
    final me = layoutGrid(_items, _columns).firstWhere((p) => p.id == id);
    final home = _slot(me.col, me.row, me.w, me.h);
    final centre = _dragTopLeft + home.size.center(Offset.zero);
    final order = chooseDrop(home, dropCandidates(_items, id, _columns, _slot), centre.dx, centre.dy);
    if (order == null) return;
    _lastMove = _now;
    setState(() => _items = canonicalOrder(order, _columns));
  }

  void _moveByKey(String id, int delta) {
    final next = moveByStep(_items, id, delta, _columns);
    if (sameOrder(next, _items)) return;
    setState(() => _items = next);
    _publish();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GuyubTokens.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _gap = tokens.sp(3);
        _columns = columnsFor(width, cellSize: widget.cellSize, maxColumns: widget.maxColumns);
        final unit = (width - _gap * (_columns - 1)) / _columns;
        final rowHeight = unit.clamp(widget.minRowHeight, widget.maxRowHeight) * textScale;
        _colStep = unit + _gap;
        _rowStep = rowHeight + _gap;

        // Resizing the window repositions at once instead of chasing the edge.
        final resized = _lastWidth != null && _lastWidth != width;
        _lastWidth = width;

        final places = {for (final p in layoutGrid(_items, _columns)) p.id: p};
        final rows = places.values.fold<int>(0, (n, p) => p.row + p.h > n ? p.row + p.h : n);
        final positions = {
          for (final (i, p) in inReadingOrder(places.values.toList()).indexed) p.id: i + 1,
        };

        // The stack paints in list order, so a lifted card goes last. Keys
        // keep each card's state when it moves in the list.
        final painted = [
          for (final item in widget.items)
            if (item.id != _raised) item,
          for (final item in widget.items)
            if (item.id == _raised) item,
        ];

        return SizedBox(
          key: _stackKey,
          height: rows == 0 ? 0 : rows * _rowStep - _gap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final item in painted)
                if (places[item.id] case final place?) _positioned(item, place, positions[item.id]!, places.length, resized || reduceMotion),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned(GridItem item, Placement place, int position, int count, bool instant) {
    final dragging = _dragging == item.id;
    final slot = _slot(place.col, place.row, place.w, place.h);
    return AnimatedPositioned.fromRect(
      key: ValueKey(item.id),
      rect: dragging ? _dragTopLeft & slot.size : slot,
      duration: dragging || instant ? Duration.zero : _moveDuration,
      curve: _moveCurve,
      child: _GridCard(
        label: item.label,
        position: position,
        count: count,
        lifted: dragging,
        landed: _landed == item.id,
        onMove: (delta) => _moveByKey(item.id, delta),
        gestures: {
          PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
            () => PanGestureRecognizer(supportedDevices: const {PointerDeviceKind.mouse}),
            (recognizer) => recognizer
              ..dragStartBehavior = DragStartBehavior.down
              ..onStart = ((details) => _startDrag(item.id, details.globalPosition))
              ..onUpdate = ((details) => _updateDrag(details.globalPosition))
              ..onEnd = ((_) => _endDrag())
              ..onCancel = _endDrag,
          ),
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: _longPress,
              supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus},
            ),
            (recognizer) => recognizer
              ..onLongPressStart = ((details) => _startDrag(item.id, details.globalPosition))
              ..onLongPressMoveUpdate = ((details) => _updateDrag(details.globalPosition))
              ..onLongPressEnd = ((_) => _endDrag())
              ..onLongPressCancel = _endDrag,
          ),
        },
        child: widget.itemBuilder(context, item),
      ),
    );
  }
}

/// One card's frame: lift, shadow, focus ring, keyboard, and semantics.
class _GridCard extends StatefulWidget {
  const _GridCard({
    required this.label,
    required this.position,
    required this.count,
    required this.lifted,
    required this.landed,
    required this.onMove,
    required this.gestures,
    required this.child,
  });

  final String label;
  final int position;
  final int count;
  final bool lifted;
  final bool landed;
  final ValueChanged<int> onMove;
  final Map<Type, GestureRecognizerFactory> gestures;
  final Widget child;

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  static const _moveEarlier = CustomSemanticsAction(label: 'Move earlier');
  static const _moveLater = CustomSemanticsAction(label: 'Move later');

  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    widget.onMove(delta);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GuyubTokens.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(tokens.radius * 1.5);
    final showRing = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final Border? ring = showRing
        ? Border.all(color: tokens.ring, width: 2)
        : widget.landed
            ? Border.all(color: tokens.foreground.withValues(alpha: 0.4), width: 2)
            : null;

    return Semantics(
      container: true,
      label: '${widget.label}, card ${widget.position} of ${widget.count}',
      customSemanticsActions: {
        _moveEarlier: () => widget.onMove(-1),
        _moveLater: () => widget.onMove(1),
      },
      child: Focus(
        onKeyEvent: _onKey,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: MouseRegion(
          cursor: widget.lifted ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
          child: RawGestureDetector(
            gestures: widget.gestures,
            child: AnimatedScale(
              scale: widget.lifted ? 1.03 : 1,
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                foregroundDecoration: ring == null ? null : BoxDecoration(borderRadius: radius, border: ring),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // The dark shadow token is wide and offset. On a near-black page it
                  // only shows where it falls on a bright neighbor, as a smudge.
                  boxShadow: [
                    if (widget.lifted) tokens.liftedShadow else if (tokens.brightness == Brightness.light) tokens.restShadow,
                  ],
                ),
                child: ClipRRect(borderRadius: radius, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
