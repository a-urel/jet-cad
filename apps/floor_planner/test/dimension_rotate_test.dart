// Spec 11 D11 (decisions 12 and 17, R-19) and D6's offset × scale: a
// dimension under the select tool's move and rotate. A fixed end is a point
// in the dimension's group, so it moves and turns with the group; an
// attached end is read from its wall, so it never moves by itself; a linear
// kind measures along the group's own axes, so they turn with it; the
// offset is a local length, multiplied by the group's scale once (D6), and
// the text's stored height is divided by it (D8).
//
// Each move and turn is a `TransformNodeCommand` per group, composed as the
// select tool composes it (`grip_drag.dart`: `t · node.transform`, world
// being root space), one compound for several groups. Every expected value
// is hand arithmetic beside the assertion; each dimension's own group sits
// at the placement (turned further in `DR2`, and by the turn itself in the
// others), so a hand value in the plan's frame holds at every placement.
// After every edit `drift()` and the all-walls oracle are empty. Ported
// from the spike's `rotate_test.dart` (`Q4a`, `Q4b`, `Q4c`, `Q4e`).
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

const l = WallSide.left, r = WallSide.right;

/// The rotation by [deg] degrees about world point [pivot].
Transform2 rotAbout(Vector2 pivot, double deg) =>
    Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(deg * math.pi / 180))
        .multiply(Transform2.translation(-pivot.x, -pivot.y));

/// Every group of [hs] transformed by [t] in one compound, as the select
/// tool's move and rotate issue it: `t · node.transform` per group.
void transformAll(DraftDocument doc, List<Handle> hs, Transform2 t,
        {String label = 'Rotate'}) =>
    doc.commands.execute(CompoundCommand([
      for (final h in hs)
        TransformNodeCommand(h, t.multiply(doc.tree[h]!.transform)),
    ], label: label));

/// `drift()` and the all-walls oracle, both empty, after [what].
void expectFollows(DraftDocument doc, String what) {
  expect(driftOf(doc), isEmpty, reason: 'drift after $what');
  expect(oracleFailures(doc), isEmpty, reason: 'oracle after $what');
}

void expectNear(Vector2 got, Vector2 want, String what, {double tol = 1e-6}) {
  expect((got - want).length, lessThan(tol), reason: '$what: $got, want $want');
}

/// Dimension [h]'s dimension line in world, `(q0, q1)`: its first LINE
/// child.
(Vector2, Vector2) lineOf(DraftDocument doc, Handle h) => dimLines(doc, h)[0];

/// The world angle of dimension [h]'s dimension line, q0 → q1, in
/// **radians**, and [deg] in radians, for a `closeTo` of 1e-9 rad. Not
/// degrees: at +1e9 mm the layout's world points (D6, in world) round to
/// about 1.2e-7 mm each, which turns a 3000 mm line by about 3e-11 rad,
/// 1.7e-9° (measured), beyond 1e-9 read as degrees.
double lineAngle(DraftDocument doc, Handle h) {
  final (a, b) = lineOf(doc, h);
  return math.atan2(b.y - a.y, b.x - a.x);
}

double rad(double deg) => deg * math.pi / 180;

/// The perpendicular distance from world [p] to dimension [h]'s dimension
/// line.
double lineDistance(DraftDocument doc, Handle h, Vector2 p) {
  final (a, b) = lineOf(doc, h);
  final d = (b - a).normalized();
  final w = p - a;
  return (w.x * d.y - w.y * d.x).abs();
}

/// The unit left normal of dimension [h]'s dimension line, q0 → q1.
Vector2 lineNormal(DraftDocument doc, Handle h) {
  final (a, b) = lineOf(doc, h);
  final u = (b - a).normalized();
  return Vector2(-u.y, u.x);
}

