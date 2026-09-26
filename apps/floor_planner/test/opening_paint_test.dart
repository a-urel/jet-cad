// Spec 08 D12: draw order stays ascending handle value, and a fitting
// symbol is never covered by its host's pieces, even by a piece added after
// it. 07's WP5 method (`wall_paint_test.dart`): the shell rendered in
// `flutter_test` and read back with `RenderRepaintBoundary.toImage`, here on
// Blueprint paper, where the ByLayer symbol is light and the wall black.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

const hA = Handle(1300), hD = Handle(4000), hW = Handle(4100);

/// The page panel's Blueprint paper.
const int blueprint = 0xFF1F3A5F;

/// Relative luminance of one RGBA pixel, 0 (black) to 1 (white).
double _luminance(ByteData d, int i) =>
    (0.2126 * d.getUint8(i) +
        0.7152 * d.getUint8(i + 1) +
        0.0722 * d.getUint8(i + 2)) /
    255;

void main() {
  testWidgets(
      'RD1 (X6-cover) on Blueprint, door D1 hinged at its end jamb, then a '
      'window added on its start side: the piece beside D1\'s hinge is '
      'rewritten into fresh handles above D1\'s leaf, and D1\'s leaf still '
      'shows light 3-10 px from the hinge; the wall\'s body is black',
      (tester) async {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final doc = DraftDocument.empty(measurer: m);
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        PageComponent(
            scaleDenominator: 20,
            originX: ox - 3000,
            originY: oy - 2000,
            background: blueprint,
            snapToGrid: false)));
    final system = installParametric(doc);
    doc.commands.execute(addWall(doc, hA, plan(-2500, -600), plan(2500, -600),
        200, Justification.centre));
    doc.commands.execute(addOpening(
        doc,
        hD,
        const OpeningParams(hA, 3500, 900, OpeningKind.door,
            hinge: HingeEnd.end)));
    final leaf = kids(doc, hD).first;
    expect(kindOf(doc, leaf), EntityKind.line);
    // D1 fits, and its hinge is the end jamb's corner on the left face.
    expect(OpeningOracle(doc).drawn(hD).fits, isTrue);
    final f = oracleFrameOf(doc, hA);
    final hinge = oracleAt(f, 3950, f.lo);
    expect((doorOracle(doc, hD).hinge - hinge).length, lessThan(1e-6));
    doc.commands.execute(addOpening(
        doc, hW, const OpeningParams(hA, 1200, 900, OpeningKind.window)));
    expect(driftOf(doc), isEmpty);
    system.dispose();
    doc.commands.clearHistory();

    // The piece at D1's hinge was rewritten into the wall's newest region,
    // fill and boundary both above D1's leaf: it is drawn after the leaf.
    final pieces = worldPieces(doc, hA);
    expect(pieces, hasLength(3));
    final fills = fillsOf(doc, hA);
    final atHinge = [
      for (var i = 0; i < fills.length; i++)
        if (nearestIn(pieces[i], hinge) < 1e-6) fills[i]
    ].single;
    expect(atHinge.value, greaterThan(leaf.value));
    expect(boundaryOf(doc, atHinge).value, greaterThan(leaf.value));

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: capture, child: MaterialApp(home: PlannerShell(document: doc))));
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(InteractionLayer));
    // Rotated, 8 px per mm, centred on the leaf's first stored point: the
    // hinge, where D1 is drawn as D10 says.
    final (from, to) = worldLines(doc, hD).single;
    const pxPerMm = 8.0;
    final linear =
        Transform2.rotation(0.35).multiply(Transform2.scale(pxPerMm, pxPerMm));
    final mid = linear.transformPoint(from);
    view.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(
                size.width / 2 - mid.x, size.height / 2 - mid.y)
            .multiply(linear));
    await tester.pump();

    Offset globalOf(Vector2 p) {
      final s = view.camera.value.worldToScreen(p);
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(s.x, s.y);
    }

    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final (pixels, width) = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      return (bytes!, width);
    }))!;
    double lumAt(Vector2 p) {
      final o = globalOf(p);
      // The pixel that contains the point: [x, x + 1) is pixel x.
      return _luminance(pixels, (o.dy.floor() * width + o.dx.floor()) * 4);
    }

    // The brightest pixel of the 3 × 3 block around [p]: a 1 px stroke
    // steps from pixel to pixel along a slant, so the one pixel containing
    // a point on it need not be painted.
    double brightestNear(Vector2 p) {
      final o = globalOf(p);
      var best = 0.0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final l = _luminance(
              pixels, ((o.dy.floor() + dy) * width + o.dx.floor() + dx) * 4);
          if (l > best) best = l;
        }
      }
      return best;
    }

    // Along the leaf as it is stored, from its first point: 3 to 10 px out.
    final along = (to - from).normalized();
    final leafLum = [
      for (var px = 3; px <= 10; px++)
        brightestNear(from + along * (px / pxPerMm)),
    ];
    // The wall's body inside the fresh piece, just past the leaf's first
    // point along the wall and into the band, and the paper in the
    // doorway, just before it.
    final bodyLum = [
      for (final (du, dv) in const [(3.0, -2.0), (6.0, -12.5), (15.0, -30.0)])
        lumAt(from + f.d * du + f.n * dv),
    ];
    final paperLum = lumAt(from - f.d * 15 - f.n * 30);
    // ignore: avoid_print
    print('RD1 leaf ${[for (final l in leafLum) l.toStringAsFixed(2)]} body '
        '${[for (final l in bodyLum) l.toStringAsFixed(2)]} paper '
        '${paperLum.toStringAsFixed(2)}');
    for (final (i, l) in leafLum.indexed) {
      expect(l, greaterThan(0.6), reason: 'the leaf, ${i + 3} px out');
    }
    for (final l in bodyLum) {
      expect(l, lessThan(0.1), reason: 'the wall');
    }
    const blue = (0.2126 * 0x1F + 0.7152 * 0x3A + 0.0722 * 0x5F) / 255;
    expect(paperLum, closeTo(blue, 0.05),
        reason: 'Blueprint paper in the doorway');
    // And the leaf sampled is D10's, from the hinge on the face.
    expect((from - hinge).length, lessThan(1e-6));
    expectDoorOnOracle(doc, hD);
  });
}
