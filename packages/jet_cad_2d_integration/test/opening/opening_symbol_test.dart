// Ported from jet_cad_floor_plan/test/opening_symbol_test.dart (spec 3a C6, C7):
// OR8 over architectureController in PlanEditor; OG7, OG10 and OR7 run in
// the kit.
// Spec 08 D10-D12: the openings' symbols, through the real ParametricSystem
// (and, for OR8, the shell's select tool). Every wall is at the far origin
// in its own rotated group (`groupAt`), no host is axis-aligned, no opening
// is central, and OR7's openings sit in their own rotated, translated
// groups. Expected symbols come from `support/opening_fixture.dart`'s
// oracles (`OpeningOracle.door`, `OpeningOracle.lines`), which never call
// `opening_geometry.dart`: a frame written out from the host's stored
// parameters and its group's transform, over the oracle's own cut.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_support.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

const hA = Handle(1300);
const hD = Handle(4000), hE = Handle(4050), hW = Handle(4100);
const hG = Handle(4200);

/// World point [q]'s offset along [f]'s left normal.
double offsetOf(OracleFrame f, Vector2 q) =>
    (q.x - f.s.x) * f.n.x + (q.y - f.s.y) * f.n.y;

void main() {
  testWidgets(
      'OR8 (M-08j, M-08j2) gaps on a 250 centre wall at 23° at the far '
      'origin: A (180 < t, m = w/4 = 45) and B (1,100 > t, m = t/4 = 62.5) '
      'each draw one ByLayer LINE on the centreline from x₁ + m to x₂ − m; '
      'a click at A\'s line end selects A; a door added on A\'s start side '
      'gives the piece at A\'s end jamb fresh, higher handles, and the click '
      'still selects A; a window band around A selects it', (tester) async {
    final c = openingController(openingPlanText(
        PageComponent(
            scaleDenominator: 20,
            originX: ox - 3000,
            originY: oy - 2000,
            snapToGrid: false), (doc) {
      doc.commands.execute(
          addWall(doc, hA, plan(-2500, 300), plan(2500, 300), 250, centre));
      // B first, then A, the last cut along the wall.
      doc.commands.execute(addOpening(
          doc, hW, const OpeningParams(hA, 1400, 1100, OpeningKind.gap)));
      doc.commands.execute(addOpening(
          doc, hG, const OpeningParams(hA, 3600, 180, OpeningKind.gap)));
    }));
    final doc = c.document;
    expect(driftOf(doc), isEmpty);

    final f = oracleFrameOf(doc, hA);
    for (final (h, x1, x2, inset) in [
      (hG, 3510.0, 3690.0, 45.0),
      (hW, 850.0, 1950.0, 62.5),
    ]) {
      final why = 'gap ${h.toHex()}';
      final ks = kids(doc, h);
      expect([for (final k in ks) kindOf(doc, k)], [EntityKind.line],
          reason: why);
      expect(doc.entities.colorAt(doc.entities.slotOf(ks.single)!), kByLayer,
          reason: why);
      final [(a, b)] = worldLines(doc, h);
      expect(offsetOf(f, a).abs(), lessThan(1e-6), reason: why);
      expect(offsetOf(f, b).abs(), lessThan(1e-6), reason: why);
      expect(oracleU(f, a), closeTo(x1 + inset, 1e-6), reason: why);
      expect(oracleU(f, b), closeTo(x2 - inset, 1e-6), reason: why);
      expectLinesOnOracle(doc, h, reason: why);
    }

    // The shell, the camera at 0.5 px/mm: the pick aperture is 12 mm in
    // world, under m/2 = 22.5 for A.
    const scale = 0.5;
    expect(kPickRadiusPixels / scale, lessThan(45 / 2));
    final gapEnd = worldLines(doc, hG).single.$2;
    await pumpEditor(tester, c, centre: gapEnd, scale: scale);

    Future<void> clickGapEnd(String when) async {
      await tester.tapAt(globalAt(tester, c, gapEnd));
      await tester.pump();
      // ignore: invalid_use_of_internal_member
      expect(c.selection.keys, [SelectionKey.root(hG)], reason: when);
      await tester.tapAt(globalAt(tester, c, oracleAt(f, 3645, 400)));
      await tester.pump();
      // ignore: invalid_use_of_internal_member
      expect(c.selection.keys, isEmpty, reason: '$when: cleared');
    }

    await clickGapEnd('before the door');

    // A door on A's start side, between B and A: the wall's pieces are
    // rewritten in u order into its regions in handle order, so the end
    // piece, at A's end jamb, is the added one, with fresh handles.
    final lineA = kids(doc, hG).single;
    doc.commands.execute(addOpening(
        doc, hD, const OpeningParams(hA, 2700, 800, OpeningKind.door)));
    await tester.pump();
    expect(driftOf(doc), isEmpty);
    expect(worldPieces(doc, hA), hasLength(4));
    final fills = fillsOf(doc, hA);
    final endFill = [
      for (final k in fills)
        if (nearestIn(worldPieces(doc, hA)[fills.indexOf(k)],
                oracleAt(f, 3690, f.lo)) <
            1e-6)
          k
    ].single;
    expect(endFill, fills.last, reason: 'the piece at A\'s end jamb');
    expect(endFill.value, greaterThan(lineA.value),
        reason: 'its handles are above A\'s line');
    expect(boundaryOf(doc, endFill).value, greaterThan(lineA.value));
    expect(centrelineHandles(doc, hA).last.value, greaterThan(lineA.value));
    await clickGapEnd('after the door');

    // A window band (left to right) around A's line.
    final (a, b) = worldLines(doc, hG).single;
    final lo = Vector2(math.min(a.x, b.x) - 15, math.min(a.y, b.y) - 15);
    final hi = Vector2(math.max(a.x, b.x) + 15, math.max(a.y, b.y) + 15);
    final from = globalAt(tester, c, lo), to = globalAt(tester, c, hi);
    expect(to.dx, greaterThan(from.dx), reason: 'a window band');
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(12, 0));
    await gesture.moveTo(to);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    // ignore: invalid_use_of_internal_member
    expect(c.selection.keys, [SelectionKey.root(hG)]);
  });
}
