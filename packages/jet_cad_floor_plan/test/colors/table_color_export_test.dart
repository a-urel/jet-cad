// Plan colours spec PC-7 (Slice 2 plan, Task 4): export and print carry the
// table colours. The floor plan builds an underlay of the coloured tables'
// tops (`tableColorUnderlay`) and hands it to the render package's page
// export, which draws it after the paper and before the drawing; the opacity
// is the exporting view's theme, or 0.35 / a given value for the
// controller's headless `exportPlan` and `printPlan`.
//
// The fixture is the fill tests' (`test/service/table_fill_test.dart`): one
// plan, every table turned and mirrored, 38 m and more off the origin, most
// of them the embedding fixture's asymmetric quadrilateral (its box off the
// definition's origin, where the number sits), two of them a round top off
// the origin too; a coloured table inside a coloured room, an unnumbered
// one, one on a locked layer, one on a hidden layer, one carrying the
// unknown name "magenta". Hues teal and purple.
//
// Expected pixels are computed forward from literals and the page's numbers
// (`composite`, `pixelAt`), never read back from the code under test, and
// sampled inside a top, off its number label (the label sits at the base
// point, outside the top).
import 'dart:convert' show latin1;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show
        ExportDpi,
        FlutterTextMeasurer,
        PageUnderlayCircle,
        PageUnderlayPolygon;
import 'package:jet_cad_floor_plan/src/colors/table_color_underlay.dart';
import 'package:jet_cad_floor_plan/src/export/export_bytes.dart';
import 'package:jet_cad_floor_plan/src/export/export_dialog.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_theme.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../service/table_fill_test.dart'
    show
        Spec,
        alphaDefault,
        alphaThemed,
        composite,
        controllerOver,
        fillDoc,
        fillJson,
        insideTop,
        placementOf,
        pumpPlan,
        purple,
        spec,
        specs,
        teal,
        tintAlpha,
        tintSample,
        whitePaper;
import '../support/fake_page_printer.dart';
import '../support/palette_fixture.dart'
    show channelDistance, hex, pixelOf, shoot;

const ExportChoice png96 =
    ExportChoice(format: ExportFormat.png, dpi: ExportDpi.d96);
const FloorPlanExportChoice apiPng96 = FloorPlanExportChoice(
    format: FloorPlanExportFormat.png, dpi: FloorPlanExportDpi.d96);

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

/// [pdf] as text, the trailer's `/ID` blanked: it is random per write, the
/// one part of two writes of one document that differs (same length, so
/// every offset is unchanged).
String text(Uint8List pdf) => latin1
    .decode(pdf)
    .replaceAllMapped(RegExp(r'/ID\[<[0-9a-f]+><[0-9a-f]+>\]'), (m) => '/ID');

/// The fill alphas the page's graphics states carry (`ca`), as written.
Set<String> alphas(String pdf) =>
    {for (final m in RegExp(r'/ca ([0-9.]+)').allMatches(pdf)) m.group(1)!};

/// The fixture's page: the fill tests set its origin; 1:50, A4 landscape.
PageComponent pageOf(DraftDocument doc) => exportPageOf(doc)!;

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

/// The tables the underlay fills, in ascending instance order: the
/// coloured ones of a known hue on a visible layer.
final List<Spec> filled = [
  for (final k in ['A', 'B', 'C', 'U', 'K', 'R']) spec(k),
];

