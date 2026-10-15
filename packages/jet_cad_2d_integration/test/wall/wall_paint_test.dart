// Ported from jet_cad_floor_plan/test/wall_paint_test.dart (3a Task 12): WP5 over a PlanController of the architecture kit in PlanEditor, assertions unchanged.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';
import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

/// The wall drawn with W: 3,000 mm at 23° about the far origin, 200 mm
/// thick by the tool's default, well inside the page.
final Vector2 _a = plan(-1500, 0), _b = plan(1500, 0);

/// Relative luminance of one RGBA pixel, 0 (black) to 1 (white).
double _luminance(ByteData d, int i) =>
    (0.2126 * d.getUint8(i) +
        0.7152 * d.getUint8(i + 1) +
        0.0722 * d.getUint8(i + 2)) /
    255;

void main() {
  testWidgets(
      'WP5 a wall drawn with W paints a dark band on white paper, not a '
      'paper-white one (07 D3, smoke test)', (tester) async {
    final ctrl = wallController(wallPlanJson(
        PageComponent(
            scaleDenominator: 20,
            originX: ox - 2900,
            originY: oy - 2000,
            snapToGrid: false),
        (_) {}));
    final doc = ctrl.document;
    expect(doc.components.get<PageComponent>(doc.rootHandle)!.background,
        0xFFFFFFFF);

    // Rotated, 0.2 px per mm: the band is 40 px wide.
    await pumpEditor(tester, ctrl, centre: far(0, 0), scale: 0.2);

    Offset globalOf(Vector2 p) {
      final s = ctrl.camera.value.worldToScreen(p);
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(s.x, s.y);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    await tester.tapAt(globalOf(_a));
    await tester.pump();
    await tester.tapAt(globalOf(_b));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    final walls = doc.components.withComponent<WallParams>().toList();
    expect(walls, hasLength(1));
    final w = worldWallOf(doc, walls.single);
    expect(w.t, 200);
    expect(w.j, Justification.centre);

    final boundary = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(
            of: find.byType(InteractionLayer),
            matching: find.byType(RepaintBoundary))
        .last);
    final origin = boundary.localToGlobal(Offset.zero);
    final (pixels, width) = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      return (bytes!, width);
    }))!;
    double lumAt(Vector2 p) {
      final o = globalOf(p) - origin;
      return _luminance(pixels, (o.dy.round() * width + o.dx.round()) * 4);
    }

    // Along the wall at fractions that sit off the 10 mm grid, on the
    // centreline and 50 mm to either side of it (inside the 100 mm half
    // band); and the paper 400 mm off the band, as the control.
    final n = Vector2(-w.d.y, w.d.x);
    for (final f in const [0.23, 0.41, 0.57, 0.77]) {
      final c = w.s + (w.e - w.s) * f;
      for (final off in const [0.0, 50.0, -50.0]) {
        expect(lumAt(c + n * off), lessThan(0.2),
            reason: 'band at $f, offset $off');
      }
      for (final off in const [403.0, -397.0]) {
        expect(lumAt(c + n * off), greaterThan(0.7),
            reason: 'paper at $f, offset $off');
      }
    }
  });
}
