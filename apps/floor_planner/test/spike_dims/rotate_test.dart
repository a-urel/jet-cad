// SPIKE 11 -- throwaway. Q4: the stored representation under move, rotate
// by a non-axis angle and a far origin: fixed ends in the group's local
// space, attached ends from their walls, a linear axis in the group's local
// frame, the offset from the outermost measured point.
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

const l = WallSide.left, r = WallSide.right;

PageComponent get mmPage =>
    PageComponent().copyWith(displayUnit: DisplayUnit.millimeters);

/// Rotation by [deg] about world [pivot].
Transform2 rotAbout(Vector2 pivot, double deg) =>
    Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(deg * math.pi / 180))
        .multiply(Transform2.translation(-pivot.x, -pivot.y));

/// Every group of [hs] transformed by [t], one compound (the select tool's
/// move/rotate: `t · node.transform`).
void transformAll(DraftDocument doc, List<Handle> hs, Transform2 t) =>
    doc.commands.execute(CompoundCommand([
      for (final h in hs)
        TransformNodeCommand(h, t.multiply(doc.tree[h]!.transform)),
    ], label: 'Rotate'));

/// The perpendicular distance from world [p] to dimension [h]'s stored
/// dimension line.
double lineDistance(DraftDocument doc, Handle h, Vector2 p) {
  final (a, b) = dimLines(doc, h).first;
  final d = (b - a).normalized();
  final w = p - a;
  return (w.x * d.y - w.y * d.x).abs();
}

