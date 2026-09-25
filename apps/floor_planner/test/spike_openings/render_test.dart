// SPIKE 08 -- throwaway. Q4 (draw order), Q5 (symbols) and Q6 (selection):
// real renders of the floor planner shell, dumped as PNG, and picks through
// the engine's SpatialIndex and the render layer's resolveHit.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import 'support.dart';

const hA = Handle(1300), hB = Handle(2600), hC = Handle(3000);

DraftDocument sceneDoc(void Function(DraftDocument doc) build, int background) {
  final m = FlutterTextMeasurer();
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: ox - 4000,
          originY: oy - 3000,
          background: background,
          snapToGrid: false)));
  final sys = installParametric(doc);
  build(doc);
  expect(ParametricSystem(doc, parametricCatalog).drift(), isEmpty);
  sys.dispose();
  doc.commands.clearHistory();
  return doc;
}

Future<void> snap(WidgetTester tester, String name, DraftDocument doc,
    Vector2 centre, double pxPerMm) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final capture = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
      key: capture, child: MaterialApp(home: PlannerShell(document: doc))));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.scale(pxPerMm, pxPerMm);
  final mid = linear.transformPoint(centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  final boundary =
      capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png!;
  }))!;
  Directory('build/spike_openings').createSync(recursive: true);
  File('build/spike_openings/$name.png')
      .writeAsBytesSync(bytes.buffer.asUint8List());
  await tester.pumpWidget(const SizedBox());
}

/// The L of 07 with a door and a window in A, a window in B, a door
/// clamped at the mitre; a T whose stem lands inside a door of the
/// through wall.
void lAndT(DraftDocument doc) {
  final hub = plan(0, 0);
  doc.commands.execute(addWall(doc, hA, plan(-3000, 0), hub, 200, centre));
  doc.commands.execute(
      addWall(doc, hB, hub, polar(hub, 180 - 67 + 23, 2500), 115, left));
  doc.commands.execute(addOpening(doc, const Handle(5000),
      const OpeningParams(hA, 900, 900, OpeningKind.door)));
  doc.commands.execute(addOpening(doc, const Handle(5100),
      const OpeningParams(hA, 2100, 900, OpeningKind.window)));
  doc.commands.execute(addOpening(
      doc,
      const Handle(5200),
      const OpeningParams(hB, 1500, 800, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right)));
  doc.commands.execute(addOpening(doc, const Handle(5300),
      const OpeningParams(hA, 2950, 700, OpeningKind.gap)));
  // The T, 3,000 mm below: C tees into D's middle, where a door is cut.
  const hD = Handle(3500);
  doc.commands.execute(
      addWall(doc, hD, plan(-3000, -3000), plan(1000, -3000), 200, centre));
  doc.commands.execute(
      addWall(doc, hC, plan(-1000, -1300), plan(-1000, -3000), 115, centre));
  doc.commands.execute(addOpening(doc, const Handle(5400),
      const OpeningParams(hD, 2000, 900, OpeningKind.door)));
}

/// Draw order: D1 first, then D2 before it along the same wall, so the
/// wall's new end piece (its handles above D1's leaf and arc) touches
/// D1's end-side jamb, where D1 is hinged.
void drawOrder(DraftDocument doc) {
  doc.commands
      .execute(addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, left));
  doc.commands.execute(addOpening(
      doc,
      const Handle(5000),
      const OpeningParams(hA, 3500, 900, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.left)));
  doc.commands.execute(addOpening(doc, const Handle(5100),
      const OpeningParams(hA, 1200, 900, OpeningKind.door)));
}