void main() {
  for (final place in placements) {
    test(
        'DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 '
        'aligned, its line at the placement\'s angle plus 30°, at $place', () {
      final plan = buildPlan(const [], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      // Two fixed points (0, 0) and (3000, 1200) in a group at the
      // placement, so the plan's frame is the group's: horizontal 3000,
      // vertical 1200, aligned √(3000² + 1200²) = √10,440,000 = 3231.1.
      final g = place.m;
      const e0 = FixedEnd(0, 0), e1 = FixedEnd(3000, 1200);
      final ho = addDimension(doc, e0, e1,
          kind: DimKind.horizontal, offset: -500.25, at: g);
      final ve = addDimension(doc, e0, e1,
          kind: DimKind.vertical, offset: 300.75, at: g);
      final al = addDimension(doc, e0, e1, offset: 400.5, at: g);
      expect(math.sqrt(3000.0 * 3000 + 1200 * 1200), closeTo(3231.1, 0.01));
      final want = ['3000', '1200', '3231'];
      expect([
        for (final h in [ho, ve, al]) dimText(doc, h)
      ], want);
      expect(lineAngle(doc, ho), closeTo(rad(place.deg), 1e-9));
      expectFollows(doc, 'the add');

      // The three turned 30° about a far pivot, both ends fixed, so both
      // move. Local axes keep every value. World axes would read, at a
      // placement turned 0°, the turned vector's x: 3000 cos 30° − 1200 sin
      // 30° = 2598.08 − 600 = 1998 (spike `Q4a`), and its y for the
      // vertical: 3000 sin 30° + 1200 cos 30° = 1500 + 1039.23 = 2539.
      final t = rotAbout(plan.at(-7000.5, 2500.25), 30);
      transformAll(doc, [ho, ve, al], t);
      expect([
        for (final h in [ho, ve, al]) dimText(doc, h)
      ], want);
      // The horizontal line runs along the group's x, q0 → q1 (its value
      // 3000 is along +x), at the placement's angle plus 30°; the vertical
      // one along the group's y, 90° more; the aligned one along
      // (3000, 1200), atan2(1200, 3000) = 21.80° more.
      expect(lineAngle(doc, ho), closeTo(rad(place.deg + 30), 1e-9));
      expect(lineAngle(doc, ve), closeTo(rad(place.deg + 30 + 90), 1e-9));
      expect(lineAngle(doc, al),
          closeTo(rad(place.deg + 30) + math.atan2(1200, 3000), 1e-9));
      final (_, _, textAngle) = dimTextGeometry(doc, ho);
      expect(textAngle * 180 / math.pi, closeTo(place.deg + 30, 1e-9));
      // The fixed ends moved with the group: the horizontal line (sign bit
      // set, so c = lo + o = 0 − 500.25) runs from (0, −500.25) to (3000,
      // −500.25) in the plan's frame, both taken through the turn.
      final (q0, q1) = lineOf(doc, ho);
      expectNear(q0, t.transformPoint(plan.at(0, -500.25)), 'horizontal q0');
      expectNear(q1, t.transformPoint(plan.at(3000, -500.25)), 'horizontal q1');
      expectFollows(doc, 'the turn');

      doc.commands.undo();
      expect([
        for (final h in [ho, ve, al]) dimText(doc, h)
      ], want);
      expect(lineAngle(doc, ho), closeTo(rad(place.deg), 1e-9));
      expectFollows(doc, 'the undo');
    });
  }

  for (final place in const [origin, corpusGroups]) {
    test(
        'DR2 an attached end stays with its wall while a fixed end moves '
        'and turns with the group, at $place', () {
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      // A (0, 0) → (4000, 0), 200 centred: A/1/left is its free end on the
      // left face, (4000, 100).
      expect(bruteCandidates(doc, plan.at(4000, 100)), [AttachedEnd(a, 1, l)],
          reason: 'premise: A/1/left');
      // The dimension's group turned a further 17° and moved off the
      // placement, so a fixed end's stored point is not its plan point.
      final g = place.m
          .multiply(Transform2.translation(-1250.5, 830.25))
          .multiply(Transform2.rotation(17 * math.pi / 180));
      final fixed = fixedAt(plan.at(4000, 3100), g);
      expect((fixed.point - Vector2(4000, 3100)).length, greaterThan(100),
          reason: 'premise: the stored point is not the plan point');
      // Aligned, offset 600.5 on the left normal: the line lies 600.5 off
      // both measured points (h1 = 0 by definition, D6).
      final dim =
          addDimension(doc, AttachedEnd(a, 1, l), fixed, offset: 600.5, at: g);

      /// The two measured points, read back from the stored line: q − 600.5
      /// n.
      (Vector2, Vector2) feet() {
        final (q0, q1) = lineOf(doc, dim);
        final n = lineNormal(doc, dim);
        return (q0 - n * 600.5, q1 - n * 600.5);
      }

      // (4000, 100) to (4000, 3100): 3000.
      expect(dimText(doc, dim), '3000');
      var (p0, p1) = feet();
      expectNear(p0, plan.at(4000, 100), 'added: the attached end');
      expectNear(p1, plan.at(4000, 3100), 'added: the fixed end');
      expectFollows(doc, 'the add');

      // Moved (700, 0) in the plan: the fixed end to (4700, 3100), the
      // attached end kept: √(700² + 3000²) = √9,490,000 = 3080.58.
      final mv = plan.at(700, 0) - plan.at(0, 0);
      transformAll(doc, [dim], Transform2.translation(mv.x, mv.y),
          label: 'Move');
      expect(math.sqrt(700.0 * 700 + 3000 * 3000), closeTo(3080.58, 0.01));
      expect(dimText(doc, dim), '3081');
      (p0, p1) = feet();
      expectNear(p0, plan.at(4000, 100), 'moved: the attached end');
      expectNear(p1, plan.at(4700, 3100), 'moved: the fixed end');
      expectFollows(doc, 'the move');

      // Then turned 37° about the plan's (0, 0): the fixed end (4700, 3100)
      // goes to (4700 c − 3100 s, 4700 s + 3100 c), c = cos 37° =
      // 0.798636, s = sin 37° = 0.601815: (3753.59 − 1865.63, 2828.53 +
      // 2475.77) = (1887.96, 5304.30); from (4000, 100): (−2112.04,
      // 5204.30), √(4,460,713 + 27,084,748) = √31,545,461 = 5616.53.
      transformAll(doc, [dim], rotAbout(plan.at(0, 0), 37));
      const c = 0.7986355100472928, s = 0.6018150231520483;
      expect(c, closeTo(math.cos(37 * math.pi / 180), 1e-15));
      expect(s, closeTo(math.sin(37 * math.pi / 180), 1e-15));
      const fx = 4700 * c - 3100 * s, fy = 4700 * s + 3100 * c;
      expect(fx, closeTo(1887.96, 0.01));
      expect(fy, closeTo(5304.30, 0.01));
      final len = math.sqrt(math.pow(fx - 4000, 2) + math.pow(fy - 100, 2));
      expect(len, closeTo(5616.53, 0.01));
      expect(dimText(doc, dim), '5617');
      (p0, p1) = feet();
      expectNear(p0, plan.at(4000, 100), 'turned: the attached end');
      expectNear(p1, plan.at(fx, fy), 'turned: the fixed end');
      expect(
          (oracleEnd(doc, dim, AttachedEnd(a, 1, l))! - plan.at(4000, 100))
              .length,
          lessThan(1e-6),
          reason: 'the wall itself never moved');
      expectFollows(doc, 'the turn');

      doc.commands.undo();
      expect(dimText(doc, dim), '3081');
      doc.commands.undo();
      expect(dimText(doc, dim), '3000');
      (p0, p1) = feet();
      expectNear(p1, plan.at(4000, 3100), 'undone: the fixed end');
      expectFollows(doc, 'the undo');
    });

    test('DR3 walls and dimensions turned together keep every value, at $place',
        () {
      final plan = buildPlan(
          const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
          place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a, b] = plan.walls;
      // C2's L, both 200 centred, mitred at (4000, 0): A/0/right is A's free
      // start on its right face (0, −100); the outer corner (4100, −100) is
      // A/1/right and B/0/right; B/1/right is B's free end (4100, 3000); the
      // inner corner (3900, 100) is A/1/left and B/0/left.
      expect(bruteCandidates(doc, plan.at(0, -100)), [AttachedEnd(a, 0, r)],
          reason: 'premise: A/0/right');
      expect(bruteCandidates(doc, plan.at(4100, -100)),
          [AttachedEnd(a, 1, r), AttachedEnd(b, 0, r)],
          reason: 'premise: the outer corner');
      expect(bruteCandidates(doc, plan.at(4100, 3000)), [AttachedEnd(b, 1, r)],
          reason: 'premise: B/1/right');
      expect(bruteCandidates(doc, plan.at(3900, 100)),
          [AttachedEnd(a, 1, l), AttachedEnd(b, 0, l)],
          reason: 'premise: the inner corner');
      final g = place.m;
      // Horizontal, the outer faces: (0, −100) → (4100, −100): 4100; its
      // line (sign bit set, h1 = 0) at −100 − 800 = −900, 800 from both.
      final hd = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(b, 0, r),
          kind: DimKind.horizontal, offset: -800, at: g);
      // Vertical, B's right face: (4100, −100) → (4100, 3000): 3100; n =
      // (−1, 0), h1 = 0, the line at x 4100 − 700 = 3400, 700 from both.
      final vd = addDimension(doc, AttachedEnd(b, 0, r), AttachedEnd(b, 1, r),
          kind: DimKind.vertical, offset: 700, at: g);
      // Aligned, the inner corner to a fixed (1000, 2500): √(2900² + 2400²)
      // = √14,170,000 = 3764.31.
      final ad = addDimension(
          doc, AttachedEnd(a, 1, l), fixedAt(plan.at(1000, 2500), g),
          offset: 300, at: g);
      expect(math.sqrt(2900.0 * 2900 + 2400 * 2400), closeTo(3764.31, 0.01));
      final want = ['4100', '3100', '3764'];
      expect([
        for (final h in [hd, vd, ad]) dimText(doc, h)
      ], want);
      expect(lineDistance(doc, hd, plan.at(0, -100)), closeTo(800, 1e-6));
      expect(lineDistance(doc, vd, plan.at(4100, -100)), closeTo(700, 1e-6));
      expectFollows(doc, 'the add');

      // All five turned 30° about a far pivot, one compound: every value
      // kept, and each line keeps its distance from its measured points,
      // which turned with their walls. World axes would give the horizontal
      // 4100 cos(place + 30°) and the vertical 3100 cos(place + 30°).
      final t = rotAbout(plan.at(9000.5, -4000.25), 30);
      final depth = doc.commands.undoDepth;
      transformAll(doc, [a, b, hd, vd, ad], t);
      expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
      expect([
        for (final h in [hd, vd, ad]) dimText(doc, h)
      ], want);
      final pa = oracleEnd(doc, hd, AttachedEnd(a, 0, r))!;
      expectNear(pa, t.transformPoint(plan.at(0, -100)), 'A/0/right turned');
      expect(lineDistance(doc, hd, pa), closeTo(800, 1e-6));
      final pb = oracleEnd(doc, vd, AttachedEnd(b, 0, r))!;
      expectNear(pb, t.transformPoint(plan.at(4100, -100)), 'B/0/right turned');
      expect(lineDistance(doc, vd, pb), closeTo(700, 1e-6));
      expect(lineAngle(doc, hd), closeTo(rad(place.deg + 30), 1e-9));
      expect(lineAngle(doc, vd), closeTo(rad(place.deg + 30 + 90), 1e-9));
      expectFollows(doc, 'the turn');

      doc.commands.undo();
      expect([
        for (final h in [hd, vd, ad]) dimText(doc, h)
      ], want);
      expect(lineDistance(doc, hd, plan.at(0, -100)), closeTo(800, 1e-6));
      expectFollows(doc, 'the undo');
    });

    test(
        'DR4 a both-ends-attached linear dimension turned alone turns its '
        'axis: 4000 reads 3464, at $place', () {
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      // A's right face: A/0/right (0, −100), A/1/right (4000, −100).
      expect(bruteCandidates(doc, plan.at(0, -100)), [AttachedEnd(a, 0, r)],
          reason: 'premise: A/0/right');
      expect(bruteCandidates(doc, plan.at(4000, -100)), [AttachedEnd(a, 1, r)],
          reason: 'premise: A/1/right');
      final dim = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
          kind: DimKind.horizontal, offset: -600.5, at: place.m);
      expect(dimText(doc, dim), '4000');
      // Unturned: h1 = 0, the line at −100 − 600.5.
      var (q0, q1) = lineOf(doc, dim);
      expectNear(q0, plan.at(0, -700.5), 'unturned q0');
      expectNear(q1, plan.at(4000, -700.5), 'unturned q1');
      expectFollows(doc, 'the add');

      // The dimension alone turned 30° about (2000, 0): its ends stay on
      // the wall, its axis turns: u = (cos 30°, sin 30°) in the plan's
      // frame, and the value is |(4000, 0) · u| = 4000 cos 30° = 3464.10.
      transformAll(doc, [dim], rotAbout(plan.at(2000, 0), 30));
      expect(4000 * math.cos(math.pi / 6), closeTo(3464.10, 0.01));
      expect(dimText(doc, dim), '3464');
      // n = (−sin 30°, cos 30°) = (−0.5, 0.866025): h1 = (4000, 0) · n =
      // −2000, so hi = 0 and lo = −2000; the sign bit set, c = lo − 600.5 =
      // −2600.5. So q0 = P0 + c n = (0 + 1300.25, −100 − 2252.10), and q1 =
      // P1 + (c − h1) n = P1 − 600.5 n = (4000 + 300.25, −100 − 520.05):
      // both feet on the wall, where they were.
      const sn = 0.5, cs = 0.8660254037844387;
      expect(cs, closeTo(math.cos(math.pi / 6), 1e-15));
      (q0, q1) = lineOf(doc, dim);
      expectNear(q0, plan.at(2600.5 * sn, -100 - 2600.5 * cs), 'turned q0');
      expectNear(
          q1, plan.at(4000 + 600.5 * sn, -100 - 600.5 * cs), 'turned q1');
      expect(lineAngle(doc, dim), closeTo(rad(place.deg + 30), 1e-9));
      expectFollows(doc, 'the turn');

      doc.commands.undo();
      expect(dimText(doc, dim), '4000');
      expectFollows(doc, 'the undo');
    });
  }

  test(
      'DR5 under a turned, translated group scaled 1.5 the world offset is '
      '1.5 times the stored one and the text is 125 world mm tall, at the '
      'corpus far origin', () {
    final plan = buildPlan(const [], place: corpus);
    final doc = plan.doc;
    attachPage(doc, mmPage);
    // Built by hand (file only: no gesture scales a group): the corpus far
    // origin moved, turned 30°, scaled 1.5 uniformly.
    const s = 1.5;
    final g = Transform2.translation(4500000 + 1234.5, 1200000 - 876.25)
        .multiply(Transform2.rotation(30 * math.pi / 180))
        .multiply(Transform2.scale(s, s));
    expect(g.scaleMagnitude, closeTo(1.5, 1e-15), reason: 'premise: scaled');
    // Local (100.5, 200.25) and (3100.5, 1400.25): d = (3000, 1200) local,
    // 1.5 times that in world.
    const e0 = FixedEnd(100.5, 200.25), e1 = FixedEnd(3100.5, 1400.25);
    final w0 = g.transformPoint(e0.point), w1 = g.transformPoint(e1.point);
    // Horizontal, offset 600.5: the value 1.5 × 3000 = 4500; hi = the
    // outer point's height, 1.5 × 1200 = 1800 above P0 in world; the line
    // 600.5 × 1.5 = 900.75 world mm above P1, and 1800 + 900.75 = 2700.75
    // above P0.
    final ho = addDimension(doc, e0, e1,
        kind: DimKind.horizontal, offset: 600.5, at: g);
    // Aligned, offset −400.25: 1.5 × √(3000² + 1200²) = 1.5 × 3231.10 =
    // 4846.65; the line 400.25 × 1.5 = 600.375 world mm to the right of
    // both points.
    final al = addDimension(doc, e0, e1, offset: -400.25, at: g);
    expect(
        1.5 * math.sqrt(3000.0 * 3000 + 1200 * 1200), closeTo(4846.65, 0.01));

    void expectScaled(DraftDocument doc, String what) {
      expect(dimText(doc, ho), '4500', reason: what);
      expect(dimText(doc, al), '4847', reason: what);
      expect(lineDistance(doc, ho, w1), closeTo(1.5 * 600.5, 1e-6),
          reason: '$what: horizontal from its outermost point');
      expect(lineDistance(doc, ho, w0), closeTo(1800 + 1.5 * 600.5, 1e-6),
          reason: '$what: horizontal from P0');
      expect(lineDistance(doc, al, w0), closeTo(1.5 * 400.25, 1e-6),
          reason: '$what: aligned from P0');
      expect(lineDistance(doc, al, w1), closeTo(1.5 * 400.25, 1e-6),
          reason: '$what: aligned from P1');
      // The aligned line on the right normal (the sign bit set): c = lo + o
      // = 0 − 600.375, so q0 = P0 − 600.375 n, n the left normal of the
      // line's own direction (P1 − P0's), and (P0 − q0) · n = +600.375.
      final (q0, _) = lineOf(doc, al);
      expect((w0 - q0).dot(lineNormal(doc, al)), closeTo(600.375, 1e-6),
          reason: '$what: the aligned line on the right');
      // A 1:50 page: 2.5 paper mm × 50 = 125 world mm, stored 125 / 1.5 =
      // 83.33.
      for (final h in [ho, al]) {
        final (_, height, _) = dimTextGeometry(doc, h);
        expect(height, closeTo(125, 1e-9), reason: '$what: world height');
        expect(payloadOf(doc, dimTextHandle(doc, h)).scalars[0],
            closeTo(125 / 1.5, 1e-9),
            reason: '$what: stored height');
      }
      expect(lineAngle(doc, ho), closeTo(rad(30), 1e-9), reason: what);
      expectFollows(doc, what);
    }

    expectScaled(doc, 'added');
    // D6's placement function divides by the same scale: a point on each
    // drawn line (its world offset 900.75 and −600.375) gives back the
    // stored offset, 600.5 and −400.25, as the offset grip would store it.
    for (final (h, kind, want) in [
      (ho, DimKind.horizontal, 600.5),
      (al, DimKind.aligned, -400.25),
    ]) {
      final (q0, q1) = lineOf(doc, h);
      expect(offsetFor((q0 + q1) * 0.5, w0, w1, kind, g), closeTo(want, 1e-6),
          reason: 'offsetFor on the $kind line');
    }
    // Through a file, the only way such a group arrives.
    final loaded = reloadWithPage(enc(doc));
    expect(loaded.tree.accumulatedTransform(ho).scaleMagnitude,
        closeTo(1.5, 1e-15));
    expectScaled(loaded, 'loaded');
  });
}
