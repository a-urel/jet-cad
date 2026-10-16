// R-16's room lines of the colour export tests (3a Task 28, D-37; rulings
// R-P18, IA-R6), from jet_cad_floor_plan/test/colors/
// table_color_export_test.dart: the fixture premises' key list with R
// (:140-143), EX2's tint and R lines (:237-241), EX3's tint line
// (:277-278) and EX5's row for R (the loop over `filled`, :478-501),
// verbatim, each with the premises it needs. Their table halves stay 2b's
// (jet_cad_2d_plan/test/export/unit_colour_export_test.dart). The fixture
// is `fill_plan.dart`'s (2b's with today's teal room and R), opened by a
// controller over the architecture kit and the fixture kit; the PNG is
// `c.export('plan.png', <png at 96 dpi>)` (today's `exportBytes` and
// `exportPlan`), its pixels read by the source's `decode`, `pixelAt` and
// `expectRgb` (copied from 2b's port, their imports public); the page is
// the plan's root page (today's `exportPageOf`).
//
// Plan colours spec PC-7: export and print carry the table colours, under
// the drawing; a coloured room's tint over them. Expected pixels are
// computed forward from literals and the page's numbers (`composite`,
// `pixelAt`), never read back from the code under test.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/fill_plan.dart';
import '../support/shot.dart';
import '../support/units.dart' show fxKit;

const PlanExportChoice png96 = PlanExportChoice(dpi: PlanExportDpi.d96);

/// A decoded export.
typedef Img = ({int w, int h, Uint8List rgba});

Future<Img> decode(WidgetTester tester, Uint8List png) async =>
    (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        final data =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        return (
          w: image.width,
          h: image.height,
          rgba: data.buffer.asUint8List(),
        );
      } finally {
        image.dispose();
      }
    }))!;

/// The fixture's page: the fill tests set its origin; 1:50, A4 landscape.
PageComponent pageOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!;

/// World ([wx], [wy]) -> image pixel `((x - ox) / den * u, (oy + effH * den
/// - y) / den * u)`, u = dpi / 25.4, computed from the page's numbers, not
/// through any camera of the code under test; the pixel's `0xRRGGBB`, and
/// its alpha, which an export keeps opaque.
({int rgb, int alpha}) pixelAt(Img img, PageComponent page, Vector2 w,
    {int dpi = 96}) {
  final u = dpi / 25.4, den = page.scaleDenominator;
  final x = ((w.x - page.originX) / den * u).floor();
  final y =
      ((page.originY + page.effectiveHeightMm * den - w.y) / den * u).floor();
  expect(x, inInclusiveRange(0, img.w - 1));
  expect(y, inInclusiveRange(0, img.h - 1));
  final i = (y * img.w + x) * 4;
  return (
    rgb: (img.rgba[i] << 16) | (img.rgba[i + 1] << 8) | img.rgba[i + 2],
    alpha: img.rgba[i + 3],
  );
}

void expectRgb(Img img, PageComponent page, Vector2 w, int want, String why) {
  final got = pixelAt(img, page, w);
  expect(got.alpha, 255, reason: why);
  expect(channelDistance(got.rgb, want), lessThanOrEqualTo(1),
      reason: '$why: ${hex(got.rgb)}, want ${hex(want)}');
}

PlanController controllerOver() {
  final c = PlanController(kits: [architectureKit, fxKit()], json: fillJson());
  addTearDown(c.dispose);
  return c;
}

/// The view's camera: 0.06 px/mm, y up, every table in the drawing area at
/// 1440 x 900 (unit_fill_test.dart:401-402).
final ViewportTransform viewCamera = ViewportTransform(
    worldToScreenMatrix: const Transform2(0.06, 0, 0, -0.06, -2260, -1528));

/// The first pump of [c]'s editor under the light theme, then
/// [viewCamera] (today's `pumpPlan`).
Future<void> pumpPlan(WidgetTester tester, PlanController c) async {
  windowAt(tester, const Size(1440, 900));
  await pumpThemed(
      tester, Scaffold(body: PlanEditor(controller: c)), ThemeMode.light);
  await tester.pump();
  await tester.pump();
  c.camera.value = viewCamera;
  await tester.pump();
}

void main() {
  test('the fixture premises: the tables the underlay fills, R among them', () {
    expect([for (final s in specs) s.key],
        ['A', 'B', 'C', 'N', 'U', 'K', 'H', 'M', 'R']);
  });

  testWidgets(
      'EX2-room M-C7 M-PC7-a the PNG at 96 dpi: the coloured table inside '
      'the coloured room under the room\'s 20 % tint (the room\'s lines of '
      'EX2)', (tester) async {
    final c = controllerOver();
    final page = pageOf(c.document);
    final png = await tester.runAsync(() => c.export('plan.png', png96));
    final img = await decode(tester, png!.bytes);
    final purpleFill = composite(purple, alphaDefault, whitePaper);
    expectRgb(img, page, tintSample, composite(teal, tintAlpha, whitePaper),
        'the room\'s tint alone');
    // R: purple at 89 over white, then the room's teal at 51 over that.
    expectRgb(img, page, insideTop(spec('R')),
        composite(teal, tintAlpha, purpleFill), 'R under the room\'s tint');
  });

  testWidgets(
      'EX3-room M-PC7-b the export at opacity 0: the room\'s tint stays (the '
      'room\'s line of EX3)', (tester) async {
    final c = controllerOver();
    final page = pageOf(c.document);
    final out = await tester
        .runAsync(() => c.export('plan.png', png96, unitColourOpacity: 0));
    final img = await decode(tester, out!.bytes);
    expectRgb(img, page, insideTop(spec('A')), whitePaper, '0: A');
    expectRgb(img, page, tintSample, composite(teal, tintAlpha, whitePaper),
        '0: the room\'s tint stays');
  });

  testWidgets(
      'EX5-room differential: the design canvas (white page, light theme) '
      'and the PNG export at the default opacity agree on R\'s colour, '
      'inside the room, within one unit per channel (EX5\'s row for R)',
      (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c);
    final shot = await shoot(tester);
    final page = pageOf(c.document);
    final out = await tester.runAsync(() => c.export('plan.png', png96));
    final img = await decode(tester, out!.bytes);
    for (final s in [spec('R')]) {
      final w = insideTop(s);
      final (x, y) = pixelOf(tester, w);
      final onScreen = shot.rgbAt(x, y);
      final exported = pixelAt(img, page, w);
      expect(channelDistance(onScreen, exported.rgb), lessThanOrEqualTo(1),
          reason: '${s.key}: canvas ${hex(onScreen)}, '
              'export ${hex(exported.rgb)}');
      // Neither is the paper: the colour is really on both.
      expect(channelDistance(onScreen, whitePaper), greaterThan(20),
          reason: '${s.key} on the canvas');
      expect(channelDistance(exported.rgb, whitePaper), greaterThan(20),
          reason: '${s.key} in the export');
    }
  });
}
