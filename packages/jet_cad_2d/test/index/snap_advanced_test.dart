import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.line,
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
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Handle addCircle(DraftDocument doc, List<double> centre, double radius) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.circle,
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
      coords: Float64List.fromList(centre),
      scalars: Float64List.fromList([radius]),
    ),
  ));
  return handle;
}

Handle addArc(DraftDocument doc, List<double> centre, double radius,
    double start, double sweep) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.arc,
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
      coords: Float64List.fromList(centre),
      scalars: Float64List.fromList([radius, start, sweep]),
    ),
  ));
  return handle;
}

void main() {
  test('segmentIntersection finds a crossing and rejects a miss', () {
    final out = Vector2.zero();
    expect(
        segmentIntersection(
            Vector2(0, 0), Vector2(10, 0), Vector2(5, -5), Vector2(5, 5), out),
        isNotNull);
    expect(out.x, closeTo(5, 1e-12));
    expect(out.y, closeTo(0, 1e-12));

    expect(
        segmentIntersection(
            Vector2(0, 0), Vector2(10, 0), Vector2(0, 5), Vector2(10, 5), out),
        isNull,
        reason: 'parallel');

    expect(
        segmentIntersection(
            Vector2(0, 0), Vector2(1, 0), Vector2(5, -5), Vector2(5, 5), out),
        isNull,
        reason: 'the infinite lines cross, but the segments do not');
  });

  test('projectOntoSegment lands on the segment and clamps outside it', () {
    final out = Vector2.zero();
    expect(
        projectOntoSegment(Vector2(5, 3), Vector2(0, 0), Vector2(10, 0), out),
        isNotNull);
    expect(out.x, closeTo(5, 1e-12));
    expect(out.y, closeTo(0, 1e-12));

    projectOntoSegment(Vector2(20, 3), Vector2(0, 0), Vector2(10, 0), out);
    expect(out.x, closeTo(10, 1e-12), reason: 'clamped to the far endpoint');
  });

  test('nearest snaps to the closest point on a line', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(
        Vector2(3, 0.4), 1.0, const SnapMask(0).with_(SnapKind.nearest), out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.nearest);
    expect(out.point.x, closeTo(3, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('intersection snaps to where two lines cross', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    addLine(doc, [5, -5, 5, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(5.2, 0.2), 1.0,
        const SnapMask(0).with_(SnapKind.intersection), out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.intersection);
    expect(out.point.x, closeTo(5, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('intersection finds nothing where lines do not cross', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    addLine(doc, [0, 3, 10, 3]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(5, 1.5), 2.0,
        const SnapMask(0).with_(SnapKind.intersection), out);
    expect(out.found, isFalse);
  });

  test('the intersection candidate cap is declared and enforced', () {
    expect(kIntersectionCandidateCap, 64);

    final doc = DraftDocument.empty();
    // 200 overlapping lines through one small region: far past the cap.
    for (var i = 0; i < 200; i++) {
      addLine(doc, [-10 + i * 0.01, -10, 10 + i * 0.01, 10]);
      addLine(doc, [-10 + i * 0.01, 10, 10 + i * 0.01, -10]);
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    // The point is not that a particular intersection wins — it is that this
    // terminates promptly rather than doing 400 choose 2 pair tests.
    index.snapInto(Vector2(0, 0), 5.0,
        const SnapMask(0).with_(SnapKind.intersection), out);
    expect(out.found, isTrue);
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('perpendicular snaps to the foot of the perpendicular', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(7, 0.5), 1.0,
        const SnapMask(0).with_(SnapKind.perpendicular), out);

    expect(out.found, isTrue);
    expect(out.point.x, closeTo(7, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('endpoint still outranks nearest when both are in range', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, SnapMask.all, out);
    expect(out.kind, SnapKind.endpoint,
        reason: 'nearest would give (0.2, 0) at a smaller distance; kind '
            'priority is what stops nearest swallowing every other kind');
  });

  // --- beyond the brief's verbatim tests -----------------------------

  group('nearest and perpendicular on a circle or arc', () {
    // The brief's verbatim tests only exercise a straight line. nearest and
    // perpendicular were extended here to circles and arcs too, for
    // consistency with every other kind in this class (all four entity
    // shapes), so they need the same standard of proof: a fixture that
    // distinguishes the correct answer from the obvious wrong one, not a
    // fixture symmetric enough to hide it.

    test('nearest snaps to the near side of a circle, not the far side', () {
      // Query point off any axis of symmetry -- direction (3/5, 4/5) from
      // the centre, not aligned with x or y -- so a foot mistakenly
      // projected to the *far* side of the rim lands somewhere clearly
      // different from the correct near-side foot, not merely swapped with
      // it by symmetry.
      final doc = DraftDocument.empty();
      addCircle(doc, [2, 3], 5);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);

      final out = SnapResult();
      // Query at (8, 11): 10 units from the centre along (3/5, 4/5). Near
      // foot (5, 7) is 5 units away; far foot (-1, -1) is 15 units away.
      index.snapInto(
          Vector2(8, 11), 6.0, const SnapMask(0).with_(SnapKind.nearest), out);

      expect(out.found, isTrue);
      expect(out.kind, SnapKind.nearest);
      expect(out.point.x, closeTo(5, 1e-9));
      expect(out.point.y, closeTo(7, 1e-9));
    });

    test('perpendicular on a circle is the same near-side foot as nearest', () {
      final doc = DraftDocument.empty();
      addCircle(doc, [2, 3], 5);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);

      final out = SnapResult();
      index.snapInto(Vector2(8, 11), 6.0,
          const SnapMask(0).with_(SnapKind.perpendicular), out);

      expect(out.found, isTrue);
      expect(out.kind, SnapKind.perpendicular);
      expect(out.point.x, closeTo(5, 1e-9));
      expect(out.point.y, closeTo(7, 1e-9));
    });

    test(
        'off-sweep nearest/perpendicular on an arc clamps to the nearer '
        'endpoint, not the farther one', () {
      // A 10-to-70-degree arc, radius 10 at the origin -- deliberately not
      // symmetric about the query direction, so the two endpoints sit at
      // very different distances from the query point (about 2.77 and
      // 12.72) rather than a tie a "pick either endpoint" bug could hide
      // behind.
      final doc = DraftDocument.empty();
      addArc(doc, [0, 0], 10, 10 * math.pi / 180, 60 * math.pi / 180);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);

      final out = SnapResult();
      // Query at (12, 0) -- angle 0 from the centre, off the arc's
      // 10-to-70-degree sweep. Distance to the start endpoint (~9.85, 1.74)
      // is ~2.77; distance to the end endpoint (~3.42, 9.40) is ~12.72. A
      // radius of 3.5 reaches the near endpoint but not the far one, so
      // clamping to the wrong endpoint would report no hit at all rather
      // than merely the wrong point.
      index.snapInto(
          Vector2(12, 0), 3.5, const SnapMask(0).with_(SnapKind.nearest), out);

      expect(out.found, isTrue,
          reason: 'clamping to the farther endpoint would put the '
              'candidate outside the 3.5 search radius entirely');
      expect(out.kind, SnapKind.nearest);
      expect(out.point.x, closeTo(10 * math.cos(10 * math.pi / 180), 1e-9));
      expect(out.point.y, closeTo(10 * math.sin(10 * math.pi / 180), 1e-9));
    });
  });

  group('tangent', () {
    test('snaps to a tangent point on a circle, radius load-bearing', () {
      // Deliberately not a unit circle at an axis-aligned point: both a and
      // h in _tangentPoints scale with r in a way that would not show up as
      // a bug on a radius of 1, and an axis-aligned query would not show up
      // a transposed x/y term either.
      final doc = DraftDocument.empty();
      addCircle(doc, [3, 2], 5);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);

      // External point, well outside the circle. Distance from centre:
      // sqrt(17^2 + 4^2) = sqrt(305) ~= 17.464; tangent length
      // sqrt(305 - 25) = sqrt(280) ~= 16.733.
      const px = 20.0, py = 6.0;
      final tangentLength = _tangentLengthForTest(px, py, 3, 2, 5);

      final out = SnapResult();
      final tangentOnly = SnapMask.none.with_(SnapKind.tangent);
      // Search radius just wide enough to reach one of the two tangent
      // points but not so wide it reaches both by coincidence.
      index.snapInto(Vector2(px, py), tangentLength + 0.5, tangentOnly, out);
      expect(out.found, isTrue);
      expect(out.kind, SnapKind.tangent);

      // The reported point must actually lie on the circle (distance r from
      // the centre) and the line from (px,py) to it must be perpendicular
      // to the radius at that point -- the defining property of a tangent
      // point, checked directly rather than trusting the formula that
      // produced it.
      final rx = out.point.x - 3, ry = out.point.y - 2;
      final radiusLen = (rx * rx + ry * ry);
      expect(radiusLen, closeTo(25, 1e-6));
      final tx = px - out.point.x, ty = py - out.point.y;
      final dot = rx * tx + ry * ty;
      expect(dot.abs(), lessThan(1e-6),
          reason: 'the radius to the tangent point must be perpendicular '
              'to the line from the query point');
    });

    test('reports nothing when the query point is inside the circle', () {
      final doc = DraftDocument.empty();
      addCircle(doc, [0, 0], 10);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);

      final out = SnapResult();
      index.snapInto(
          Vector2(1, 1), 50.0, SnapMask.none.with_(SnapKind.tangent), out);
      expect(out.found, isFalse,
          reason: 'a point strictly inside a circle has no real tangent '
              'line to it');
    });

    test('an off-sweep tangent point on an arc is rejected', () {
      // A half-circle arc from 0 to 180 degrees, radius 10 at the origin.
      // Its tangent points from a query point below the X axis fall on the
      // (excluded) lower half, so neither should be offered even though the
      // arc's own indexed box may still be reached by the broad phase.
      final doc = DraftDocument.empty();
      addArc(doc, [0, 0], 10, 0, 3.14159265358979);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);

      final out = SnapResult();
      index.snapInto(
          Vector2(0, -30), 25.0, SnapMask.none.with_(SnapKind.tangent), out);
      expect(out.found, isFalse,
          reason: 'the only real tangent points from directly below the '
              'centre of a half-circle are on the excluded lower half');
    });
  });

  test(
      'an intersection candidate names the later-drawn (greater-handle) '
      'entity', () {
    // Two lines cross at a single point; SnapResult.entity must pick one of
    // them deterministically. This fixture is asymmetric on purpose (the
    // crossing is not at either line's own midpoint or endpoint) so that
    // a swapped-operand bug -- reporting the *lower* handle -- is
    // observable rather than accidentally matching by symmetry.
    final doc = DraftDocument.empty();
    final first = addLine(doc, [0, 0, 10, 0]);
    final second = addLine(doc, [3, -5, 3, 5]);
    expect(second.value, greaterThan(first.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(3.1, 0.1), 1.0,
        const SnapMask(0).with_(SnapKind.intersection), out);

    expect(out.found, isTrue);
    expect(out.point.x, closeTo(3, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
    expect(out.entity, second,
        reason: 'SnapResult.entity for an intersection names the '
            'later-drawn (greater-handle) of the two crossing entities, the '
            'same "later drawn wins" convention _considerSnapCandidate '
            'already uses to break every other snap tie in this class');
  });

  test('endpoint (a cheap kind) still outranks intersection', () {
    // Both an endpoint and an intersection point sit inside the radius;
    // if intersection's priority slot were wrong relative to the cheap
    // kinds, it could win here even though endpoint must dominate by
    // SnapKind's declared order.
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    addLine(doc, [0, -5, 0, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, SnapMask.all, out);
    expect(out.kind, SnapKind.endpoint,
        reason: 'the two lines also cross exactly at (0,0), giving an '
            'intersection candidate at the same location as the endpoint; '
            'endpoint must still win on kind priority alone');
  });

  test(
      'the intersection cap selects the lowest handles, not whichever the '
      'R-tree visits first', () {
    // 70 lines, added in ascending-handle order with ascending X position
    // (handle N sits at X = (N-1)*10). Handles 1..64 are short, mutually
    // parallel (non-crossing) vertical bars. Handles 65 and 66 are the only
    // crossing pair, placed at the high-X end -- outside the 64 lowest
    // handles. A correct cap (ascending handle order) never considers
    // handles 65/66 at all, so no crossing is found. A cap that instead
    // takes the first kIntersectionCandidateCap entities in R-tree visit
    // order is not handle-ordered, and for this exact layout (verified
    // against the real PackedRTree, which packs leaves by ascending centre
    // X and then visits children highest-index-first) visits in roughly
    // *descending* handle order -- so it would include handles 65 and 66
    // and report a hit.
    final doc = DraftDocument.empty();
    const n = 70;
    for (var i = 0; i < n; i++) {
      final x = i * 10.0;
      if (i == 64) {
        // First half of the crossing pair (handle 65): rises left to right.
        addLine(doc, [x, -5, x + 10, 5]);
      } else if (i == 65) {
        // Second half (handle 66): falls left to right over the same span,
        // so the two actually cross at their shared midpoint.
        addLine(doc, [x - 10, 5, x, -5]);
      } else {
        addLine(doc, [x, -1, x, 1]);
      }
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2((n - 1) * 5.0, 0), (n - 1) * 5.0 + 10,
        const SnapMask(0).with_(SnapKind.intersection), out);
    expect(out.found, isFalse,
        reason: 'the only crossing pair sits outside the 64 lowest '
            'handles, and the cap must be chosen by handle, not by '
            'traversal order');
  });
}

double _tangentLengthForTest(
    double px, double py, double cx, double cy, double r) {
  final dx = px - cx, dy = py - cy;
  final d2 = dx * dx + dy * dy;
  return math.sqrt(d2 - r * r);
}
