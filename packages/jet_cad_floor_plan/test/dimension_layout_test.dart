// Spec 11 D6-D8: a dimension's measuring direction, value, offset and
// children. Every expected point is hand arithmetic in the dimension group's
// local frame, worked beside the assertion; the group sits at the placement
// (and in `DL1`'s coincident pair and `DL4`, turned further), so a hand value
// in the local frame holds at every placement. Ported from the spike's
// `rotate_test.dart` (`Q4d`) and `engine_test.dart` (`Q5e`, `Q5f`).
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/parametric/dimension.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

const r = WallSide.right;

/// Dimension [h]'s LINE children (the dimension line, the extension lines
/// at `a` and `b`, the slashes at `a` and `b`) in its group's local frame:
/// the world points taken back through the group.
List<(Vector2, Vector2)> localLines(DraftDocument doc, Handle h) {
  final inv = doc.tree.accumulatedTransform(h).invert();
  return [
    for (final (p, q) in dimLines(doc, h))
      (inv.transformPoint(p), inv.transformPoint(q)),
  ];
}

/// Dimension [h]'s TEXT insertion point in its group's local frame.
Vector2 localTextAt(DraftDocument doc, Handle h) {
  final (w, _, _) = dimTextGeometry(doc, h);
  return doc.tree.accumulatedTransform(h).invert().transformPoint(w);
}

/// Dimension [h]'s TEXT's stored rotation, radians: its world angle less
/// the group's world rotation.
double storedRotation(DraftDocument doc, Handle h) =>
    payloadOf(doc, dimTextHandle(doc, h)).scalars[1];

void expectAt(Vector2 got, double x, double y, String what,
    {double tol = 1e-6}) {
  expect(got.x, closeTo(x, tol), reason: '$what x');
  expect(got.y, closeTo(y, tol), reason: '$what y');
}

void expectSegment((Vector2, Vector2) got, double x0, double y0, double x1,
    double y1, String what,
    {double tol = 1e-6}) {
  expectAt(got.$1, x0, y0, '$what start', tol: tol);
  expectAt(got.$2, x1, y1, '$what end', tol: tol);
}

/// A document with the floor planner's system and [page] attached.
DraftDocument dimDoc(Placement place, PageComponent page) {
  final doc = buildPlan(const [], place: place).doc;
  attachPage(doc, page);
  return doc;
}

