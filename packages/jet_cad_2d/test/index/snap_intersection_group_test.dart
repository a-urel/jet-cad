// Intersection snaps over root-level leaves that sit inside flattened
// groups (post-11 found item (a)).
//
// A leaf in a root-level `GroupNode` stores its coordinates in the group's
// space; `ContainerIndex.transformOfLeaf` carries them to world. Every
// fixture below puts the group at a transform that is neither the identity
// nor a pure translation where a translation would hide the mistake, and
// every expected point is computed by hand in the test's own comments, so
// a crossing found in stored coordinates (the phantom) and a crossing found
// in world coordinates can never coincide by accident.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const SnapMask _intersectionOnly = SnapMask(1 << 7);

Handle _group(DraftDocument doc, Transform2 transform, {Handle? parent}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: handle,
    parent: parent ?? doc.rootHandle,
    transform: transform,
    children: const [],
  )));
  return handle;
}

Handle _leaf(
    DraftDocument doc, Handle owner, EntityKind kind, List<double> coords) {
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
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Handle _line(DraftDocument doc, Handle owner, List<double> coords) =>
    _leaf(doc, owner, EntityKind.line, coords);

SnapResult _snap(SpatialIndex index, double x, double y, double radius,
    {SnapMask mask = _intersectionOnly}) {
  final out = SnapResult();
  index.snapInto(Vector2(x, y), radius, mask, out);
  return out;
}

void _expectIntersectionAt(SnapResult out, double x, double y, String what) {
  expect(out.found, isTrue, reason: '$what: an intersection snap');
  expect(out.kind, SnapKind.intersection, reason: what);
  expect(out.point.x, closeTo(x, 1e-9), reason: what);
  expect(out.point.y, closeTo(y, 1e-9), reason: what);
}

void main() {
  test('the mask these tests use is intersection alone', () {
    expect(_intersectionOnly.bits,
        const SnapMask(0).with_(SnapKind.intersection).bits);
  });

  test(
      'two lines in one turned-and-moved group snap at their world crossing, '
      'not at the stored one', () {
    // G: rotation with cos 0.8, sin 0.6, then translation (100, 50).
    // Local: L1 (0, 0)-(10, 0), L2 (4, -3)-(4, 5); they cross at local
    // (4, 0), the middle of both. World: (0.8 * 4 + 100, 0.6 * 4 + 50) =
    // (103.2, 52.4).
    final doc = DraftDocument.empty();
    final g = _group(doc, const Transform2(0.8, 0.6, -0.6, 0.8, 100, 50));
    _line(doc, g, [0, 0, 10, 0]);
    final l2 = _line(doc, g, [4, -3, 4, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = _snap(index, 103.5, 52.1, 1.0);
    _expectIntersectionAt(out, 103.2, 52.4, 'the world crossing');
    expect(out.entity, l2, reason: 'the later-drawn of the pair names it');
  });

  test(
      'no intersection snap at the phantom point, where the stored '
      'coordinates cross', () {
    // G: rotation cos 0.8, sin 0.6 about the origin. Local: L1 (-10, 0)-
    // (10, 0), L2 (4, -10)-(4, 10), crossing at local (4, 0). World
    // crossing: (3.2, 2.4), 2.53 from (4, 0). World boxes: L1 from (-8, -6)
    // to (8, 6); L2 from (-2.8, -5.6) to (9.2, 10.4) (its ends are
    // (0.8 * 4 + 0.6 * 10, 0.6 * 4 - 0.8 * 10) = (9.2, -5.6) and (-2.8,
    // 10.4)). Both boxes hold (4, 0), so both lines are candidates there:
    // only the segment coordinates decide.
    final doc = DraftDocument.empty();
    final g = _group(doc, const Transform2(0.8, 0.6, -0.6, 0.8, 0, 0));
    _line(doc, g, [-10, 0, 10, 0]);
    _line(doc, g, [4, -10, 4, 10]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(_snap(index, 4, 0, 1.0).found, isFalse,
        reason: 'the stored crossing (4, 0) is 2.53 from any world '
            'crossing: nothing to snap to within 1');
    _expectIntersectionAt(
        _snap(index, 3.2, 2.4, 1.0), 3.2, 2.4, 'the world crossing');
  });

  test('a grouped line crossing an ungrouped root line', () {
    // G: rotation cos 0.8, sin 0.6, then translation (20, 10). Its line,
    // local (0, 0)-(10, 0), runs in world from (20, 10) to (28, 16): (20 +
    // 8t, 10 + 6t). The root line x = 24, y 10..20, meets it at t = 0.5:
    // (24, 13). In stored coordinates the grouped line is y = 0, x 0..10,
    // which never reaches x = 24.
    final doc = DraftDocument.empty();
    final g = _group(doc, const Transform2(0.8, 0.6, -0.6, 0.8, 20, 10));
    _line(doc, g, [0, 0, 10, 0]);
    final root = _line(doc, doc.rootHandle, [24, 10, 24, 20]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = _snap(index, 24.3, 13.2, 1.0);
    _expectIntersectionAt(out, 24, 13, 'grouped x ungrouped');
    expect(out.entity, root);
  });

  test('two lines in two different groups (a transform per side)', () {
    // G1: rotation cos 0.8, sin 0.6, translation (50, 0); line local (0, 0)-
    // (20, 0), world (50 + 16t, 12t). G2: scale (2, 0.5), translation (40,
    // -10); line local (10, -4)-(10, 56), world x = 2 * 10 + 40 = 60, y
    // from 0.5 * -4 - 10 = -12 to 0.5 * 56 - 10 = 18. They meet at 50 + 16t
    // = 60: t = 0.625, y = 7.5, so (60, 7.5). Stored, they cross at (10, 0).
    final doc = DraftDocument.empty();
    final g1 = _group(doc, const Transform2(0.8, 0.6, -0.6, 0.8, 50, 0));
    final g2 = _group(doc, const Transform2(2, 0, 0, 0.5, 40, -10));
    _line(doc, g1, [0, 0, 20, 0]);
    _line(doc, g2, [10, -4, 10, 56]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    _expectIntersectionAt(
        _snap(index, 59.6, 7.9, 1.0), 60, 7.5, 'two groups, two transforms');
  });

  test(
      'a polyline whose world-near segment is not its stored-near segment '
      '(the near filter and the pair loop must both map)', () {
    // G: translation (100, 0). Polyline local P0 (105, 0), P1 (105, 10),
    // P2 (-95, 0).
    //   s0 stored (105, 0)-(105, 10): passes through q = (105, 5).
    //       world (205, 0)-(205, 10): 100 from q.
    //   s1 stored (105, 10)-(-95, 0): 4.99 from q (|(0, -5) x (-200, -10)|
    //       / |(-200, -10)| = 1000 / 200.25).
    //       world (205, 10)-(5, 0): at x = 105, t = 0.5, y = 5 -- through q.
    // The root line x = 105, y 2..8, crosses world s1 at (105, 5). Stored s1
    // is at y = 10 at x = 105 (outside 2..8), stored s0 is collinear with it
    // (no crossing), world s0 is parallel to it: only world s1 gives the
    // crossing, and only a near filter that also measures world s1 keeps it.
    final doc = DraftDocument.empty();
    final g = _group(doc, Transform2.translation(100, 0));
    _leaf(doc, g, EntityKind.polyline, [105, 0, 105, 10, -95, 0]);
    _line(doc, doc.rootHandle, [105, 2, 105, 8]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    _expectIntersectionAt(
        _snap(index, 105.2, 5.1, 1.0), 105, 5, 'the world-near segment');
  });

  test('a mirrored group (negative determinant) snaps at its world crossing',
      () {
    // G = rotation (cos 0.8, sin 0.6) after scale (-2, 1):
    // [[0.8, -0.6], [0.6, 0.8]] . [[-2, 0], [0, 1]] = [[-1.6, -0.6],
    // [-1.2, 0.8]], so a = -1.6, b = -1.2, c = -0.6, d = 0.8 (det -2), then
    // translation (30, 5). Local L1 (0, 1)-(10, 1), L2 (3, -5)-(8, 5): L2 is
    // (3 + 5s, -5 + 10s), y = 1 at s = 0.6, x = 6: local crossing (6, 1).
    // World: x = -1.6 * 6 - 0.6 * 1 + 30 = 19.8, y = -1.2 * 6 + 0.8 * 1 + 5 =
    // -1.4.
    const m = Transform2(-1.6, -1.2, -0.6, 0.8, 30, 5);
    expect(m.determinant, lessThan(0), reason: 'premise: a mirror');
    expect(m.b, isNot(m.c),
        reason: 'premise: not symmetric, so a '
            'transposed linear part is a different map');
    final doc = DraftDocument.empty();
    final g = _group(doc, m);
    _line(doc, g, [0, 1, 10, 1]);
    _line(doc, g, [3, -5, 8, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    _expectIntersectionAt(
        _snap(index, 19.5, -1.0, 1.0), 19.8, -1.4, 'the mirrored crossing');
    expect(_snap(index, 6, 1, 1.0).found, isFalse,
        reason: 'nothing at the stored crossing');
  });

  test('a group nested in a group composes both transforms', () {
    // Outer: translation (10, 20). Inner: rotation cos 0.6, sin 0.8. A leaf
    // at local (x, y) is at (0.6x - 0.8y + 10, 0.8x + 0.6y + 20). Inner L1
    // (0, 0)-(10, 0), L2 (5, -5)-(5, 5): local crossing (5, 0), world
    // (13, 24).
    final doc = DraftDocument.empty();
    final outer = _group(doc, Transform2.translation(10, 20));
    final inner =
        _group(doc, const Transform2(0.6, 0.8, -0.8, 0.6, 0, 0), parent: outer);
    _line(doc, inner, [0, 0, 10, 0]);
    _line(doc, inner, [5, -5, 5, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    _expectIntersectionAt(
        _snap(index, 13.3, 23.8, 1.0), 13, 24, 'the nested crossing');
  });

  test(
      'the snap follows a TransformNodeCommand on the group, and its undo, '
      'on a live index', () {
    // T0: rotation cos 0.6, sin 0.8, translation (-20, 7). T1: rotation
    // cos 0.8, sin 0.6, translation (100, 50). Local crossing (4, 0) of
    // L1 (0, 0)-(10, 0) and L2 (4, -3)-(4, 5): at T0, (0.6 * 4 - 20, 0.8 * 4
    // + 7) = (-17.6, 10.2); at T1, (103.2, 52.4).
    final doc = DraftDocument.empty();
    final g = _group(doc, const Transform2(0.6, 0.8, -0.8, 0.6, -20, 7));
    _line(doc, g, [0, 0, 10, 0]);
    _line(doc, g, [4, -3, 4, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    _expectIntersectionAt(_snap(index, -17.4, 10.5, 1.0), -17.6, 10.2, 'T0');
    final rebuilds = index.rebuildCount;

    doc.commands.execute(TransformNodeCommand(
        g, const Transform2(0.8, 0.6, -0.6, 0.8, 100, 50)));
    _expectIntersectionAt(_snap(index, 103.5, 52.1, 1.0), 103.2, 52.4, 'T1');
    expect(_snap(index, -17.6, 10.2, 1.0).found, isFalse,
        reason: 'nothing left at T0');
    // Which route this covers: a node's transform is a structural edit, and
    // `SpatialIndex._reconcile` answers every structural edit with a full
    // rebuild of this same index. The dirty-overlay route is the next test.
    expect(index.rebuildCount, greaterThan(rebuilds),
        reason: 'premise: a group move reconciles by rebuilding');

    doc.commands.undo();
    _expectIntersectionAt(
        _snap(index, -17.4, 10.5, 1.0), -17.6, 10.2, 'T0 after undo');
    expect(_snap(index, 103.2, 52.4, 1.0).found, isFalse,
        reason: 'nothing left at T1 after undo');
  });

  test(
      'the snap follows an edit to a grouped leaf through the dirty overlay, '
      'and its undo', () {
    // G: rotation cos 0.8, sin 0.6, translation (100, 50). L1 local (0, 0)-
    // (10, 0). L2 local (4, -3)-(4, 5) crosses it at local (4, 0), world
    // (103.2, 52.4); moved to local (6, -3)-(6, 5) it crosses at local
    // (6, 0), world (0.8 * 6 + 100, 0.6 * 6 + 50) = (104.8, 53.6). The two
    // world crossings are 2 apart, so a radius-1 query at one never reaches
    // the other.
    final doc = DraftDocument.empty();
    final g = _group(doc, const Transform2(0.8, 0.6, -0.6, 0.8, 100, 50));
    _line(doc, g, [0, 0, 10, 0]);
    final l2 = _line(doc, g, [4, -3, 4, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    _expectIntersectionAt(
        _snap(index, 103.5, 52.1, 1.0), 103.2, 52.4, 'before the edit');
    final rebuilds = index.rebuildCount;
    final dirty = index.dirtyCount;

    doc.commands.execute(SetEntityGeometryCommand(
        l2,
        GeometryPayload(
          coords: Float64List.fromList([6, -3, 6, 5]),
          scalars: Float64List(0),
        )));
    _expectIntersectionAt(
        _snap(index, 104.6, 53.9, 1.0), 104.8, 53.6, 'after the edit');
    expect(_snap(index, 103.2, 52.4, 1.0).found, isFalse,
        reason: 'nothing left at the old crossing');
    expect(index.rebuildCount, rebuilds,
        reason: 'premise: the edit went through the dirty overlay, not a '
            'rebuild');
    expect(index.dirtyCount, greaterThan(dirty),
        reason: 'premise: the edit wrote a dirty entry');

    doc.commands.undo();
    _expectIntersectionAt(
        _snap(index, 103.5, 52.1, 1.0), 103.2, 52.4, 'after the undo');
    expect(_snap(index, 104.8, 53.6, 1.0).found, isFalse,
        reason: 'nothing left at the edited crossing after the undo');
    expect(index.rebuildCount, rebuilds,
        reason: 'premise: the undo went through the dirty overlay too');
  });

  test(
      'the near-segment buffer keeps the rows it wrote before it grows '
      '(more than 64 near segments in one query)', () {
    // A fresh index's buffer holds 64 near segments. A: the root line x = 0,
    // y -1..1. B: local (0, 0)-(2, 0) in a group at translation (-1, 0.3),
    // world y = 0.3, x -1..1: A and B cross at (0, 0.3). C: an 81-point
    // polyline, local (0.01 i, 0), in a group at translation (0.2, 0.9) --
    // world y = 0.9, x 0.2..1.0, 80 segments, every one within 1.35 of the
    // query point (0, 0), none crossing A (x >= 0.2) or B (parallel). The
    // candidates are taken in handle order, so A's and B's rows are written
    // first and C's 80 push the buffer past 64 while they are in it.
    final doc = DraftDocument.empty();
    _line(doc, doc.rootHandle, [0, -1, 0, 1]);
    final gb = _group(doc, Transform2.translation(-1, 0.3));
    _line(doc, gb, [0, 0, 2, 0]);
    final gc = _group(doc, Transform2.translation(0.2, 0.9));
    _leaf(doc, gc, EntityKind.polyline, [
      for (var i = 0; i <= 80; i++) ...[0.01 * i, 0.0],
    ]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    _expectIntersectionAt(
        _snap(index, 0.1, 0.1, 2.0), 0, 0.3, 'A x B, after the growth');
  });

  test(
      'a one-point polyline among the candidates leaves the crossing pair '
      'and its name alone', () {
    // G: rotation cos 0.8, sin 0.6, translation (100, 50). L1 local (0, 0)-
    // (10, 0) and L2 local (4, -3)-(4, 5) cross at local (4, 0), world
    // (103.2, 52.4). P: a root polyline with a single point (103, 52),
    // drawn last, so it has the greatest handle and sits last among the
    // candidates (its box is the point itself, inside the query square
    // (102.5, 51.1)-(104.5, 53.1)). It has no segment, so it contributes
    // no near segment and takes part in no pair: the crossing is L1 x L2,
    // and it is named by L2, the later-drawn of that pair -- not by P,
    // whose handle is greater still. A candidate that skipped writing its
    // own start offset would inherit a stale one and claim other
    // candidates' segments as its own.
    final doc = DraftDocument.empty();
    final g = _group(doc, const Transform2(0.8, 0.6, -0.6, 0.8, 100, 50));
    _line(doc, g, [0, 0, 10, 0]);
    final l2 = _line(doc, g, [4, -3, 4, 5]);
    final p = _leaf(doc, doc.rootHandle, EntityKind.polyline, [103, 52]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(p.value, greaterThan(l2.value),
        reason: 'premise: the one-point polyline is drawn last');
    final seen = <Handle>[];
    index.rootIndex.searchLeavesRaw(102.5, 51.1, 104.5, 53.1,
        (slot) => seen.add(doc.entities.handleAt(slot)));
    expect(seen, contains(p),
        reason: 'premise: the one-point polyline is an intersection '
            'candidate at this query');

    final out = _snap(index, 103.5, 52.1, 1.0);
    _expectIntersectionAt(out, 103.2, 52.4, 'L1 x L2, next to P');
    expect(out.entity, l2,
        reason: 'the later-drawn line of the crossing pair names it, not '
            'the one-point polyline drawn after both');
  });
}
