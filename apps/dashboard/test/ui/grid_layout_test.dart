import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/ui/dashboard/grid_layout.dart';

GridItem item(String id, CardSize size) => GridItem(id: id, size: size, label: id);

/// No card sticks out of the grid and no two cards share a cell.
void expectValid(List<Placement> places, int columns) {
  final seen = <(int, int)>{};
  for (final p in places) {
    expect(p.col + p.w, lessThanOrEqualTo(columns), reason: '${p.id} sticks out');
    for (var y = p.row; y < p.row + p.h; y++) {
      for (var x = p.col; x < p.col + p.w; x++) {
        expect(seen.add((x, y)), isTrue, reason: '${p.id} overlaps at $x,$y');
      }
    }
  }
}

void main() {
  final dashboard = [
    item('hero', CardSize.wide),
    item('a', CardSize.sm),
    item('b', CardSize.sm),
    item('chart', CardSize.lg),
    item('next', CardSize.wide),
    item('activity', CardSize.wide),
    item('events', CardSize.lg),
    item('c', CardSize.sm),
    item('d', CardSize.sm),
    item('e', CardSize.sm),
    item('f', CardSize.sm),
  ];

  group('layoutGrid', () {
    test('tiles the organizer dashboard without gaps at 4 columns', () {
      final places = layoutGrid(dashboard, 4);
      expectValid(places, 4);
      final area = places.fold<int>(0, (sum, p) => sum + p.w * p.h);
      final rows = places.map((p) => p.row + p.h).reduce((a, b) => a > b ? a : b);
      expect(area, rows * 4, reason: 'a gap-free rectangle');
      expect(places.firstWhere((p) => p.id == 'hero').col, 0);
      expect(places.firstWhere((p) => p.id == 'next').col, 2);
    });

    for (final columns in [2, 3, 4]) {
      test('stays valid at $columns columns', () {
        final places = layoutGrid(dashboard, columns);
        expect(places, hasLength(dashboard.length));
        expectValid(places, columns);
      });
    }

    test('a wide card narrows to fit one column', () {
      final places = layoutGrid([item('a', CardSize.wide)], 1);
      expect(places.single.w, 1);
    });

    test('an arrangement with no exact tiling falls back to the packer', () {
      final tricky = [item('a', CardSize.tall), item('b', CardSize.wide), item('c', CardSize.wide), item('d', CardSize.tall)];
      final places = layoutGrid(tricky, 3);
      expect(places, hasLength(4));
      expectValid(places, 3);
    });

    test('empty input', () {
      expect(layoutGrid([], 4), isEmpty);
    });
  });

  group('columnsFor', () {
    test('phones keep two columns, large screens stop at the maximum', () {
      expect(columnsFor(288, cellSize: 240, maxColumns: 4), 2);
      expect(columnsFor(343, cellSize: 240, maxColumns: 4), 2);
      expect(columnsFor(720, cellSize: 240, maxColumns: 4), 3);
      expect(columnsFor(5000, cellSize: 240, maxColumns: 4), 4);
    });
  });

  group('order helpers', () {
    test('moveToIndex moves one card and ignores bad indexes', () {
      final items = [item('a', CardSize.sm), item('b', CardSize.sm), item('c', CardSize.sm)];
      expect(moveToIndex(items, 'a', 2).map((i) => i.id), ['b', 'c', 'a']);
      expect(identical(moveToIndex(items, 'a', 9), items), isTrue);
      expect(identical(moveToIndex(items, 'x', 1), items), isTrue);
    });

    test('moveByStep skips moves that change nothing, and stops at the ends', () {
      final items = [item('a', CardSize.sm), item('b', CardSize.sm), item('c', CardSize.sm)];
      expect(moveByStep(items, 'a', 1, 4).map((i) => i.id), ['b', 'a', 'c']);
      expect(identical(moveByStep(items, 'a', -1, 4), items), isTrue);
      expect(identical(moveByStep(items, 'c', 1, 4), items), isTrue);
    });

    test('mergeOrder drops unknown cards and appends new ones', () {
      final items = [item('a', CardSize.sm), item('b', CardSize.sm), item('new', CardSize.sm)];
      expect(mergeOrder(items, ['b', 'gone', 'a']).map((i) => i.id), ['b', 'a', 'new']);
      expect(identical(mergeOrder(items, null), items), isTrue);
    });
  });

  group('drop targets', () {
    Rect slot(int col, int row, int w, int h) => Rect.fromLTWH(col * 110.0, row * 110.0, w * 110.0 - 10, h * 110.0 - 10);

    test('a card held over its own slot stays', () {
      final items = [item('a', CardSize.sm), item('b', CardSize.sm)];
      final home = slot(0, 0, 1, 1);
      expect(chooseDrop(home, dropCandidates(items, 'a', 2, slot), home.center.dx, home.center.dy), isNull);
    });

    test('a card dragged onto a neighbour takes its place', () {
      final items = [item('a', CardSize.sm), item('b', CardSize.sm)];
      final target = slot(1, 0, 1, 1);
      final order = chooseDrop(slot(0, 0, 1, 1), dropCandidates(items, 'a', 2, slot), target.center.dx, target.center.dy);
      expect(order!.map((i) => i.id), ['b', 'a']);
    });

    test('a big card swaps with the small cards filling the same area', () {
      final items = [item('big', CardSize.lg), item('a', CardSize.sm), item('b', CardSize.sm), item('c', CardSize.sm), item('d', CardSize.sm)];
      final candidates = dropCandidates(items, 'big', 4, slot);
      final swap = candidates.first;
      expect(swap.slot, slot(2, 0, 2, 2));
      final places = layoutGrid(swap.order, 4);
      expect(places.firstWhere((p) => p.id == 'big').col, 2);
      expectValid(places, 4);
    });

    test('moves always reduce the distance, so repeated checks settle', () {
      var items = dashboard;
      const columns = 4;
      // Hold the hero at one point and apply every accepted move.
      const cx = 350.0;
      const cy = 260.0;
      var moves = 0;
      while (moves < 20) {
        final me = layoutGrid(items, columns).firstWhere((p) => p.id == 'hero');
        final order = chooseDrop(slot(me.col, me.row, me.w, me.h), dropCandidates(items, 'hero', columns, slot), cx, cy);
        if (order == null) break;
        items = canonicalOrder(order, columns);
        moves++;
      }
      expect(moves, lessThan(20), reason: 'no oscillation');
    });
  });
}
