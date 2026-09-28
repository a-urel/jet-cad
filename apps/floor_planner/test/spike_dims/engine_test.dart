// SPIKE 11 -- throwaway. Q5: the dimension type on the real
// ParametricSystem: its children, the page-scaled text, decision 7's
// half-up rounding against binary floating point, decision 8's flip.
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

const l = WallSide.left;

void main() {
  test('Q5a children, records, page-scaled text; a page change is one step',
      () {
    final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: corpusGroups);
    final doc = plan.doc;
    attachPage(
        doc, PageComponent().copyWith(displayUnit: DisplayUnit.millimeters));
    final [a] = plan.walls;
    final dim = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
        offset: 600);
    final ks = kids(doc, dim);
    expect([for (final k in ks) kindOf(doc, k).name],
        ['line', 'line', 'line', 'line', 'line', 'text']);
    for (final k in ks.take(5)) {
      expect(recordOf(doc, k).lineweight, kDimLineweight);
    }
    final text = recordOf(doc, ks.last);
    expect(text.text, '4000');
    expect(text.textAttrs, kDimTextAttrs);
    // 2.5 paper mm at 1:50: 125 model mm.
    expect(dimTextGeometry(doc, dim).$2, closeTo(125, 1e-9));
    // The text sits 1 paper mm (50 mm) above the line's middle: the line at
    // y = 100 + 600 = 700, from x 0 to 4000; the text at (2000, 750).
    expect((dimTextGeometry(doc, dim).$1 - plan.at(2000, 750)).length,
        lessThan(1e-6));
    final depth = doc.commands.undoDepth;
    // 1:50 m -> 1:100 ft-in, one command: 4000 mm = 157.48" = 13'-1.48",
    // nearest 1/4": 157.5" = 13'-1 1/2".
    final page = pageOf(doc);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        page.copyWith(
            scaleDenominator: 100, displayUnit: DisplayUnit.feetInches)));
    expect(doc.commands.undoDepth, depth + 1);
    expect(dimText(doc, dim), "13'-1 1/2\"");
    expect(dimTextGeometry(doc, dim).$2, closeTo(250, 1e-9));
    expect(kids(doc, dim), ks);
    expect(driftOf(doc), isEmpty);
    doc.commands.undo();
    expect(dimText(doc, dim), '4000');
    expect(dimTextGeometry(doc, dim).$2, closeTo(125, 1e-9));
  });

  test('Q5b decision 7: the format table', () {
    final cases = <(double, DisplayUnit, String)>[
      (3450, DisplayUnit.millimeters, '3450'),
      (3450.5, DisplayUnit.millimeters, '3451'),
      (3450.4, DisplayUnit.millimeters, '3450'),
      (3450, DisplayUnit.centimeters, '345.0'),
      (3456, DisplayUnit.centimeters, '345.6'),
      (3450, DisplayUnit.meters, '3.45'),
      (3455, DisplayUnit.meters, '3.46'),
      (3454.9, DisplayUnit.meters, '3.45'),
      (1005, DisplayUnit.meters, '1.01'),
      // 136 3/8" = 136.375 × 25.4 = 3463.925 mm.
      (3463.925, DisplayUnit.inches, '136 3/8'),
      // 136 1/2" = 3467.1 mm: 4/8 reduced to 1/2.
      (3467.1, DisplayUnit.inches, '136 1/2'),
      // 11'-4 1/4" = 136.25" = 3460.75 mm.
      (3460.75, DisplayUnit.feetInches, "11'-4 1/4\""),
      (3657.6, DisplayUnit.feetInches, "12'-0\""),
      // 3/16" = 4.7625 mm: half of an eighth, up to 1/4.
      (3 * 25.4 / 16, DisplayUnit.inches, '0 1/4'),
      // 3/8" = 9.525 mm: half of a quarter, up to 1/2.
      (3 * 25.4 / 8, DisplayUnit.feetInches, "0'-0 1/2\""),
    ];
    for (final (mm, unit, want) in cases) {
      expect(formatDimension(mm, unit), want, reason: '$mm mm in $unit');
    }
  });

  test(
      'Q5c half-up at an exact .5 despite binary floating point: where the '
      'naive rule goes wrong', () {
    final lines = <String>[];
    void row(String what, double mm, double unitMm, int per, double quantum,
        int want) {
      final naive = naiveRound(mm, unitMm, per);
      final ours = roundHalfUp(mm, quantum);
      lines.add('$what: $mm mm -> naive $naive, half-up $ours, want $want');
      expect(ours, want, reason: what);
    }

    // 1005 mm in metres to 0.01: 1.005 × 100 = 100.49999999999999.
    row('1005 mm in m', 1005, 1000, 100, 10, 101);
    // 3/16" (4.7625 mm, stored 4.762499999999999) in eighths.
    row('3/16"', 3 * 25.4 / 16, 25.4, 8, 25.4 / 8, 2);
    // 3/8" in quarters (feet-inches).
    row('3/8"', 3 * 25.4 / 8, 25.4, 4, 25.4 / 4, 2);
    // A 3-4-5 aligned dimension: legs 18.9 and 25.2, true length 31.5.
    final h = math.sqrt(18.9 * 18.9 + 25.2 * 25.2);
    row('hypot(18.9, 25.2)', h, 1, 1, 1, 32);
    // The same at the corpus far origin: (4,500,000 + 0.3) - 4,500,000 and
    // 0.4, true length 0.5.
    const ox = 4500000.0;
    final dx = (ox + 0.3) - ox;
    row('far-origin hypot(0.3, 0.4)', math.sqrt(dx * dx + 0.16), 1, 1, 1, 1);
    // Not over-reaching: 2e-6 below a half is below it.
    row('3450.5 - 2e-6', 3450.5 - 2e-6, 1, 1, 1, 3450);
    // ignore: avoid_print
    print('Q5c\n  ${lines.join('\n  ')}');
  });

  test('Q5d a .5 value through the real object, turned and far', () {
    for (final place in [origin, corpusGroups, km1000Groups]) {
      // A free wall 3450.5 long: A/0/left -> A/1/left is 3450.5.
      final plan = buildPlan(const [W(0, 0, 3450.5, 0, 200)], place: place);
      final doc = plan.doc;
      attachPage(
          doc, PageComponent().copyWith(displayUnit: DisplayUnit.millimeters));
      final [a] = plan.walls;
      final dim = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
          offset: 300);
      final p0 = oracleEnd(doc, dim, AttachedEnd(a, 0, l));
      final p1 = oracleEnd(doc, dim, AttachedEnd(a, 1, l));
      final v = (p1 - p0).length;
      // ignore: avoid_print
      print('Q5d $place: measured $v, naive ${v.round()}, text '
          '${dimText(doc, dim)}');
      expect(dimText(doc, dim), '3451');
    }
  });

  test('Q5e decision 8: readable, with the flip at exactly vertical', () {
    double deg(Vector2 u) {
      final r = readable(u);
      return math.atan2(r.y, r.x) * 180 / math.pi;
    }

    Vector2 dir(double d) =>
        Vector2(math.cos(d * math.pi / 180), math.sin(d * math.pi / 180));
    expect(deg(dir(0)), closeTo(0, 1e-9));
    expect(deg(dir(45)), closeTo(45, 1e-9));
    expect(deg(dir(135)), closeTo(-45, 1e-9));
    expect(deg(dir(180)), closeTo(0, 1e-9));
    expect(deg(dir(-45)), closeTo(-45, 1e-9));
    expect(deg(dir(-135)), closeTo(45, 1e-9));
    // Exactly vertical, both ways: +90° (reads from the right).
    expect(deg(Vector2(0, 1)), 90);
    expect(deg(Vector2(0, -1)), 90);
    // Within the tolerance of vertical, either side: +90°-ish, never -90°.
    expect(deg(Vector2(1e-12, -1)), closeTo(90, 1e-9));
    expect(deg(Vector2(-1e-12, 1)), closeTo(90, 1e-9));
    // What a group turned by -90° gives: cos(-π/2) = 6.1e-17.
    final t =
        Transform2.rotation(-math.pi / 2).transformDirection(Vector2(1, 0));
    expect(t.x, greaterThan(0));
    expect(deg(t), closeTo(90, 1e-9));
    // Beyond the tolerance, the side decides.
    expect(deg(Vector2(1e-6, -1).normalized()), closeTo(-90 + 5.7e-5, 1e-6));
  });

  test(
      'Q5f the object: a vertical dimension in a group turned -90° reads '
      'from the right', () {
    final plan = buildPlan(const [], place: corpus);
    final doc = plan.doc;
    attachPage(
        doc, PageComponent().copyWith(displayUnit: DisplayUnit.millimeters));
    // A group turned by -90° at the world origin: local x runs world down,
    // (cos(-π/2), sin(-π/2)) = (6.1e-17, -1). Fixed points 0 and 2000 along
    // local x: the line runs straight down, and without the tolerance on
    // "exactly vertical" (u.x = +6.1e-17 > 0) it would not flip and would
    // read from the left (-90°).
    final g0 = Transform2.rotation(-math.pi / 2);
    final dim = addDimension(doc, const FixedEnd(0, 0), const FixedEnd(2000, 0),
        offset: 200, at: g0);
    final (_, _, ang) = dimTextGeometry(doc, dim);
    expect(ang * 180 / math.pi, closeTo(90, 1e-9));
    expect(dimText(doc, dim), '2000');
  });
}