void main() {
  for (final place in [origin, corpus, km1000Groups]) {
    test(
        'Q4a a fixed-fixed horizontal dimension rotated 30°: local axes '
        'keep 3000, $place', () {
      final plan = buildPlan(const [], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      // Two fixed points (0, 0) and (3000, 1200) in a group at the
      // placement: horizontal 3000, aligned sqrt(3000² + 1200²) = 3231.1.
      final g = place.m;
      final h = addDimension(
          doc, fixedAt(plan.at(0, 0), g), fixedAt(plan.at(3000, 1200), g),
          kind: DimKind.horizontal, offset: -500, at: g);
      final al = addDimension(
          doc, fixedAt(plan.at(0, 0), g), fixedAt(plan.at(3000, 1200), g),
          offset: 400, at: g);
      expect([dimText(doc, h), dimText(doc, al)], ['3000', '3231']);
      expect(math.sqrt(3000 * 3000 + 1200 * 1200), closeTo(3231.099, 1e-3));
      // Rotated 30° about a far pivot, the dimension alone (both ends
      // fixed, so both move). Local axes: still 3000, the line now at
      // place.deg + 30°. World axes would read the rotated vector's x:
      // 3000 cos 30° - 1200 sin 30° = 2598.08 - 600 = 1998.08 (only at a
      // placement turned 0°; see the note).
      transformAll(doc, [h, al], rotAbout(plan.at(-7000, 2500), 30));
      expect([dimText(doc, h), dimText(doc, al)], ['3000', '3231']);
      final (a, b) = dimLines(doc, h).first;
      final ang = math.atan2(b.y - a.y, b.x - a.x) * 180 / math.pi;
      expect(ang, closeTo(place.deg + 30, 1e-9));
      final (_, _, textAngle) = dimTextGeometry(doc, h);
      expect(textAngle * 180 / math.pi, closeTo(place.deg + 30, 1e-9));
      expect(driftOf(doc), isEmpty);
      // ignore: avoid_print
      print('Q4a $place: after 30°: horizontal ${dimText(doc, h)}, aligned '
          '${dimText(doc, al)}, line at ${ang.toStringAsFixed(9)} deg; world '
          'axes would give ${(3000 * math.cos(math.pi / 6) - 1200 * math.sin(math.pi / 6)).toStringAsFixed(2)} at 0 deg');
    });
  }

  for (final place in [origin, corpus, km1000Groups]) {
    test(
        'Q4b one attached end, one fixed: a move and a 37° rotation of the '
        'dimension alone, $place', () {
      final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a] = plan.walls;
      // A/1/left = (4000, 100); fixed (4000, 3100): 3000, vertical.
      final g = place.m;
      final dim = addDimension(
          doc, AttachedEnd(a, 1, l), fixedAt(plan.at(4000, 3100), g),
          offset: 600, at: g);
      expect(dimText(doc, dim), '3000');
      // Moved (700, 0) in plan: the fixed end to (4700, 3100), the
      // attached end pinned: sqrt(700² + 3000²) = 3080.584.
      final mv = plan.at(700, 0) - plan.at(0, 0);
      transformAll(doc, [dim], Transform2.translation(mv.x, mv.y));
      expect(dimText(doc, dim), '3081');
      expect(math.sqrt(700 * 700 + 3000 * 3000), closeTo(3080.584, 1e-3));
      // Rotated 37° about plan (0, 0): the fixed end (4700, 3100) goes to
      // (4700 c - 3100 s, 4700 s + 3100 c), c = cos 37° = 0.798636,
      // s = sin 37° = 0.601815: (3753.59 - 1865.63, 2828.53 + 2475.77) =
      // (1887.96, 5304.30); from (4000, 100): dx -2112.04, dy 5204.30,
      // length sqrt(4,460,713 + 27,084,748) = sqrt(31,545,461) = 5616.53.
      transformAll(doc, [dim], rotAbout(plan.at(0, 0), 37));
      const c = 0.7986355100472928, s = 0.6018150231520483;
      final fx = 4700 * c - 3100 * s, fy = 4700 * s + 3100 * c;
      final len = math.sqrt(math.pow(fx - 4000, 2) + math.pow(fy - 100, 2));
      expect(len, closeTo(5616.53, 0.01));
      expect(dimText(doc, dim), '5617');
      // The attached end never moved: the dimension line's start is still
      // 600 (+ the outermost rule) from A/1/left along the normal.
      final p0 = oracleEnd(doc, dim, AttachedEnd(a, 1, l));
      expect((p0 - plan.at(4000, 100)).length, lessThan(1e-6));
      expect(driftOf(doc), isEmpty);
    });
  }

  test(
      'Q4c walls and dimensions rotated together by 30°: every value '
      'unchanged, far origin', () {
    final plan = buildPlan(
        const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
        place: corpusGroups);
    final doc = plan.doc;
    attachPage(doc, mmPage);
    final [a, b] = plan.walls;
    // The outer faces: horizontal A/0/right (0, -100) -> B/0/right
    // (4100, -100): 4100; vertical B/0/right -> B/1/right (4100, 3000):
    // 3100; aligned from the inner corner A/1/left (3900, 100) to a fixed
    // point (1000, 2500): sqrt(2900² + 2400²) = 3764.306.
    final g = plan.place.m;
    final hd = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(b, 0, r),
        kind: DimKind.horizontal, offset: -800, at: g);
    final vd = addDimension(doc, AttachedEnd(b, 0, r), AttachedEnd(b, 1, r),
        kind: DimKind.vertical, offset: 700, at: g);
    final ad = addDimension(
        doc, AttachedEnd(a, 1, l), fixedAt(plan.at(1000, 2500), g),
        offset: 300, at: g);
    final want = ['4100', '3100', '3764'];
    expect([
      for (final h in [hd, vd, ad]) dimText(doc, h)
    ], want);
    expect(math.sqrt(2900 * 2900 + 2400 * 2400), closeTo(3764.306, 1e-3));
    final dBefore = lineDistance(doc, hd, plan.at(0, -100));
    transformAll(doc, [a, b, hd, vd, ad], rotAbout(plan.at(9000, -4000), 30));
    expect([
      for (final h in [hd, vd, ad]) dimText(doc, h)
    ], want);
    // The offset follows: the horizontal line is still 800 from A/0/right.
    final p = oracleEnd(doc, hd, AttachedEnd(a, 0, r));
    expect(dBefore, closeTo(800, 1e-6));
    expect(lineDistance(doc, hd, p), closeTo(800, 1e-6));
    expect(driftOf(doc), isEmpty);
  });

  test(
      'Q4d the offset is kept from the outermost measured point when a '
      'wall changes', () {
    final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: corpus);
    final doc = plan.doc;
    attachPage(doc, mmPage);
    final [a] = plan.walls;
    final g = plan.place.m;
    // Horizontal, A/0/right (0, -100) to a fixed point (5000, -2000),
    // offset -500: the line at min(-100, -2000) - 500 = -2500, 2400 below
    // A/0/right and 500 below the fixed point.
    final dim = addDimension(
        doc, AttachedEnd(a, 0, r), fixedAt(plan.at(5000, -2000), g),
        kind: DimKind.horizontal, offset: -500, at: g);
    expect(dimText(doc, dim), '5000');
    expect(lineDistance(doc, dim, plan.at(0, -100)), closeTo(2400, 1e-6));
    expect(lineDistance(doc, dim, plan.at(5000, -2000)), closeTo(500, 1e-6));
    // A 4400 thick: its right face y = -2200, below the fixed point: the
    // line follows it, at -2200 - 500 = -2700.
    doc.commands.execute(SetComponentCommand<WallParams>(
        a, doc.components.get<WallParams>(a)!.copyWith(thickness: 4400)));
    expect(lineDistance(doc, dim, plan.at(0, -2200)), closeTo(500, 1e-6));
    expect(lineDistance(doc, dim, plan.at(5000, -2000)), closeTo(700, 1e-6));
    expect(driftOf(doc), isEmpty);
  });

  test(
      'Q4e a horizontal dimension with both ends attached, rotated alone '
      'by 30°: the axis turns, the ends stay', () {
    final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: corpus);
    final doc = plan.doc;
    attachPage(doc, mmPage);
    final [a] = plan.walls;
    final g = plan.place.m;
    final dim = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
        kind: DimKind.horizontal, offset: -600, at: g);
    expect(dimText(doc, dim), '4000');
    transformAll(doc, [dim], rotAbout(plan.at(2000, 0), 30));
    // The ends are (0, -100) and (4000, -100); the axis is now at 30° to
    // the wall: 4000 cos 30° = 3464.10.
    expect(dimText(doc, dim), '3464');
    expect(4000 * math.cos(math.pi / 6), closeTo(3464.10, 0.01));
    expect(driftOf(doc), isEmpty);
  });
}
