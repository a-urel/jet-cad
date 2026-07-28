import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addEntity(DraftDocument doc, Handle owner, EntityKind kind,
    List<double> coords, List<double> scalars) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
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
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

void main() {
  test('SnapMask reports the kinds it contains', () {
    const mask = SnapMask.cheap;
    expect(mask.has(SnapKind.endpoint), isTrue);
    expect(mask.has(SnapKind.midpoint), isTrue);
    expect(mask.has(SnapKind.nearest), isFalse);
    expect(SnapMask.none.has(SnapKind.endpoint), isFalse);
    expect(SnapMask.all.has(SnapKind.intersection), isTrue);
  });

  test(
      'SnapMask.cheap and SnapMask.all match a runtime derivation from '
      'SnapKind', () {
    // SnapMask.cheap and SnapMask.all are hard-coded bit literals -- Dart's
    // const evaluator cannot read SnapKind.values.length or SnapKind.x.index
    // in a const context (verified: both are "not a constant expression").
    // This test re-derives the same values at runtime, so inserting or
    // reordering a SnapKind without updating the literals fails here rather
    // than silently drifting.
    var cheapBits = 0;
    for (final k in SnapKind.values) {
      if (k.index <= SnapKind.insertion.index) cheapBits |= 1 << k.index;
    }
    expect(SnapMask.cheap.bits, cheapBits);

    var allBits = 0;
    for (final k in SnapKind.values) {
      allBits |= 1 << k.index;
    }
    expect(SnapMask.all.bits, allBits);
  });

  test('with_ sets exactly the requested bit, leaving the others alone', () {
    final mask = SnapMask.none.with_(SnapKind.midpoint);
    expect(mask.has(SnapKind.midpoint), isTrue);
    expect(mask.has(SnapKind.endpoint), isFalse);
  });

  test('snaps to an endpoint', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.3, 0.3), 1.0, SnapMask.cheap, out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.endpoint);
    expect(out.point.x, closeTo(0, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('snaps to a midpoint', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(5.1, 0.1), 1.0, SnapMask.cheap, out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.midpoint);
    expect(out.point.x, closeTo(5, 1e-12));
  });

  test('prefers an endpoint to a midpoint at equal distance', () {
    final doc = DraftDocument.empty();
    // Endpoint at (0,0), midpoint at (5,0); query is equidistant from both.
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(2.5, 0), 3.0, SnapMask.cheap, out);

    expect(out.kind, SnapKind.endpoint,
        reason: 'kind priority beats distance only at equal distance, and '
            'endpoint outranks midpoint');
    expect(out.point.x, closeTo(0, 1e-12));
  });

  test(
      'kind priority dominates even when the higher-priority candidate is '
      'FARTHER, not merely equidistant', () {
    // The "equal distance" test above cannot distinguish a correct
    // kind-first comparison from a broken distance-first one that happens
    // to fall back to kind on an exact tie -- either order reaches the same
    // answer when the distances are equal. This fixture breaks the tie
    // properly: the midpoint (5,0) is strictly nearer to the query point
    // (4,0) than the endpoint (0,0) is, so a distance-first comparison
    // would pick the midpoint. Kind priority must still pick the endpoint.
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(4, 0), 5.0, SnapMask.cheap, out);

    expect(out.kind, SnapKind.endpoint,
        reason: 'the endpoint at distance 4 must beat the midpoint at '
            'distance 1: kind strictly dominates distance, not merely on a '
            'tie');
    expect(out.point.x, closeTo(0, 1e-12));
  });

  test('snaps to a circle centre and to its quadrants', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.circle, [0, 0], [10]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.center);
    expect(out.point.x, closeTo(0, 1e-12));

    index.snapInto(Vector2(10.2, 0.1), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.quadrant);
    expect(out.point.x, closeTo(10, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('finds nothing outside the radius and resets the result', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult()..found = true;
    index.snapInto(Vector2(500, 500), 1.0, SnapMask.cheap, out);
    expect(out.found, isFalse);
  });

  test('an empty mask finds nothing even on top of geometry', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0, 0), 1.0, SnapMask.none, out);
    expect(out.found, isFalse);
  });

  test('a miss leaves no stale kind, point, or entity from a previous hit', () {
    // Not just "found stays false": a caller that forgets to check found
    // must not be able to read the *previous* query's location, kind, or
    // entity and mistake it for a fresh hit at the new query point.
    final doc = DraftDocument.empty();
    final handle =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.1, 0.1), 1.0, SnapMask.cheap, out);
    expect(out.found, isTrue);
    expect(out.entity, handle);
    expect(out.kind, SnapKind.endpoint);

    index.snapInto(Vector2(500, 500), 1.0, SnapMask.cheap, out);
    expect(out.found, isFalse);
    expect(out.entity, Handle.none);
    expect(out.kind, SnapKind.nearest);
    expect(out.point, Vector2.zero());
    expect(out.chainLength, 0);
  });

  test('snapping crosses an instance boundary', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Chair',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(400),
        parent: doc.rootHandle,
        transform: Transform2.translation(100, 100),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(102.1, 100.1), 1.0, SnapMask.cheap, out);

    expect(out.found, isTrue,
        reason: 'snapping to a chair corner inside a table instance is the '
            'motivating case');
    expect(out.entity, leaf);
    expect(out.point.x, closeTo(102, 1e-9));
    expect(out.point.y, closeTo(100, 1e-9));
  });

  test('snap points are exact under a rotated instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'R',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(400),
        parent: doc.rootHandle,
        transform: Transform2.rotation(math.pi / 2),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // The far endpoint rotates from (10,0) to (0,10).
    final out = SnapResult();
    index.snapInto(Vector2(0.1, 9.9), 1.0, SnapMask.cheap, out);
    expect(out.found, isTrue);
    expect(out.kind, SnapKind.endpoint);
    expect(out.point.x, closeTo(0, 1e-9));
    expect(out.point.y, closeTo(10, 1e-9));
  });

  test('arc: endpoint, midpoint, centre, and quadrant only inside the sweep',
      () {
    final doc = DraftDocument.empty();
    // A quarter arc from 0 to 90 degrees, radius 10, centred at the origin.
    addEntity(
        doc, doc.rootHandle, EntityKind.arc, [0, 0], [10, 0, math.pi / 2]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();

    // The start endpoint, at angle 0: (10, 0).
    index.snapInto(Vector2(10.1, 0.1), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.endpoint);
    expect(out.point.x, closeTo(10, 1e-9));
    expect(out.point.y, closeTo(0, 1e-9));

    // The end endpoint, at angle 90: (0, 10).
    index.snapInto(Vector2(0.1, 9.9), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.endpoint);
    expect(out.point.x, closeTo(0, 1e-9));
    expect(out.point.y, closeTo(10, 1e-9));

    // The midpoint, at angle 45: (10/sqrt2, 10/sqrt2).
    final mid = 10 / math.sqrt2;
    index.snapInto(Vector2(mid, mid), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.midpoint);
    expect(out.point.x, closeTo(mid, 1e-9));
    expect(out.point.y, closeTo(mid, 1e-9));

    // The centre.
    index.snapInto(Vector2(0.1, 0.1), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.center);

    // The quadrant point at angle 0 coincides with the start endpoint --
    // higher priority (endpoint beats quadrant) wins there, which does not
    // by itself prove quadrant generation ran at all. Use quadrant masking
    // alone to observe it directly.
    final quadrantOnly = SnapMask.none.with_(SnapKind.quadrant);
    index.snapInto(Vector2(10.1, 0.1), 1.0, quadrantOnly, out);
    expect(out.found, isTrue);
    expect(out.kind, SnapKind.quadrant);
    expect(out.point.x, closeTo(10, 1e-9));
    expect(out.point.y, closeTo(0, 1e-9));
  });

  test(
      'an off-sweep quadrant is rejected by the narrow-phase sweep check, '
      'not merely because the broad phase never reaches the entity', () {
    // A query far from the arc's own bounding box (e.g. the angle-180
    // quadrant of a 0..90-degree arc) is rejected by the R-tree broad phase
    // before candidate generation ever runs -- proving nothing about the
    // narrow-phase `angleInSweep` check in _considerSnapLeaf specifically.
    // `arcBounds` computes a *tight* box that already excludes any rim point
    // the arc does not actually draw, so a naive "query near an excluded
    // quadrant" fixture is silently vacuous: deleting the narrow-phase
    // check entirely still passes it.
    //
    // To actually exercise the narrow-phase check, the off-sweep quadrant
    // must be queried through a radius wide enough that the broad-phase
    // query rectangle still overlaps the arc's indexed box, even though the
    // exact quadrant point sits just outside the true curve.
    final doc = DraftDocument.empty();
    // 0 to 80 degrees -- just short of the 90-degree quadrant. The
    // indexed box (via arcBounds) is tight: x in [10*cos80, 10], y in
    // [0, 10*sin80] ~= [1.74, 10] x [0, 9.85]. The off-sweep quadrant at
    // (0, 10) sits just outside that box's y edge (9.85 < 10), so a
    // sufficiently wide query radius still makes the broad phase overlap
    // it without the exact point being inside the box.
    final sweep = 80 * math.pi / 180;
    addEntity(doc, doc.rootHandle, EntityKind.arc, [0, 0], [10, 0, sweep]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final quadrantOnly = SnapMask.none.with_(SnapKind.quadrant);
    final out = SnapResult();
    // Query directly at the 90-degree quadrant point, which this arc does
    // not draw, with a radius wide enough to reach the broad-phase box.
    index.snapInto(Vector2(0, 10), 2.5, quadrantOnly, out);
    expect(out.found, isFalse,
        reason: 'the 90-degree quadrant point is off this arc\'s sweep and '
            'must not be produced as a candidate even though the entity is '
            'reached in the broad phase');
  });

  test('snaps to a text insertion point', () {
    final doc = DraftDocument.empty();
    final handle = addEntity(doc, doc.rootHandle, EntityKind.text, [5, 5], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(5.1, 5.1), 1.0, SnapMask.cheap, out);
    expect(out.found, isTrue);
    expect(out.kind, SnapKind.insertion);
    expect(out.entity, handle);
    expect(out.point.x, closeTo(5, 1e-12));
    expect(out.point.y, closeTo(5, 1e-12));
  });

  test(
      'two coincident lines at exactly the same kind and distance: the '
      'greater handle wins, deterministically', () {
    final doc = DraftDocument.empty();
    final lower =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final upper =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    expect(upper.value, greaterThan(lower.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.1, 0.1), 1.0, SnapMask.cheap, out);
    expect(out.found, isTrue);
    expect(out.kind, SnapKind.endpoint);
    expect(out.entity, upper,
        reason: 'both lines offer an identical endpoint candidate at the '
            'same distance; the tie must resolve the same way every time, '
            'not depend on traversal order');
  });

  test('snapInto refuses to run inside another query\'s visitor', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    var threw = false;
    index.forEachInRect(
      Aabb2(Vector2(-10, -10), Vector2(10, 10)),
      const QueryFilter.all(),
      (_) {
        try {
          index.snapInto(Vector2(0, 0), 1.0, SnapMask.cheap, out);
        } on QueryReentrancyError {
          threw = true;
        }
      },
    );
    expect(threw, isTrue,
        reason: 'snapInto shares the index scratch state with every other '
            'query and must refuse to run while one is already in progress');
  });

  test('reset() clears every field, not just found', () {
    final result = SnapResult()
      ..found = true
      ..entity = const Handle(42)
      ..kind = SnapKind.center
      ..chainLength = 5;
    // In place, not a reassignment: `point` is final so that `reset()`
    // cannot allocate a fresh vector on every snap.
    result.point.setValues(3, 4);

    result.reset();

    expect(result.found, isFalse);
    expect(result.entity, Handle.none);
    expect(result.kind, SnapKind.nearest);
    expect(result.point, Vector2.zero());
    expect(result.chainLength, 0);
  });
}
