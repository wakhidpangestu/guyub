// Layout and drop-target logic of the draggable dashboard grid. Pure Dart, no
// widgets. A Dart port of the `draggable-widget-grid` reference component: the
// arrangement is a sequence plus a size per card, and an exact tiler turns the
// sequence into a gap-free rectangle at any column count.

import 'dart:math' as math;
import 'dart:ui' show Rect;

/// Column by row span of a card.
enum CardSize {
  sm(1, 1),
  wide(2, 1),
  tall(1, 2),
  lg(2, 2);

  const CardSize(this.cols, this.rows);

  final int cols;
  final int rows;
}

class GridItem {
  const GridItem({required this.id, required this.size, required this.label});

  final String id;
  final CardSize size;

  /// Accessible name of the card.
  final String label;
}

class Placement {
  Placement({required this.id, required this.col, required this.row, required this.w, required this.h});

  final String id;
  final int col;
  final int row;
  int w;
  int h;

  Placement at(int col, int row) => Placement(id: id, col: col, row: row, w: w, h: h);

  bool same(Placement other) => col == other.col && row == other.row && w == other.w && h == other.h;
}

class _Box {
  const _Box(this.col, this.row, this.w, this.h);

  final int col;
  final int row;
  final int w;
  final int h;

  factory _Box.of(Placement p) => _Box(p.col, p.row, p.w, p.h);

  bool overlaps(_Box other) =>
      col < other.col + other.w && other.col < col + w && row < other.row + other.h && other.row < row + h;

  bool contains(_Box inner) =>
      inner.col >= col && inner.row >= row && inner.col + inner.w <= col + w && inner.row + inner.h <= row + h;
}

/// Column count for a grid [width]: never fewer than two, so phones keep the
/// bento look instead of one long column.
int columnsFor(double width, {required double cellSize, required int maxColumns}) {
  final minColumns = math.min(2, math.max(1, maxColumns));
  return (width / cellSize).round().clamp(minColumns, maxColumns);
}

/// Places every card. Tries an exact tiling first (no gaps, no stretching) and
/// falls back to a row packer that grows cards to close gaps.
List<Placement> layoutGrid(List<GridItem> items, int columns) {
  if (columns < 1 || items.isEmpty) return [];
  return _tile(items, columns) ?? _pack(items, columns);
}

const _tilingBudget = 20000;

/// Exact tiling. The first empty cell in reading order takes the earliest card
/// that fits there and still lets the rest be placed.
List<Placement>? _tile(List<GridItem> items, int columns) {
  final spans = [for (final item in items) (w: math.min(item.size.cols, columns), h: item.size.rows)];
  final area = spans.fold<int>(0, (sum, s) => sum + s.w * s.h);
  final rows = (area / columns).ceil();
  final grid = List<bool>.filled(rows * columns, false);
  final used = List<bool>.filled(items.length, false);
  final out = <Placement>[];
  var budget = _tilingBudget;

  bool fits(int w, int h, int r, int c) {
    if (c + w > columns || r + h > rows) return false;
    for (var y = r; y < r + h; y++) {
      for (var x = c; x < c + w; x++) {
        if (grid[y * columns + x]) return false;
      }
    }
    return true;
  }

  void mark(int w, int h, int r, int c, bool value) {
    for (var y = r; y < r + h; y++) {
      for (var x = c; x < c + w; x++) {
        grid[y * columns + x] = value;
      }
    }
  }

  bool place(int count) {
    if (count == items.length) return true;
    if (--budget < 0) return false;
    final i = grid.indexOf(false);
    if (i < 0) return false;
    final r = i ~/ columns;
    final c = i % columns;
    // Cards of the same shape are interchangeable at this cell.
    final tried = <(int, int)>{};
    for (var k = 0; k < items.length; k++) {
      if (used[k]) continue;
      final (:w, :h) = spans[k];
      if (tried.contains((w, h)) || !fits(w, h, r, c)) continue;
      tried.add((w, h));
      used[k] = true;
      mark(w, h, r, c, true);
      out.add(Placement(id: items[k].id, col: c, row: r, w: w, h: h));
      if (place(count + 1)) return true;
      out.removeLast();
      mark(w, h, r, c, false);
      used[k] = false;
    }
    return false;
  }

  return place(0) ? out : null;
}

