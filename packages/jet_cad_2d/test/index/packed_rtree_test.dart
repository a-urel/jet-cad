import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import '../invariants/vm_allocation_meter.dart';

/// Builds a tree over [count] unit boxes on a grid, payload == index.
PackedRTree gridTree(int count) {
  final side = math.sqrt(count).ceil();
  final boxes = Float64List(count * 4);
  final payloads = Uint32List(count);
  for (var i = 0; i < count; i++) {
    final x = (i % side).toDouble();
    final y = (i ~/ side).toDouble();
    boxes[i * 4] = x;
    boxes[i * 4 + 1] = y;
    boxes[i * 4 + 2] = x + 0.5;
    boxes[i * 4 + 3] = y + 0.5;
    payloads[i] = i;
  }
  return PackedRTree.build(count, boxes, payloads);
}

/// Everything the tree reports for a query, ascending.
List<int> hits(
    PackedRTree tree, double minX, double minY, double maxX, double maxY) {
  final out = <int>[];
  tree.search(minX, minY, maxX, maxY, out.add);
  out.sort();
  return out;
}

void main() {
  test('an empty tree reports nothing and has empty bounds', () {
    final tree = PackedRTree.empty();
    expect(tree.itemCount, 0);
    expect(tree.bounds.isEmpty, isTrue);
    expect(hits(tree, -1e9, -1e9, 1e9, 1e9), isEmpty);
  });

  test('a single item is found by a query that overlaps it', () {
    final tree = gridTree(1);
    expect(hits(tree, -1, -1, 1, 1), [0]);
    expect(hits(tree, 10, 10, 11, 11), isEmpty);
  });

  test('a query returns exactly what a brute-force scan returns', () {
    // 1000 items forces several tree levels at capacity 16.
    const count = 1000;
    final tree = gridTree(count);
    final side = math.sqrt(count).ceil();

    final rng = math.Random(7);
    for (var trial = 0; trial < 200; trial++) {
      final qx = rng.nextDouble() * side;
      final qy = rng.nextDouble() * side;
      final qw = rng.nextDouble() * 6;
      final qh = rng.nextDouble() * 6;

      final expected = <int>[];
      for (var i = 0; i < count; i++) {
        final x = (i % side).toDouble();
        final y = (i ~/ side).toDouble();
        // Same overlap predicate the tree uses: touching counts.
        if (x <= qx + qw && x + 0.5 >= qx && y <= qy + qh && y + 0.5 >= qy) {
          expected.add(i);
        }
      }
      expect(hits(tree, qx, qy, qx + qw, qy + qh), expected,
          reason: 'trial $trial at ($qx, $qy) size ($qw, $qh)');
    }
  });

  test('bounds covers every item', () {
    final tree = gridTree(100);
    final b = tree.bounds;
    expect(b.minX, 0.0);
    expect(b.minY, 0.0);
    expect(b.maxX, closeTo(9.5, 1e-12));
    expect(b.maxY, closeTo(9.5, 1e-12));
  });

  test('a dead payload is skipped and clearDead restores it', () {
    final tree = gridTree(100);
    expect(hits(tree, -1, -1, 100, 100), hasLength(100));

    tree.markDead(42);
    expect(tree.isDead(42), isTrue);
    final afterKill = hits(tree, -1, -1, 100, 100);
    expect(afterKill, hasLength(99));
    expect(afterKill, isNot(contains(42)));

    tree.clearDead();
    expect(tree.isDead(42), isFalse);
    expect(hits(tree, -1, -1, 100, 100), hasLength(100));
  });

  test('a dead item has no box, and markAlive restores it', () {
    final tree = gridTree(100);
    expect(tree.boxOfPayload(42), isNotNull);
    tree.markDead(42);
    expect(tree.boxOfPayload(42), isNull,
        reason: 'a stale box for a dead item is how remove-then-undo loses '
            'an entity forever');
    tree.markAlive(42);
    expect(tree.boxOfPayload(42), isNotNull);
    expect(tree.isDead(42), isFalse);
  });

  // Was a stub, deliberately skipped by Task 3: the old `_allocatedBytes()`
  // below always returned 0, so the assertion it fed passed against any
  // implementation, including a broken one -- a test that reads as coverage
  // but measures nothing. Task 17 (`query_allocation_test.dart`, next to
  // this file's own package -- see `test/invariants/vm_allocation_meter
  // .dart` for the mechanism) replaces the stub with a real reading rather
  // than deleting this test: the two harnesses check different code. The
  // one in `test/invariants/` watches `Vector2`, since that is what
  // `SpatialIndex`'s own narrow phase allocates one of per candidate; this
  // tree's own `search` touches none of that package's geometry types at
  // all -- it walks `_stackLevel`/`_stackIndex`, two typed arrays already
  // held as fields, entirely in raw ints -- so there is nothing of that
  // shape *to* watch here. What is watched instead is `Aabb2` and
  // `Transform2`: not because `search` uses either today, but because it is
  // exactly what a well-meaning future edit would reach for first (compare
  // `boxOfPayload`, right above this test, which already builds one) if it
  // started computing something geometric per visited node instead of just
  // testing raw doubles against `_boxes` -- see [_overlaps].
  test('search allocates nothing after the first call', () async {
    final meter = await AllocationMeter.connect();
    if (meter == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    addTearDown(meter.dispose);

    final tree = gridTree(5000);
    var seen = 0;
    void count(int _) => seen++;
    for (var i = 0; i < 20000; i++) {
      tree.search(0, 0, 70, 70, count); // warm
    }
    expect(seen, greaterThan(0),
        reason: 'the fixture must actually match something, or this test '
            'would pass by never exercising a real walk at all');

    await meter.reset();
    const iters = 1000;
    for (var i = 0; i < iters; i++) {
      tree.search(0, 0, 70, 70, count);
    }
    final accumulated =
        await meter.accumulatedInstances({'Vector2', 'Aabb2', 'Transform2'});
    for (final entry in accumulated.entries) {
      // A tolerance rather than zero: the VM allocates for reasons outside
      // this call, and `Aabb2`'s own name collides with an unused class of
      // the same name in `package:vector_math` (see
      // `AllocationMeter.accumulatedInstances`'s own doc comment) -- 0.5
      // admits that noise without admitting a genuine per-node object,
      // which at 5000 items visited per call would read as several
      // thousand, not a fraction of one.
      expect(entry.value / iters, lessThan(0.5),
          reason: '${entry.key}: ${entry.value / iters} per call over '
              '$iters calls against a 5000-item tree -- a per-node or '
              'per-item allocation here would be orders of magnitude above '
              'this budget');
    }
  });

  test('handles items that all share one box', () {
    final boxes = Float64List(64 * 4);
    final payloads = Uint32List(64);
    for (var i = 0; i < 64; i++) {
      boxes[i * 4] = 5.0;
      boxes[i * 4 + 1] = 5.0;
      boxes[i * 4 + 2] = 6.0;
      boxes[i * 4 + 3] = 6.0;
      payloads[i] = i;
    }
    final tree = PackedRTree.build(64, boxes, payloads);
    expect(hits(tree, 5.5, 5.5, 5.5, 5.5), hasLength(64));
    expect(hits(tree, 100, 100, 101, 101), isEmpty);
  });

  test('handles a degenerate zero-area box', () {
    final boxes = Float64List.fromList([3.0, 3.0, 3.0, 3.0]);
    final payloads = Uint32List.fromList([9]);
    final tree = PackedRTree.build(1, boxes, payloads);
    expect(hits(tree, 2, 2, 4, 4), [9]);
    expect(hits(tree, 3, 3, 3, 3), [9]);
  });
}
