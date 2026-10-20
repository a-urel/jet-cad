// POS-host fix wave: the first fit shows the whole sheet on every layout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitWords;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/mark_kit.dart';

/// A3 landscape at 1:50, off the origin, set by a host build.
void a3Build(DraftDocument doc, KitWords words) {
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          widthMm: 297,
          heightMm: 420,
          orientation: PageOrientation.landscape,
          scaleDenominator: 50,
          originX: 7000,
          originY: -3000)));
}

void main() {
  for (final (w, h) in [(375.0, 812.0), (800.0, 1280.0), (1440.0, 900.0)]) {
    testWidgets(
        'FF $w x $h: the first fit maps the whole sheet into the canvas',
        (tester) async {
      // The controller is made inside the first build, as an app's State
      // does: the build's page change reaches the page notifier's stream
      // only after the first frame's post-frame callbacks.
      PlanController? made;
      addTearDown(() => made?.dispose());
      await tester.binding.setSurfaceSize(Size(w, h));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        return PlanEditor(
            controller: made ??=
                PlanController(kits: [markKit()], build: a3Build),
            gallery: false);
      }))));
      final c = made!;
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      final canvas = tester.getRect(find.byKey(const Key('chrome-canvas')));
      final page =
          c.document.components.get<PageComponent>(c.document.rootHandle)!;
      final sheet = sheetWorldRect(page);
      final m = c.camera.value.worldToScreenMatrix;
      Offset toScreen(double x, double y) => Offset(
          m.a * x + m.c * y + m.e + canvas.left,
          m.b * x + m.d * y + m.f + canvas.top);
      final a = toScreen(sheet.minX, sheet.minY);
      final b = toScreen(sheet.maxX, sheet.maxY);
      final r = Rect.fromPoints(a, b);
      expect(canvas.inflate(0.5).contains(r.topLeft), isTrue,
          reason: 'sheet $r in canvas $canvas');
      expect(canvas.inflate(0.5).contains(r.bottomRight), isTrue,
          reason: 'sheet $r in canvas $canvas');
    });
  }
}