/// Fallback: fill rows in order, then widen cards to close each row.
List<Placement> _pack(List<GridItem> items, int columns) {
  final out = <Placement>[];
  var row = 0;
  var queue = [
    for (final item in items) Placement(id: item.id, col: 0, row: 0, w: math.min(item.size.cols, columns), h: item.size.rows),
  ];

  while (queue.isNotEmpty) {
    final height = queue.take(columns).map((q) => q.h).reduce(math.max);
    final cells = List<bool>.filled(height * columns, false);
    final band = <Placement>[];
    final rest = <Placement>[];

    for (final q in queue) {
      var spot = -1;
      for (var i = 0; i < cells.length && spot < 0; i++) {
        final r = i ~/ columns;
        final c = i % columns;
        if (c + q.w > columns || r + q.h > height) continue;
        var free = true;
        for (var y = r; y < r + q.h && free; y++) {
          for (var x = c; x < c + q.w && free; x++) {
            if (cells[y * columns + x]) free = false;
          }
        }
        if (free) spot = i;
      }
      if (spot < 0 || rest.isNotEmpty) {
        rest.add(q);
        continue;
      }
      final r = spot ~/ columns;
      final c = spot % columns;
      for (var y = r; y < r + q.h; y++) {
        for (var x = c; x < c + q.w; x++) {
          cells[y * columns + x] = true;
        }
      }
      band.add(q.at(c, r));
    }

    // Grow cards right, then down, into any cell left empty.
    for (var i = 0; i < cells.length; i++) {
      if (cells[i]) continue;
      final r = i ~/ columns;
      final c = i % columns;
      Placement? left;
      Placement? above;
      for (final p in band) {
        if (p.col + p.w == c && p.row <= r && p.row + p.h > r && p.h == 1) left ??= p;
        if (p.row + p.h == r && p.col == c && p.w == 1) above ??= p;
      }
      final grow = left ?? above;
      if (grow == null) continue;
      if (identical(grow, left)) {
        grow.w += 1;
      } else {
        grow.h += 1;
      }
      cells[i] = true;
    }

    out.addAll(band.map((p) => p.at(p.col, p.row + row)));
    row += height;
    queue = rest;
  }
  return out;
}

/// Reorders [items] to match the reading order of their layout, when that
/// produces the same layout.
List<GridItem> canonicalOrder(List<GridItem> items, int columns) {
  final places = layoutGrid(items, columns);
  if (places.length != items.length) return items;
  final byId = {for (final item in items) item.id: item};
  final sorted = ([...places]..sort(_readingOrder)).map((p) => byId[p.id]!).toList();
  if (sameOrder(sorted, items)) return items;
  final at = {for (final p in places) p.id: p};
  final same = layoutGrid(sorted, columns).every((p) => at[p.id]!.same(p));
  return same ? sorted : items;
}

int _readingOrder(Placement a, Placement b) => a.row != b.row ? a.row - b.row : a.col - b.col;

/// [placements] in the order a person reads them.
List<Placement> inReadingOrder(List<Placement> placements) => [...placements]..sort(_readingOrder);

List<GridItem> moveToIndex(List<GridItem> items, String id, int index) {
  final from = items.indexWhere((item) => item.id == id);
  if (from < 0 || from == index || index < 0 || index >= items.length) return items;
  final next = [...items];
  final moved = next.removeAt(from);
  next.insert(index, moved);
  return next;
}

