import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('starts empty and reset makes it empty again', () {
    final scratch = QueryScratch()
      ..add(1)
      ..add(2);
    expect(scratch.length, 2);
    scratch.reset();
    expect(scratch.length, 0);
  });

  test('grows past its initial capacity without losing entries', () {
    final scratch = QueryScratch();
    final initial = scratch.capacity;
    for (var i = 0; i < initial * 4; i++) {
      scratch.add(i);
    }
    expect(scratch.length, initial * 4);
    expect(scratch.capacity, greaterThanOrEqualTo(initial * 4));
    for (var i = 0; i < initial * 4; i++) {
      expect(scratch[i], i);
    }
  });

  test('capacity is retained across reset, which is what warming means', () {
    final scratch = QueryScratch();
    for (var i = 0; i < 5000; i++) {
      scratch.add(i);
    }
    final grown = scratch.capacity;
    scratch.reset();
    expect(scratch.capacity, grown,
        reason: 'reset must not shrink, or every query would regrow');
  });

  test('a zero initial capacity is usable, not a trap', () {
    // The doubling growth strategy in add() cannot recover from a starting
    // capacity of 0 (0 * 2 stays 0), so an unclamped constructor would build
    // successfully and then throw RangeError on the very first add.
    final scratch = QueryScratch(0);
    expect(scratch.capacity, greaterThanOrEqualTo(1));
    scratch.add(7);
    expect(scratch.length, 1);
    expect(scratch[0], 7);
  });

  test('operator[] rejects an index at or past the live length', () {
    final scratch = QueryScratch()..add(42);
    expect(() => scratch[1], throwsRangeError,
        reason: 'index 1 is inside capacity but past length');

    scratch.reset();
    expect(() => scratch[0], throwsRangeError,
        reason: 'reset rewinds length without clearing the backing array, '
            'so slot 0 still physically holds the old value 42 — reading it '
            'must fail rather than silently return stale data');
  });

  test('sortByHandle orders slots by their entity handle, not by slot', () {
    final doc = DraftDocument.empty();
    // Deliberately add so that slot order and handle order disagree: remove
    // the middle entity, then add a new one, which reuses the freed slot while
    // taking a larger handle.
    final a = _add(doc); // slot 0
    final b = _add(doc); // slot 1
    final c = _add(doc); // slot 2
    doc.commands.execute(RemoveEntityCommand(b));
    final d = _add(doc); // reuses slot 1, handle > c

    final slotA = doc.entities.slotOf(a)!;
    final slotC = doc.entities.slotOf(c)!;
    final slotD = doc.entities.slotOf(d)!;
    expect(slotD, lessThan(slotC),
        reason: 'the fixture is only meaningful if slot order disagrees');

    final scratch = QueryScratch()
      ..add(slotC)
      ..add(slotD)
      ..add(slotA);
    scratch.sortByHandle(doc.entities);

    expect([scratch[0], scratch[1], scratch[2]], [slotA, slotC, slotD]);
  });

  test('sorting is stable enough to be deterministic across runs', () {
    final doc = DraftDocument.empty();
    final handles = [for (var i = 0; i < 50; i++) _add(doc)];
    final slots = [for (final h in handles) doc.entities.slotOf(h)!];

    List<int> sortOnce() {
      final scratch = QueryScratch();
      for (final s in slots.reversed) {
        scratch.add(s);
      }
      scratch.sortByHandle(doc.entities);
      return [for (var i = 0; i < scratch.length; i++) scratch[i]];
    }

    expect(sortOnce(), sortOnce());
    expect(sortOnce(), slots);
  });

  test('sorting an empty and a single-element scratch is safe', () {
    final doc = DraftDocument.empty();
    final scratch = QueryScratch()..sortByHandle(doc.entities);
    expect(scratch.length, 0);

    final h = _add(doc);
    scratch.add(doc.entities.slotOf(h)!);
    scratch.sortByHandle(doc.entities);
    expect(scratch.length, 1);
  });

  test('sortByValue orders raw values ascending, insertion-sort path', () {
    final scratch = QueryScratch()
      ..add(30)
      ..add(10)
      ..add(20);
    scratch.sortByValue();
    expect([scratch[0], scratch[1], scratch[2]], [10, 20, 30]);
  });

  test('sortByValue orders raw values ascending, heapsort path', () {
    // 60 elements, descending, forces the >32 heapsort branch — the same
    // shape used to pin sortByHandle's heapsort above, but for the sibling
    // method forEachInstanceInRect actually calls: nothing else in this
    // package exercises sortByValue's heap past the 32-element threshold.
    final values = [for (var i = 59; i >= 0; i--) i];
    final scratch = QueryScratch();
    for (final v in values) {
      scratch.add(v);
    }
    scratch.sortByValue();
    expect([for (var i = 0; i < scratch.length; i++) scratch[i]],
        [for (var i = 0; i < 60; i++) i]);
  });

  test('sortByValue orders handle values above 2^31 correctly', () {
    // `forEachInstanceInRect` stores raw handle values here, and kMaxHandle is
    // 0xFFFFFFFF. An Int32List reads 0x90000000 as negative, so it sorts below
    // a small handle and then throws HandleRangeError when the caller rebuilds
    // the Handle. Values chosen to straddle the sign bit.
    final scratch = QueryScratch(4);
    scratch
      ..add(0x90000000)
      ..add(0x00000010)
      ..add(0xFFFFFFFF);
    scratch.sortByValue();

    expect([for (var i = 0; i < scratch.length; i++) scratch[i]],
        [0x00000010, 0x90000000, 0xFFFFFFFF]);
    expect(() => Handle(scratch[2]), returnsNormally);
  });
}

Handle _add(DraftDocument doc) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.point,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}