void main() {
  test('the fixture premises: the tables the underlay fills', () {
    expect([for (final s in specs) s.key],
        ['A', 'B', 'C', 'N', 'U', 'K', 'H', 'M', 'R']);
    expect(spec('H').layer, 'Hidden');
    expect(spec('K').layer, 'Locked');
    expect(spec('M').color, 'magenta');
    expect(spec('N').color, isNull);
    expect(spec('U').label, isNull);
    for (final s in specs) {
      final t = placementOf(s);
      expect(t.a * t.d - t.b * t.c, closeTo(-1, 1e-12), reason: s.key);
      expect(t.b.abs(), greaterThan(0.1), reason: '${s.key} turned');
    }
    expect(composite(teal, alphaDefault, whitePaper), 0xA6D6D1);
  });

  test(
      'EX1 tableColorUnderlay(doc, 0.35): one fill per visible coloured '
      'table of a known hue, ascending by instance; a polygon is its ring '
      'closed and triangulated, a circle its centre and radius; each placed '
      'by its instance\'s transform; nothing for the hidden, the unknown or '
      'the uncoloured', () {
    final doc = fillDoc(const InsertionPointMeasurer());
    addTearDown(doc.dispose);
    final fills = tableColorUnderlay(doc, 0.35);
    expect(fills, hasLength(filled.length));
    for (var i = 0; i < filled.length; i++) {
      final s = filled[i], f = fills[i];
      final rgb = s.color == 'teal' ? teal : purple;
      expect(f.argb, (89 << 24) | rgb, reason: s.key);
      final want = placementOf(s).toJson(), got = f.placement.toJson();
      for (var k = 0; k < 6; k++) {
        expect(got[k], closeTo(want[k], 1e-9), reason: '${s.key} placement $k');
      }
      expect(got[1].abs(), greaterThan(0.1), reason: '${s.key} is turned');
      switch (f) {
        case PageUnderlayPolygon():
          expect(s.round, isFalse, reason: s.key);
          // The embedding fixture's quadrilateral, written out, then its
          // first point repeated.
          expect(f.xy.toList(),
              [300, -200, 1100, -200, 900, 400, 300, 250, 300, -200],
              reason: s.key);
          expect(f.count, 5, reason: s.key);
          expect(f.triangles, hasLength(6), reason: '${s.key}: two triangles');
          expect(f.triangles.every((v) => v >= 0 && v < f.count), isTrue);
        case PageUnderlayCircle():
          expect(s.round, isTrue, reason: s.key);
          expect([f.cx, f.cy, f.r], [600, 300, 400], reason: s.key);
      }
    }
    // The hidden, the unknown "magenta" and the uncoloured: no fill.
    final placements = [for (final f in fills) f.placement.toJson()];
    for (final k in ['H', 'M', 'N']) {
      final p = placementOf(spec(k)).toJson();
      expect(placements.where((q) {
        for (var i = 0; i < 6; i++) {
          if ((q[i] - p[i]).abs() > 1e-9) return false;
        }
        return true;
      }), isEmpty, reason: '$k has no fill');
    }
    // The opacity is the alpha: round(255 * o).
    expect({for (final f in tableColorUnderlay(doc, 0.6)) f.argb >> 24}, {153});
    expect({for (final f in tableColorUnderlay(doc, 1)) f.argb >> 24}, {255});
    expect({for (final f in tableColorUnderlay(doc, 0)) f.argb >> 24}, {0});
  });

  testWidgets(
      'EX2 M-C7 M-C8 M-PC7-a the PNG through exportBytes at 96 dpi: a teal '
      'top\'s off-centre arm is teal at alpha 89 over white, a purple round '
      'top purple, the locked one coloured, the coloured table inside the '
      'coloured room under the room\'s 20 % tint; the hidden, the unknown '
      'and the uncoloured are white', (tester) async {
    final doc = fillDoc(FlutterTextMeasurer());
    addTearDown(doc.dispose);
    final page = pageOf(doc);
    final png = await tester.runAsync(() => exportBytes(doc, page, png96,
        fontBytes: () async => throw StateError('a PNG reads no font')));
    final img = await decode(tester, png!);
    final tealFill = composite(teal, alphaDefault, whitePaper);
    final purpleFill = composite(purple, alphaDefault, whitePaper);
    expect(hex(tealFill), hex(0xA6D6D1), reason: 'premise: the arithmetic');
    for (final k in ['A', 'C', 'U']) {
      expectRgb(img, page, insideTop(spec(k)), tealFill, k);
    }
    for (final k in ['B', 'K']) {
      expectRgb(img, page, insideTop(spec(k)), purpleFill, k);
    }
    for (final k in ['N', 'H', 'M']) {
      expectRgb(img, page, insideTop(spec(k)), whitePaper, k);
    }
    expectRgb(img, page, tintSample, composite(teal, tintAlpha, whitePaper),
        'the room\'s tint alone');
    // R: purple at 89 over white, then the room's teal at 51 over that.
    expectRgb(img, page, insideTop(spec('R')),
        composite(teal, tintAlpha, purpleFill), 'R under the room\'s tint');
  });

  testWidgets(
      'EX3 Review Focus 3 M-C8 M-PC7-b controller.exportPlan(png) with no '
      'view mounted: coloured tables at 0.35 by default, at alpha 153 for '
      '0.6, opaque for 1, none for 0; an opacity outside [0, 1] or not '
      'finite throws ArgumentError and no flow runs', (tester) async {
    final c = FloorPlanController(json: fillJson());
    addTearDown(c.dispose);
    final page = pageOf(c.activeDocument);
    final a = insideTop(spec('A')), b = insideTop(spec('B'));
    final k = insideTop(spec('K'));

    Future<Img> export([double? opacity]) async {
      final out = await tester
          .runAsync(() => c.exportPlan(apiPng96, tableColorOpacity: opacity));
      return decode(tester, out!.bytes);
    }

    var img = await export();
    expectRgb(img, page, a, composite(teal, 89, whitePaper), 'default: A');
    expectRgb(img, page, k, composite(purple, 89, whitePaper), 'default: K');
    img = await export(0.35);
    expectRgb(img, page, a, composite(teal, 89, whitePaper), '0.35: A');
    img = await export(0.6);
    expectRgb(img, page, a, composite(teal, alphaThemed, whitePaper), '0.6: A');
    expectRgb(
        img, page, b, composite(purple, alphaThemed, whitePaper), '0.6: B');
    expectRgb(img, page, k, composite(purple, alphaThemed, whitePaper),
        '0.6: K, locked');
    img = await export(1);
    expectRgb(img, page, a, teal, '1: A opaque');
    expectRgb(img, page, insideTop(spec('N')), whitePaper, '1: N uncoloured');
    img = await export(0);
    expectRgb(img, page, a, whitePaper, '0: A');
    expectRgb(img, page, tintSample, composite(teal, tintAlpha, whitePaper),
        '0: the room\'s tint stays');

    for (final bad in [1.5, -0.1, double.nan, double.infinity]) {
      expect(() => c.exportPlan(apiPng96, tableColorOpacity: bad),
          throwsA(isA<ArgumentError>()),
          reason: '$bad');
      expect(
          () => c.printPlan(printer: FakePagePrinter(), tableColorOpacity: bad),
          throwsA(isA<ArgumentError>()),
          reason: 'print $bad');
      expect(c.pageFlowReady.value, isTrue, reason: 'no flow ran for $bad');
    }
    final printer = FakePagePrinter();
    expect(() => c.printPlan(printer: printer, tableColorOpacity: 2),
        throwsArgumentError);
    expect(printer.calls, isEmpty, reason: 'nothing was printed');
    // A refusal leaves the guard free: the next export runs.
    expect(await tester.runAsync(() => c.exportPlan(apiPng96)), isNotNull);
  });

  testWidgets(
      'EX3b printPlan carries the colours at the given opacity: the PDF '
      'differs by it, is the same for the same, and the default is 0.35',
      (tester) async {
    final c = FloorPlanController(json: fillJson());
    addTearDown(c.dispose);
    Future<Uint8List> pdf([double? opacity]) async {
      final printer = FakePagePrinter();
      final ok = await tester.runAsync(
          () => c.printPlan(printer: printer, tableColorOpacity: opacity));
      expect(ok, isTrue);
      return printer.calls.single.pdf;
    }

    final byDefault = text(await pdf());
    final explicit = text(await pdf(0.35));
    final themed = text(await pdf(0.6));
    final none = text(await pdf(0));
    // round(255 * o) / 255, five decimals: 89, 153 and 0 of 255.
    expect(alphas(byDefault), contains('0.34902'));
    expect(alphas(byDefault), isNot(contains('0.6')));
    expect(alphas(themed), contains('0.6'));
    expect(alphas(themed), isNot(contains('0.34902')));
    expect(alphas(none), contains('0'));
    expect(alphas(none), isNot(contains('0.34902')));
    expect(explicit, byDefault, reason: 'the default is 0.35');
    expect(themed, isNot(byDefault), reason: '0.6 is another alpha');
    expect(none, isNot(byDefault));
    expect(themed, isNot(none));
    expect(text(await pdf(0.6)), themed, reason: 'the same bytes again');
  });

  testWidgets(
      'EX4 M-C23 the view\'s Export and Print at a non-default theme: '
      'tableColorOpacity 0.6 reaches the bytes (alpha 153), read at the call '
      'and resolved as the scope resolves it (the ambient extension, the '
      'view\'s theme over it, field by field)', (tester) async {
    final got = <FloorPlanExport>[];
    final printer = FakePagePrinter();
    final c = FloorPlanController(json: fillJson());
    addTearDown(c.dispose);
    final page = pageOf(c.activeDocument);
    Future<FloorPlanExportChoice?> dialog(
            BuildContext context, FloorPlanExportChoice initial) async =>
        apiPng96;
    Widget app(FloorPlanTheme? theme, {FloorPlanTheme? ambient}) => MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: ThemeData(extensions: [if (ambient != null) ambient]),
        home: Scaffold(
            body: FloorPlanView(
                controller: c,
                theme: theme,
                onExport: got.add,
                printer: printer,
                onExportDialog: dialog)));
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(
        const FloorPlanTheme(tableColorOpacity: 0.6, statusFillOpacity: 0.8)));
    await tester.pump();
    await tester.pump();

    Future<void> settled(bool Function() done) async {
      for (var i = 0; i < 600 && !done(); i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(done(), isTrue);
      // The flow is over once its guard is free again.
      for (var i = 0; i < 600 && !c.pageFlowReady.value; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(c.pageFlowReady.value, isTrue);
    }

    // Cmd+[key].
    Future<void> chord(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    Future<Img> exportByChord() async {
      final before = got.length;
      await chord(LogicalKeyboardKey.keyE);
      await settled(() => got.length > before);
      return decode(tester, got.last.bytes);
    }

    Future<Set<String>> printByChord() async {
      final before = printer.calls.length;
      await chord(LogicalKeyboardKey.keyP);
      await settled(() => printer.calls.length > before);
      return alphas(text(printer.calls.last.pdf));
    }

    final a = insideTop(spec('A')), k = insideTop(spec('K'));
    final tealDefault = composite(teal, alphaDefault, whitePaper);

    var img = await exportByChord();
    expectRgb(img, page, a, composite(teal, alphaThemed, whitePaper), '0.6: A');
    expectRgb(
        img, page, k, composite(purple, alphaThemed, whitePaper), '0.6: K');
    var printed = await printByChord();
    expect(printed, contains('0.6'), reason: 'Print at 0.6');
    expect(printed, isNot(contains('0.34902')), reason: 'Print at 0.6');

    // The theme is read at the call: a host rebuild with another opacity,
    // and with none, changes the next export, with no flows rebuilt.
    await tester.pumpWidget(app(const FloorPlanTheme(tableColorOpacity: 1)));
    await tester.pump();
    img = await exportByChord();
    expectRgb(img, page, a, teal, 'theme 1: A opaque');
    printed = await printByChord();
    expect(printed, isNot(contains('0.6')), reason: 'Print at 1');
    await tester.pumpWidget(app(const FloorPlanTheme(statusFillOpacity: 0.8)));
    await tester.pump();
    img = await exportByChord();
    expectRgb(img, page, a, tealDefault, 'a theme without it: 0.35');
    await tester.pumpWidget(app(null));
    await tester.pump();
    img = await exportByChord();
    expectRgb(img, page, a, tealDefault, 'no theme: 0.35');
    printed = await printByChord();
    expect(printed, contains('0.34902'), reason: 'Print with no theme');
    expect(printed, isNot(contains('0.6')), reason: 'Print with no theme');

    // The ambient extension alone, the view's theme over it, field by field.
    const ambient = FloorPlanTheme(tableColorOpacity: 0.6);
    await tester.pumpWidget(app(null, ambient: ambient));
    await tester.pump();
    img = await exportByChord();
    expectRgb(img, page, a, composite(teal, alphaThemed, whitePaper),
        'the ambient 0.6');
    printed = await printByChord();
    expect(printed, contains('0.6'), reason: 'Print at the ambient 0.6');
    await tester.pumpWidget(
        app(const FloorPlanTheme(statusFillOpacity: 0.8), ambient: ambient));
    await tester.pump();
    img = await exportByChord();
    expectRgb(img, page, a, composite(teal, alphaThemed, whitePaper),
        'the ambient 0.6 kept beside the view\'s other field');
    await tester.pumpWidget(
        app(const FloorPlanTheme(tableColorOpacity: 1), ambient: ambient));
    await tester.pump();
    img = await exportByChord();
    expectRgb(img, page, a, teal, 'the view\'s 1 over the ambient 0.6');
  });

  testWidgets(
      'EX5 differential: the design canvas (white page, light theme) and the '
      'PNG export at the default opacity agree on every coloured table\'s '
      'colour, within one unit per channel', (tester) async {
    final c = controllerOver();
    await pumpPlan(tester, c);
    final shot = await shoot(tester);
    final page = pageOf(c.activeDocument);
    final out = await tester.runAsync(() => c.exportPlan(apiPng96));
    final img = await decode(tester, out!.bytes);
    for (final s in filled) {
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
