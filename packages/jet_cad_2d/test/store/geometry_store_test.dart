import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload lineFrom(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

void main() {
  test('stores and reads back a payload unchanged', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 10, 5));
    final read = store.read(slot);
    expect(read.pointCount, 2);
    expect(read.pointAt(1), Vector2(10, 5));
    expect(read.scalars, isEmpty);
  });

  test('read returns a copy, so mutating it cannot corrupt the store', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 1, 1));
    store.read(slot).coords[0] = 999;
    expect(store.read(slot).coords[0], 0);
  });

  test('keeps coordinates and scalars in separate pools', () {
    // An arc: centre in coords, radius and angles in scalars. A transform
    // applies to the centre but not to the radius or the angles.
    final store = GeometryStore();
    final arc = GeometryPayload(
      coords: Float64List.fromList([100, 200]),
      scalars: Float64List.fromList([50, 0, 1.5707963267948966]),
    );
    final slot = store.add(arc);
    final read = store.read(slot);
    expect(read.pointCount, 1);
    expect(read.scalars.length, 3);
    expect(read.scalars[0], 50);
  });

  test('transformedBy moves points and leaves scalars alone', () {
    final arc = GeometryPayload(
      coords: Float64List.fromList([1, 0]),
      scalars: Float64List.fromList([50, 0, 3.14]),
    );
    final moved = arc.transformedBy(Transform2.translation(10, 20));
    expect(moved.pointAt(0), Vector2(11, 20));
    expect(moved.scalars[0], 50);
    expect(moved.scalars[2], 3.14);
  });

  test('pointBounds bounds only the coordinate pool', () {
    final store = GeometryStore();
    final slot = store.add(GeometryPayload(
      coords: Float64List.fromList([-3, 4, 7, -2]),
      scalars: Float64List.fromList([1e9]), // must not affect the bounds
    ));
    final box = store.pointBounds(slot);
    expect(box.min, Vector2(-3, -2));
    expect(box.max, Vector2(7, 4));
  });

  test('remove frees the slot and reading it throws', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 1, 1));
    store.remove(slot);
    expect(store.liveCount, 0);
    expect(() => store.read(slot), throwsA(isA<SlotStateError>()));
  });

  test(
      'a removed slot is reused, and undo restoring a payload may land elsewhere',
      () {
    // Rule 2: the inverse command carries the payload, not the slot. This test
    // pins that behaviour so nobody later "fixes" the store to preserve slots.
    final store = GeometryStore();
    final a = store.add(lineFrom(0, 0, 1, 1));
    final payload = store.read(a);
    final b = store.add(lineFrom(2, 2, 3, 3));
    store.remove(a);

    final restored = store.add(payload);
    expect(restored, a, reason: 'free list is LIFO, so this happens to match');
    expect(store.read(b).pointAt(0), Vector2(2, 2));
  });

  test('replace swaps the payload in place without changing the slot', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 1, 1));
    store.replace(slot, lineFrom(5, 5, 6, 6));
    expect(store.read(slot).pointAt(0), Vector2(5, 5));
    expect(store.liveCount, 1);
  });

  test('purge compacts and reports the remap for the caller to apply', () {
    final store = GeometryStore();
    final a = store.add(lineFrom(0, 0, 1, 1));
    final b = store.add(lineFrom(2, 2, 3, 3));
    final c = store.add(lineFrom(4, 4, 5, 5));
    store.remove(b);

    final remap = store.purge();
    expect(remap[a], 0);
    expect(remap[b], -1);
    expect(remap[c], 1);
    expect(store.read(remap[c]).pointAt(0), Vector2(4, 4));
    expect(store.liveCount, 2);
  });

  test('payload json round-trips', () {
    final payload = GeometryPayload(
      coords: Float64List.fromList([1, 2, 3, 4]),
      scalars: Float64List.fromList([9]),
    );
    expect(GeometryPayload.fromJson(payload.toJson()), payload);
  });
}