bool sameOrder(List<GridItem> a, List<GridItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

/// Moves a card one step earlier ([delta] -1) or later (+1), stepping until
/// the arrangement actually changes. Returns [items] when it cannot move.
List<GridItem> moveByStep(List<GridItem> items, String id, int delta, int columns) {
  final from = items.indexWhere((item) => item.id == id);
  for (var to = from + delta; to >= 0 && to < items.length; to += delta) {
    final next = canonicalOrder(moveToIndex(items, id, to), columns);
    if (!sameOrder(next, items)) return next;
  }
  return items;
}

/// Applies a saved [order] to [items]. Unknown IDs are dropped, and cards the
/// saved order does not know yet keep their default place at the end.
List<GridItem> mergeOrder(List<GridItem> items, List<String>? order) {
  if (order == null) return items;
  final byId = {for (final item in items) item.id: item};
  final known = [for (final id in order) ?byId[id]];
  final seen = {for (final item in known) item.id};
  return [...known, ...items.where((item) => !seen.contains(item.id))];
}

class DropCandidate {
  const DropCandidate(this.order, this.slot);

  final List<GridItem> order;
  final Rect slot;
}

/// Fraction of a slot the dragged card's centre must enter to take it.
const _enter = 0.18;

/// Picks the arrangement whose slot for the dragged card is nearest to its
/// centre, or null to keep the current one.
///
/// Candidates are measured to a slot shrunk by [_enter]; the current slot is
/// measured unshrunk. Every accepted move therefore strictly reduces that
/// distance, which rules out oscillating between arrangements.
List<GridItem>? chooseDrop(Rect home, List<DropCandidate> candidates, double cx, double cy) {
  double distance(Rect s, double inset) {
    final ix = s.width * inset;
    final iy = s.height * inset;
    final dx = [s.left + ix - cx, 0.0, cx - (s.right - ix)].reduce(math.max);
    final dy = [s.top + iy - cy, 0.0, cy - (s.bottom - iy)].reduce(math.max);
    return math.sqrt(dx * dx + dy * dy);
  }

  double toCentre(Rect s) {
    final dx = s.center.dx - cx;
    final dy = s.center.dy - cy;
    return math.sqrt(dx * dx + dy * dy);
  }

  var best = distance(home, 0);
  if (best == 0) return null;
  List<GridItem>? pick;
  var bestCentre = double.infinity;
  for (final candidate in candidates) {
    final d = distance(candidate.slot, _enter);
    final c = toCentre(candidate.slot);
    // On a tie the earlier candidate wins; group swaps are listed first.
    if (d < best || (d == best && pick != null && c < bestCentre)) {
      best = d;
      bestCentre = c;
      pick = candidate.order;
    }
  }
  return pick;
}

/// Every arrangement one move away from [items]:
/// - group swaps: a same-shaped area filled entirely by smaller cards trades
///   places with the dragged card, keeping its internal arrangement;
/// - sequence moves: the dragged card takes another index.
List<DropCandidate> dropCandidates(
  List<GridItem> items,
  String id,
  int columns,
  Rect Function(int col, int row, int w, int h) toSlot,
) {
  final places = layoutGrid(items, columns);
  final me = places.where((p) => p.id == id).firstOrNull;
  if (me == null) return [];
  final byId = {for (final item in items) item.id: item};
  final rows = places.map((p) => p.row + p.h).reduce(math.max);
  final mine = _Box.of(me);
  final out = <DropCandidate>[];

  for (var row = 0; row + me.h <= rows; row++) {
    for (var col = 0; col + me.w <= columns; col++) {
      final area = _Box(col, row, me.w, me.h);
      if (area.overlaps(mine)) continue;
      final group = places.where((p) => _Box.of(p).overlaps(area)).toList();
      if (group.length < 2 || !group.every((p) => area.contains(_Box.of(p)))) continue;
      final moved = [
        for (final p in places)
          if (p.id == id)
            p.at(col, row)
          else if (group.contains(p))
            p.at(p.col - col + me.col, p.row - row + me.row)
          else
            p,
      ]..sort(_readingOrder);
      out.add(DropCandidate([for (final p in moved) byId[p.id]!], toSlot(col, row, me.w, me.h)));
    }
  }

  final from = items.indexWhere((item) => item.id == id);
  for (var i = 0; i < items.length; i++) {
    if (i == from) continue;
    final order = moveToIndex(items, id, i);
    final p = layoutGrid(order, columns).where((q) => q.id == id).firstOrNull;
    if (p != null) out.add(DropCandidate(order, toSlot(p.col, p.row, p.w, p.h)));
  }
  return out;
}