void main() {
  testWidgets('R1 L and T with openings, white paper', (tester) async {
    final doc = sceneDoc(lAndT, 0xFFFFFFFF);
    await snap(tester, 'r1_l_and_t', doc, plan(-1000, -1300), 0.13);
    await snap(tester, 'r1_zoom_door_a', doc, plan(-2100, 0), 0.6);
    await snap(tester, 'r1_zoom_t_door', doc, plan(-1000, -3000), 0.6);
  });

  testWidgets('R2 draw order at D1\'s hinge jamb: white and Blueprint',
      (tester) async {
    for (final (name, bg) in [
      ('white', 0xFFFFFFFF),
      ('blueprint', 0xFF1F3A5F)
    ]) {
      final doc = sceneDoc(drawOrder, bg);
      final d1 = kids(doc, const Handle(5000));
      final pieces = [
        for (final k in kids(doc, hA))
          if (kindOf(doc, k) == EntityKind.fill) k
      ];
      // ignore: avoid_print
      print('R2 $name: wall children ${kids(doc, hA)}, fills $pieces, '
          'D1 children $d1, D2 children ${kids(doc, const Handle(5100))}');
      final f = oracleFrame(doc, hA);
      final hinge = f.s + f.d * (3500 + 450) + f.n * f.lo;
      await snap(tester, 'r2_${name}_hinge', doc, hinge, 8);
      await snap(tester, 'r2_${name}_wall', doc, f.s + f.d * 2500, 0.2);
    }
  });

  testWidgets(
      'R3 a no-fit window on Blueprint, then a fitting door added '
      'beside it: the new end piece covers the window lines', (tester) async {
    final doc = sceneDoc((doc) {
      doc.commands
          .execute(addWall(doc, hA, plan(-500, 0), plan(500, 0), 200, centre));
      doc.commands.execute(addOpening(doc, const Handle(5000),
          const OpeningParams(hA, 500, 1200, OpeningKind.window)));
      doc.commands.execute(addOpening(doc, const Handle(5100),
          const OpeningParams(hA, 750, 250, OpeningKind.gap)));
    }, 0xFF1F3A5F);
    // ignore: avoid_print
    print('R3: wall children ${kids(doc, hA)}, window children '
        '${kids(doc, const Handle(5000))}');
    await snap(tester, 'r3_blueprint_nofit', doc, plan(400, 0), 0.9);
  });

  test('Q6 picks: the leaf, the arc, the gap, the hinge vertex', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final doc = DraftDocument.empty(measurer: m);
    final sys = installParametric(doc);
    drawOrder(doc);
    doc.commands.execute(addOpening(doc, const Handle(5200),
        const OpeningParams(hA, 4600, 500, OpeningKind.gap)));
    final index = SpatialIndex(doc);
    final f = oracleFrame(doc, hA);
    Vector2 at(double u, double v) => f.s + f.d * u + f.n * v;
    String pick(Vector2 p) {
      final hit = HitPath();
      if (!index.pickInto(p, 20, const QueryFilter.picking(), hit)) {
        return 'miss';
      }
      final key = resolveHit(hit, doc);
      return '${hit.entity.value} (${hit.kind.name}) -> ${key?.target.value}';
    }

    final w = 900.0, uh = 3950.0; // D1: hinge at the end jamb, swing left
    final picks = {
      'D1 leaf middle': pick(at(uh, f.lo + w / 2)),
      'D1 arc middle': pick(at(uh, f.lo) +
          (f.n * math.cos(math.pi / 4) - f.d * math.sin(math.pi / 4)) * w),
      'D1 gap, on the centreline': pick(at(3500, f.lo / 2)),
      'D1 gap, on the centreline (offset 0)': pick(at(3500, 0)),
      'D1 gap, 60 mm off the faces': pick(at(3500, 60)),
      'D1 hinge vertex': pick(at(uh, f.lo)),
      'D1 shut-side jamb vertex': pick(at(3050, f.lo)),
      'gap opening 5200, middle': pick(at(4600, 100)),
    };
    for (final e in picks.entries) {
      // ignore: avoid_print
      print('Q6 ${e.key}: ${e.value}');
    }
    expect(picks['D1 leaf middle'], endsWith('-> 5000'));
    expect(picks['D1 arc middle'], endsWith('-> 5000'));
    index.dispose();
    sys.dispose();
  });
}