void main() {
  for (final place in placements) {
    test(
        'DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, '
        '1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at '
        '$place', () {
      final doc = dimDoc(place, mmPage);
      final g = place.m;
      const p0 = FixedEnd(0, 0), p1 = FixedEnd(3000, 1200);
      // |(3000, 1200)| = √(3000² + 1200²) = √10,440,000 = 3,231.099...
      final len = math.sqrt(3000.0 * 3000 + 1200 * 1200);
      expect(len, closeTo(3231.1, 0.01));

      // Aligned: u = (3000, 1200) / L, n = (−1200, 3000) / L, h1 = 0 by
      // definition, so c = 0 + 500.25 along n from both points.
      final al = addDimension(doc, p0, p1, offset: 500.25, at: g);
      expect(dimText(doc, al), '3231');
      final k = 500.25 / len;
      final al0 = localLines(doc, al)[0];
      expectSegment(
          al0, -1200 * k, 3000 * k, 3000 - 1200 * k, 1200 + 3000 * k, 'al');

      // Horizontal: u = local x, n = local y, h1 = 1200 = hi, lo = 0: the
      // line at y 1200 + 500.25 = 1700.25.
      final ho = addDimension(doc, p0, p1,
          kind: DimKind.horizontal, offset: 500.25, at: g);
      expect(dimText(doc, ho), '3000');
      expectSegment(
          localLines(doc, ho)[0], 0, 1700.25, 3000, 1700.25, 'horizontal');

      // Vertical: u = local y, n = (−1, 0), h1 = (3000, 1200) · (−1, 0) =
      // −3000, so hi = h0 = 0 and c = 0 + 500.25 along n: the line at x
      // −500.25.
      final ve = addDimension(doc, p0, p1,
          kind: DimKind.vertical, offset: 500.25, at: g);
      expect(dimText(doc, ve), '1200');
      expectSegment(
          localLines(doc, ve)[0], -500.25, 0, -500.25, 1200, 'vertical');

      // A coincident aligned pair in a group turned a further 30° (Task 3's
      // R-noR8): |P1 − P0| = 0 ≤ wallJoin.linear, so u is the group's local
      // x in world, (cos, sin)(place + 30°), not world x. In the local frame
      // n is local y: the extension line at `a` runs from P + 75 n to
      // P + (500.25 + 100) n, and the text reads along local x (stored
      // rotation 0).
      final turned = g.multiply(Transform2.rotation(math.pi / 6));
      final th = (place.deg + 30) * math.pi / 180;
      final pw = turned.transformPoint(Vector2(1234.5, -310.25));
      final u = measuringDirection(DimKind.aligned, pw, pw.clone(), turned);
      expectAt(u, math.cos(th), math.sin(th), 'coincident u', tol: 1e-12);
      final co = addDimension(
          doc, const FixedEnd(1234.5, -310.25), const FixedEnd(1234.5, -310.25),
          offset: 500.25, at: turned);
      expect(kids(doc, co), hasLength(6));
      expect(dimText(doc, co), '0');
      final coLines = localLines(doc, co);
      // The line: both ends at P + 500.25 n.
      expectSegment(coLines[0], 1234.5, -310.25 + 500.25, 1234.5,
          -310.25 + 500.25, 'coincident line');
      expectSegment(coLines[1], 1234.5, -310.25 + 75, 1234.5,
          -310.25 + 500.25 + 100, 'coincident extension a');
      expect(storedRotation(doc, co), closeTo(0, 1e-12));

      // Task 5's review: formatDimension formats a finite value only. Two
      // finite fixed points whose world distance overflows (|x| = 1e200:
      // 2e200 squared is beyond a double) generate nothing, and the edit
      // stands; unguarded, the value Infinity would reach the format, which
      // throws on it.
      expect(() => formatDimension(double.infinity, DisplayUnit.millimeters),
          throwsUnsupportedError);
      final wide = addDimension(
          doc, const FixedEnd(1e200, 0.5), const FixedEnd(-1e200, 0.5),
          offset: 500.25, at: g);
      final wp = doc.components.get<DimensionParams>(wide)!;
      expect((wp.a as FixedEnd).x.isFinite, isTrue);
      expect(
          (g.transformPoint(const FixedEnd(-1e200, 0.5).point) -
                  g.transformPoint(const FixedEnd(1e200, 0.5).point))
              .length
              .isFinite,
          isFalse);
      expect(kids(doc, wide), isEmpty);
      expect(driftOf(doc), isEmpty);
    });
  }

  for (final place in [origin, corpusGroups]) {
    test(
        'DL2 the offset runs from the outermost measured point on the '
        'line\'s side; offsetFor follows the pointer outside the band and '
        'sticks to the nearer extreme inside it, its side the sign bit, at '
        '$place', () {
      // --- Q4d: horizontal, A/0/right (0, −100) to a fixed (5000, −2000),
      // offset −500. n = local y; h0 = 0, h1 = −2000 − (−100) = −1900, so
      // lo = −1900 and, the sign bit set, c = −1900 − 500 = −2400 from P0:
      // the line at y −100 − 2400 = −2500, 2400 below A/0/right and 500
      // below the fixed point.
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      final g = place.m;
      final q4d = addDimension(
          doc, AttachedEnd(a, 0, r), const FixedEnd(5000, -2000),
          kind: DimKind.horizontal, offset: -500, at: g);
      expect(dimText(doc, q4d), '5000');
      expectSegment(localLines(doc, q4d)[0], 0, -2500, 5000, -2500, 'Q4d');
      // A thickened to 4400: its right face, and so P0, at y −2200, below
      // the fixed point. h1 = −2000 − (−2200) = +200, lo = h0 = 0, c = 0 −
      // 500: the line at −2700, 500 below the face and 700 below the fixed
      // point.
      doc.commands.execute(SetComponentCommand<WallParams>(
          a, doc.components.get<WallParams>(a)!.copyWith(thickness: 4400)));
      expectSegment(localLines(doc, q4d)[0], 0, -2700, 5000, -2700, 'Q4d 4400');
      expect(driftOf(doc), isEmpty);

      // --- offsetFor, horizontal on (0, 0)-(3000, 1200): h0 = 0, h1 =
      // 1200, so lo = 0 and hi = 1200.
      final dim = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
          kind: DimKind.horizontal, offset: 7.5, at: g);
      final w0 = g.transformPoint(Vector2(0, 0));
      final w1 = g.transformPoint(Vector2(3000, 1200));
      double at(double y) => offsetFor(
          g.transformPoint(Vector2(1500.5, y)), w0, w1, DimKind.horizontal, g);
      void store(double offset) =>
          doc.commands.execute(SetComponentCommand<DimensionParams>(
              dim,
              doc.components
                  .get<DimensionParams>(dim)!
                  .copyWith(offset: offset)));

      // y 2000 ≥ hi: 2000 − 1200 = +800, the line at 2000.
      final above = at(2000);
      expect(above, closeTo(800, 1e-6));
      store(above);
      expectSegment(localLines(doc, dim)[0], 0, 2000, 3000, 2000, 'y 2000');

      // y −300 ≤ lo: −(0 − (−300)) = −300, the line at −300; σ = −1, so the
      // extension lines run down: at a from (0, −75) to (0, −400), at b from
      // (3000, 1200 − 75) to (3000, −400).
      final below = at(-300);
      expect(below, closeTo(-300, 1e-6));
      store(below);
      final bl = localLines(doc, dim);
      expectSegment(bl[0], 0, -300, 3000, -300, 'y -300');
      expectSegment(bl[1], 0, -75, 0, -400, 'y -300 extension a');
      expectSegment(bl[2], 3000, 1125, 3000, -400, 'y -300 extension b');

      // y 900, between: hi − hq = 300 ≤ hq − lo = 900, the upper extreme:
      // +0.0, the line at 1200. Its extension at b starts on P1 itself
      // (min(75, |1200 − 1200|) = 0) and runs to (3000, 1300).
      final upper = at(900);
      expect(upper, 0.0);
      expect(upper.isNegative, isFalse);
      store(upper);
      final ul = localLines(doc, dim);
      expectSegment(ul[0], 0, 1200, 3000, 1200, 'y 900');
      expectSegment(ul[1], 0, 75, 0, 1300, 'y 900 extension a');
      expectSegment(ul[2], 3000, 1200, 3000, 1300, 'y 900 extension b');

      // y 400, between: hi − hq = 800 > hq − lo = 400, the lower extreme:
      // -0.0, the line at 0; σ = −1, so the extension at a starts on P0 and
      // runs down to (0, −100).
      final lower = at(400);
      expect(lower, 0.0);
      expect(lower.isNegative, isTrue);
      store(lower);
      expect(
          doc.components.get<DimensionParams>(dim)!.offset.isNegative, isTrue);
      final ll = localLines(doc, dim);
      expectSegment(ll[0], 0, 0, 3000, 0, 'y 400');
      expectSegment(ll[1], 0, 0, 0, -100, 'y 400 extension a');
      expect(driftOf(doc), isEmpty);
    });
  }

  test(
      'DL2b offsetFor\'s boundaries: a point on the upper extreme is +0.0, '
      'and the middle of the between band is +0.0, at the origin and at '
      'corpusAxis', () {
    // Task 6's review (Minor 1). Where the arithmetic is exact: the origin,
    // and the corpus far origin unturned (4,500,000 + 600 − 4,500,000 is
    // 600 exactly, as are 1,200 and 3,000 there).
    for (final place in [origin, corpusAxis]) {
      final g = place.m;
      final w0 = g.transformPoint(Vector2(0, 0));
      final w1 = g.transformPoint(Vector2(3000, 1200));
      // Aligned, q = P0: hq = 0 = hi = lo (h1 = 0 by definition). Case 1
      // (hq ≥ hi) takes it first: (0 − 0) / 1 = +0.0, not case 2's −0.0.
      final onP0 = offsetFor(w0, w0, w1, DimKind.aligned, g);
      expect(onP0, 0.0, reason: '$place');
      expect(onP0.isNegative, isFalse, reason: 'on P0 at $place');
      // Horizontal, the band lo = 0, hi = 1200, q at y 600: hi − hq = 600 ≤
      // hq − lo = 600, a tie, which goes to the upper extreme: +0.0.
      final q = g.transformPoint(Vector2(1500.5, 600));
      // The premise: the heights are exact here.
      expect((q - w0).y, 600, reason: '$place');
      expect((w1 - w0).y, 1200, reason: '$place');
      final mid = offsetFor(q, w0, w1, DimKind.horizontal, g);
      expect(mid, 0.0, reason: '$place');
      expect(mid.isNegative, isFalse, reason: 'mid-band at $place');
    }
  });

  for (final place in [origin, corpusGroups]) {
    test(
        'DL3 the children by hand at 1:50 and 1:100, and a pair drawn '
        'right to left reads upright with its text above the line, at '
        '$place', () {
      final doc = dimDoc(place, mmPage);
      final g = place.m;
      final dim = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(4000, 0),
          kind: DimKind.horizontal, offset: 600, at: g);
      // At 1:50: g = 1.5 × 50 = 75, v = 2 × 50 = 100, slash 3 × 50 = 150,
      // text 2.5 × 50 = 125 above the line by 1 × 50 = 50. u = (1, 0) = ur,
      // n = nr = (0, 1), t = (1, 1) / √2 × 75 = (53.033, 53.033).
      final t50 = 75 / math.sqrt(2);
      expect(t50, closeTo(53.033, 1e-3));
      var ls = localLines(doc, dim);
      expect(ls, hasLength(5));
      expectSegment(ls[0], 0, 600, 4000, 600, '1:50 line');
      expectSegment(ls[1], 0, 75, 0, 700, '1:50 extension a');
      expectSegment(ls[2], 4000, 75, 4000, 700, '1:50 extension b');
      expectSegment(ls[3], -t50, 600 - t50, t50, 600 + t50, '1:50 slash a');
      expectSegment(
          ls[4], 4000 - t50, 600 - t50, 4000 + t50, 600 + t50, '1:50 slash b');
      expectAt(localTextAt(doc, dim), 2000, 650, '1:50 text');
      final (_, height, angle) = dimTextGeometry(doc, dim);
      expect(height, closeTo(125, 1e-9));
      // Stored rotation 0 in the local frame; in world the group's own
      // rotation, the placement's.
      expect(storedRotation(doc, dim), closeTo(0, 1e-12));
      expect(angle, closeTo(place.deg * math.pi / 180, 1e-12));
      expect(dimText(doc, dim), '4000');

      // At 1:100 in feet-inches: g 150, v 200, the slash ±300 / 2 / √2 =
      // ±106.066, the text 100 above at (2000, 700), height 250. 4000 mm =
      // 4000 / 6.35 = 629.92 quarters of an inch → 630 = 13 × 48 + 6:
      // 13'-1 1/2".
      attachPage(
          doc,
          PageComponent().copyWith(
              scaleDenominator: 100, displayUnit: DisplayUnit.feetInches));
      final t100 = 150 / math.sqrt(2);
      expect(t100, closeTo(106.066, 1e-3));
      ls = localLines(doc, dim);
      expectSegment(ls[0], 0, 600, 4000, 600, '1:100 line');
      expectSegment(ls[1], 0, 150, 0, 800, '1:100 extension a');
      expectSegment(ls[2], 4000, 150, 4000, 800, '1:100 extension b');
      expectSegment(
          ls[3], -t100, 600 - t100, t100, 600 + t100, '1:100 slash a');
      expectAt(localTextAt(doc, dim), 2000, 700, '1:100 text');
      final (_, height100, _) = dimTextGeometry(doc, dim);
      expect(height100, closeTo(250, 1e-9));
      expect(dimText(doc, dim), "13'-1 1/2\"");

      // Right to left, aligned: (4000, 0) → (0, 0), offset 600. u = (−1, 0),
      // n = (0, −1): the line at y −600. readable flips u: ur = (1, 0), nr =
      // (0, 1), so the text is above the line at (2000, −600 + 100) at
      // 1:100 (−550 at 1:50), angle 0.
      attachPage(doc, mmPage);
      final rl = addDimension(
          doc, const FixedEnd(4000, 0), const FixedEnd(0, 0),
          offset: 600, at: g);
      final rls = localLines(doc, rl);
      expectSegment(rls[0], 4000, -600, 0, -600, 'right to left line');
      // The extension lines run down (σ = +1 along n = (0, −1)).
      expectSegment(rls[1], 4000, -75, 4000, -700, 'right to left extension');
      // The slash still rises to the right along ur: Q ∓ (53.033, 53.033).
      expectSegment(rls[3], 4000 - t50, -600 - t50, 4000 + t50, -600 + t50,
          'right to left slash a');
      expectAt(localTextAt(doc, rl), 2000, -550, 'right to left text');
      expect(storedRotation(doc, rl), closeTo(0, 1e-12));
      expect(dimText(doc, rl), '4000');
      expect(driftOf(doc), isEmpty);
    });
  }

  test(
      'DL4 readable reverses a direction that would read from the top '
      'or the left, reads exactly vertical upwards, and a vertical dimension '
      'in a group turned −90° reads +90°', () {
    double deg(Vector2 u) {
      final v = readable(u);
      return math.atan2(v.y, v.x) * 180 / math.pi;
    }

    Vector2 dir(double d) =>
        Vector2(math.cos(d * math.pi / 180), math.sin(d * math.pi / 180));
    // Q5e's table.
    expect(deg(dir(0)), closeTo(0, 1e-9));
    expect(deg(dir(45)), closeTo(45, 1e-9));
    expect(deg(dir(135)), closeTo(-45, 1e-9));
    expect(deg(dir(180)), closeTo(0, 1e-9));
    expect(deg(dir(-45)), closeTo(-45, 1e-9));
    expect(deg(dir(-135)), closeTo(45, 1e-9));
    // Exactly vertical, both ways: +90° (reads from the right).
    expect(deg(Vector2(0, 1)), 90);
    expect(deg(Vector2(0, -1)), 90);
    // Within dimFormat.angular (1e-9) of vertical, either side: +90°.
    expect(deg(Vector2(1e-12, -1)), closeTo(90, 1e-9));
    expect(deg(Vector2(-1e-12, 1)), closeTo(90, 1e-9));
    // Beyond it, the side decides: atan2(−1, 1e-6) = −90° + 5.7e-5°.
    expect(deg(Vector2(1e-6, -1).normalized()), closeTo(-90 + 5.7e-5, 1e-6));

    // Q5f: fixed (0, 0) and (2000, 0) in a group turned −90°. Horizontal
    // at the corpus far origin: u = the group's local x in world = (cos,
    // sin)(−90°) = (6.1e-17, −1), which without the tolerance would not
    // flip and would read from the left (−90°). Aligned at the world origin
    // (the spike's case): P1 − P0 = (1.2e-13, −2000), the same u.
    for (final (at, kind) in [
      (
        Transform2.translation(4500000, 1200000)
            .multiply(Transform2.rotation(-math.pi / 2)),
        DimKind.horizontal
      ),
      (Transform2.rotation(-math.pi / 2), DimKind.aligned),
    ]) {
      final doc = dimDoc(origin, mmPage);
      final w0 = at.transformPoint(Vector2(0, 0));
      final w1 = at.transformPoint(Vector2(2000, 0));
      final u = measuringDirection(kind, w0, w1, at);
      // The premise: u.x is positive and inside the tolerance.
      expect(u.x, greaterThan(0), reason: '$kind');
      expect(u.x, lessThan(1e-16), reason: '$kind');
      expect(u.y, -1, reason: '$kind');
      final dim = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(2000, 0),
          kind: kind, offset: 200.5, at: at);
      final (_, _, ang) = dimTextGeometry(doc, dim);
      expect(ang * 180 / math.pi, closeTo(90, 1e-9), reason: '$kind');
      expect(dimText(doc, dim), '2000');
    }
  });

  for (final place in [origin, corpusGroups]) {
    test(
        'DL5 a coincident aligned pair and a vertical pair measured '
        'horizontally still draw six children, read 0, and report '
        'dimension.degenerate, at $place', () {
      final doc = dimDoc(place, mmPage);
      // The dimensions' group at the placement, turned a further 37°: every
      // expected point below is in its local frame.
      final g = place.m.multiply(Transform2.rotation(37 * math.pi / 180));
      // At 1:50: g = 75, v = 100, the slash ±75 / √2 = ±53.033 along (1, 1),
      // the text 50 above the line.
      final t = 75 / math.sqrt(2);

      // Coincident, aligned: |P1 − P0| = 0, so u is the group's local x
      // (R-8), n its local y; h0 = h1 = 0 and c = 400.5: Q0 = Q1 = (1234.5,
      // −310.25 + 400.5) = (1234.5, 90.25), the dimension line zero long.
      final co = addDimension(
          doc, const FixedEnd(1234.5, -310.25), const FixedEnd(1234.5, -310.25),
          offset: 400.5, at: g);
      expect(kindsOf(doc, co), [
        EntityKind.line,
        EntityKind.line,
        EntityKind.line,
        EntityKind.line,
        EntityKind.line,
        EntityKind.text,
      ]);
      expect(dimText(doc, co), '0');
      final cl = localLines(doc, co);
      expectSegment(cl[0], 1234.5, 90.25, 1234.5, 90.25, 'coincident line');
      expectSegment(cl[1], 1234.5, -310.25 + 75, 1234.5, 90.25 + 100,
          'coincident extension a');
      expectSegment(cl[2], 1234.5, -310.25 + 75, 1234.5, 90.25 + 100,
          'coincident extension b');
      expectSegment(cl[3], 1234.5 - t, 90.25 - t, 1234.5 + t, 90.25 + t,
          'coincident slash a');
      expectSegment(cl[4], 1234.5 - t, 90.25 - t, 1234.5 + t, 90.25 + t,
          'coincident slash b');
      expectAt(localTextAt(doc, co), 1234.5, 90.25 + 50, 'coincident text');
      expect(storedRotation(doc, co), closeTo(0, 1e-12));

      // A vertical pair measured horizontally: u = local x, n = local y; h1 =
      // 3000 = hi, so c = 3000 + 400.5 = 3400.5: Q0 = (0, 3400.5) and Q1 =
      // (0, 3000) + (0, 400.5), the same point. The component along u is 0.
      final vh = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(0, 3000),
          kind: DimKind.horizontal, offset: 400.5, at: g);
      expect(kids(doc, vh), hasLength(6));
      expect(dimText(doc, vh), '0');
      final vl = localLines(doc, vh);
      expectSegment(vl[0], 0, 3400.5, 0, 3400.5, 'vertical pair line');
      expectSegment(vl[1], 0, 75, 0, 3500.5, 'vertical pair extension a');
      expectSegment(vl[2], 0, 3075, 0, 3500.5, 'vertical pair extension b');
      expectSegment(
          vl[3], -t, 3400.5 - t, t, 3400.5 + t, 'vertical pair slash a');
      expectSegment(
          vl[4], -t, 3400.5 - t, t, 3400.5 + t, 'vertical pair slash b');
      expectAt(localTextAt(doc, vh), 0, 3450.5, 'vertical pair text');

      // One warning each, in ascending handle order (D15).
      expect(codedAs(diagnosticsOf(doc), 'dimension.'), [
        for (final h in [co, vh])
          Diagnostic(
            severity: DiagnosticSeverity.warning,
            code: 'dimension.degenerate',
            message: '${h.toHex()} measures zero',
            handles: [h],
          ),
      ]);
      expect(driftOf(doc), isEmpty);
    });
  }
}
