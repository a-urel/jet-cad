// Ported from the old apps/restaurant_demo/test/look_test.dart (the
// restaurant-kit test audit, section 8, docs/superpowers/specs/
// 2026-10-16-restaurant-kit-test-audit.md): the app bar's Standard / POS
// look. The POS look is a `PlanTheme` in each of the app's themes
// (lib/demo_theme.dart), a local `Theme` with a hand-built `ColorScheme`
// around the view, and one field of the view's own (`selectionWidth: 3`),
// merged over the extension. Read back on the Salon sample, whose fitted
// camera is neither the identity nor at the origin, in both modes, under a
// light and a dark platform, in pixels where the demo can see them (the bar,
// the surround, the selection, the fill, the caption's size) and in the theme
// the view resolves where it cannot (the caption's weight and family).
// Standard again gives back today's pixels, byte for byte. Expected colours
// are the theme's own tokens or composited here, never read from the
// planner.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PaperPalette, SelectionOverlayPainter;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/demo_theme.dart';
import 'package:restaurant_demo/statuses.dart' show kStatuses;
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadThemeData, ShadTheme, ShadZincColorScheme;

import 'support/demo_rig.dart';

/// Past the app's theme animation (200 ms) and the view's re-measure.
Future<void> settleTheme(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// One captured frame of the whole window, at device pixel ratio 1.
final class Shot {
  Shot(this.bytes, this.width);

  final ByteData bytes;
  final int width;

  /// `0xRRGGBB` at pixel ([x], [y]).
  int rgbAt(int x, int y) {
    final i = (y * width + x) * 4;
    return (bytes.getUint8(i) << 16) |
        (bytes.getUint8(i + 1) << 8) |
        bytes.getUint8(i + 2);
  }

  int rgbAtOffset(Offset p) => rgbAt(p.dx.floor(), p.dy.floor());

  /// How many pixels of [r] satisfy [test].
  int count(Rect r, bool Function(int rgb) test) {
    var n = 0;
    for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
      for (var x = r.left.floor(); x < r.right.ceil(); x++) {
        if (test(rgbAt(x, y))) n++;
      }
    }
    return n;
  }

  /// [r]'s pixels, row by row, for an exact comparison.
  List<int> region(Rect r) => [
        for (var y = r.top.floor(); y < r.bottom.ceil(); y++)
          for (var x = r.left.floor(); x < r.right.ceil(); x++) rgbAt(x, y),
      ];
}

/// The window of these tests. The first fit shows the whole A3 sheet (it
/// framed the A4 sheet the build replaced before the fit fix): the window is
/// as much larger as the tables were once drawn larger than the sheet.
const Size kWindow = Size(2300, 1450);

/// The window as it is now: the route's boundary, the whole screen.
Future<Shot> shoot(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find
      .ancestor(
          of: find.byType(Scaffold), matching: find.byType(RepaintBoundary))
      .first);
  expect(boundary.size, kWindow, reason: 'premise: the window');
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final shot = Shot(raw!, image.width);
    image.dispose();
    return shot;
  }))!;
}

int rgbOf(Color c) => c.toARGB32() & 0xFFFFFF;

String hex(int rgb) => '0x${rgb.toRadixString(16).padLeft(6, '0')}';

/// The largest per-channel difference of two `0xRRGGBB` values.
int distance(int a, int b) => [16, 8, 0]
    .map((s) => (((a >> s) & 0xFF) - ((b >> s) & 0xFF)).abs())
    .reduce((x, y) => x > y ? x : y);

/// [colour] (straight alpha [alpha]) over the opaque [paper], `0xRRGGBB`.
int over(Color colour, double alpha, int paper) {
  int channel(double c, int shift) =>
      (c * 255 * alpha + ((paper >> shift) & 0xFF) * (1 - alpha)).round();
  return (channel(colour.r, 16) << 16) |
      (channel(colour.g, 8) << 8) |
      channel(colour.b, 0);
}

/// [rgb] seen through a room's tint over the White page: each channel
/// scaled by 0xE5/0xFF (measured: Bill's 0xEF8886 over White reads 0xD77A78
/// on the Garden's table).
int inRoom(int rgb) {
  int channel(int shift) => ((((rgb >> shift) & 0xFF) * 0xE5) / 0xFF).round();
  return (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

/// Table [number]'s bounding box on the screen, from its world corners
/// through the public `worldToGlobal`.
Rect screenBox(PlanController c, String number) {
  final points = unitCorners(c, number);
  var box = Rect.fromPoints(points[0], points[1]);
  for (final p in points.skip(2)) {
    box = box.expandToInclude(Rect.fromPoints(p, p));
  }
  return box;
}

/// [number]'s box on screen with the band under it where its status caption
/// is drawn (P7, the caption sits clear of the unit's box, chairs and all).
Rect captionBand(PlanController c, String number) {
  final box = screenBox(c, number);
  return Rect.fromLTRB(box.left, box.top, box.right, box.bottom + 40);
}

/// The selection overlay the shown mode painted with.
SelectionOverlayPainter overlay(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .firstWhere((p) => p.painter is SelectionOverlayPainter)
    .painter! as SelectionOverlayPainter;

/// A pixel of the drawing area's surround: its bottom-left corner, clear of
/// the page at the sample's fit.
Offset surround(PlanController c) {
  final r = c.canvasRect.value!;
  return Offset(r.left + 3, r.bottom - 3);
}

/// A pixel of the service bar's own background, right of its buttons.
Offset barBackground(WidgetTester tester) {
  final r = tester.getRect(byKey('service-bar'));
  return Offset(r.right - 4, r.center.dy);
}

/// The look's controls and what the view resolved, by the public API: the
/// ambient extension and colour scheme at the view's element, the
/// `ShadTheme` above it (R-LOOK) and the view's own `theme:`.
({PlanTheme? ambient, ColorScheme scheme, ShadThemeData? shad, PlanTheme? view})
    seen(WidgetTester tester) {
  final view = find.byType(PlanEditor);
  final theme = Theme.of(tester.element(view));
  return (
    ambient: theme.extension<PlanTheme>(),
    scheme: theme.colorScheme,
    shad: ShadTheme.maybeOf(tester.element(view)),
    view: tester.widget<PlanEditor>(view).theme,
  );
}

/// What a check of one look in one mode saw.
typedef Look = ({
  Shot shot,
  Rect view,
  int selectionPixels,
});

void main() {
  for (final brightness in Brightness.values) {
    final name = brightness.name;
    testWidgets(
        'DL${brightness == Brightness.light ? 1 : 2} the POS look under a '
        '$name platform: the extension of the app\'s $name theme, a '
        'ShadTheme of zinc above the view, zinc\'s background on the bar (DL-S1), under '
        'Standard the derived one, the 52 px bar, the surround '
        'in the canvas colour in both modes, the selection 3 px in the '
        'theme\'s colour for the paper in both modes, the fill at 0.8, the '
        '12 px bold Roboto caption; Standard again is today\'s, byte for byte',
        (tester) async {
      if (brightness == Brightness.dark) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      }
      final demo = await pumpDemo(tester, size: kWindow);
      final c = demo.area.controller;
      final light = brightness == Brightness.light;
      final pos = posPlanTheme(brightness);
      final posShad = posShadTheme(brightness);
      final zinc = light
          ? const ShadZincColorScheme.light()
          : const ShadZincColorScheme.dark();
      // The Salon's page is White: under the dark theme it is shown on the
      // dark canvas (14d K1), whose selection is the dark set's.
      final standardSet = light ? PaperPalette.light : PaperPalette.dark;
      final posSelection = light ? pos.selectionOnLight! : pos.selectionOnDark!;
      expect(rgbOf(posSelection), isNot(rgbOf(standardSet.selection)),
          reason: 'premise: the looks select in different colours');

      // Bill on 2 through the demo's own button, 7 selected.
      await tester.tap(byKey('mode-service'));
      await settleTheme(tester);
      c.select({'2'});
      await tester.pump();
      await pressInPanel(tester, 'status-bill');
      c.select({'7'});
      await settleTheme(tester);

      final standardSeen = seen(tester);
      expect(standardSeen.ambient, isNull, reason: 'Standard: no extension');
      expect(standardSeen.view, isNull, reason: 'Standard: no view theme');
      expect(standardSeen.shad, isNull,
          reason: 'Standard: no ShadTheme above the view (the planner '
              'derives its chrome from the Material theme)');
      final standardSurface = rgbOf(standardSeen.scheme.surface);
      // The bar is the shadcn background derived from the seed scheme,
      // which the mapping takes from `surface` (R-BarSurface).
      final standardBar = rgbOf(standardSeen.scheme.surface);

      /// The shown mode's look: the shot, the view's rect, and the pixels
      /// of [selection] within 3 per channel around table 7.
      Future<Look> check(String step, Color selection) async {
        final shot = await shoot(tester);
        final box7 = screenBox(c, '7').inflate(6);
        return (
          shot: shot,
          view: tester.getRect(find.byType(PlanEditor)),
          selectionPixels:
              shot.count(box7, (p) => distance(p, rgbOf(selection)) <= 3),
        );
      }

      // Standard, the service.
      expect(tester.getSize(byKey('service-bar')).height, 44);
      final standardService =
          await check('Standard service', standardSet.selection);
      expect(hex(standardService.shot.rgbAtOffset(surround(c))),
          hex(standardSurface),
          reason: 'premise: the surround is the seed scheme\'s surface');
      expect(hex(standardService.shot.rgbAtOffset(barBackground(tester))),
          hex(standardBar),
          reason: 'premise: the bar is the derived shadcn background of the '
              'seed theme');
      expect(overlay(tester).selectionStrokePixels, 2);
      expect(overlay(tester).paper.selection, standardSet.selection);
      expect(standardService.selectionPixels, greaterThan(200),
          reason: 'premise: 7 is outlined in the standard colour');
      final box2 = screenBox(c, '2');
      final billFill = kStatuses['Bill']!.color;
      if (light) {
        // Decided: table 2 stands in the Garden (spec D14), whose room tints
        // everything under it by 0xE5/0xFF per channel (the fill, Bill's
        // included), so Bill's 0.6 over White is read through that tint.
        expect(
            standardService.shot.count(
                box2, (p) => p == inRoom(over(billFill, billFill.a, 0xFFFFFF))),
            greaterThan(1000),
            reason: 'premise: Bill at its own 0.6 over the Garden\'s tint');
      }

      // Standard, the design.
      await tester.tap(byKey('mode-design'));
      await settleTheme(tester);
      final standardDesign =
          await check('Standard design', standardSet.selection);
      expect(hex(standardDesign.shot.rgbAtOffset(surround(c))),
          hex(standardSurface));
      expect(overlay(tester).selectionStrokePixels, 2);
      expect(standardDesign.selectionPixels, greaterThan(200));

      // POS, the design.
      await tester.tap(byKey('look-pos'));
      await settleTheme(tester);
      final posSeen = seen(tester);
      expect(posSeen.ambient, pos,
          reason: 'the extension of the app\'s $name theme, carried into '
              'the local Theme');
      expect(posSeen.view, const PlanTheme(selectionWidth: 3));
      expect(posSeen.shad, isNotNull, reason: 'a ShadTheme above the view');
      expect(posSeen.shad!.brightness, brightness);
      expect(posSeen.shad!.colorScheme.background, zinc.background);
      expect(posSeen.shad!.colorScheme, posShad.colorScheme,
          reason: 'zinc, as posShadTheme builds it');
      expect(posSeen.scheme, standardSeen.scheme,
          reason: 'the Material theme is the app\'s: no local Theme');
      expect(posSeen.ambient!.selectionWidth, isNull,
          reason: 'premise: the width is the view\'s alone (the merge)');
      final posDesign = await check('POS design', posSelection);
      expect(hex(posDesign.shot.rgbAtOffset(surround(c))),
          hex(rgbOf(pos.canvasBackground!)),
          reason: 'design: the surround is the canvas colour');
      expect(overlay(tester).selectionStrokePixels, 3,
          reason: 'design: the view\'s width over the extension');
      expect(overlay(tester).paper.selection, posSelection);
      expect(posDesign.selectionPixels,
          greaterThan(standardDesign.selectionPixels * 1.4),
          reason: 'design: 3 px of the theme\'s colour where 2 px were '
              '(${posDesign.selectionPixels} against '
              '${standardDesign.selectionPixels})');
      expect(
          posDesign.shot.count(screenBox(c, '7').inflate(6),
              (p) => distance(p, rgbOf(standardSet.selection)) <= 3),
          0,
          reason: 'design: none of the standard colour left');

      // POS, the service.
      await tester.tap(byKey('mode-service'));
      await settleTheme(tester);
      expect(tester.getSize(byKey('service-bar')).height, 52);
      expect(
          c.canvasRect.value!.top, tester.getRect(byKey('service-bar')).bottom,
          reason: 'the canvas starts under the 52 px bar');
      final posService = await check('POS service', posSelection);
      expect(hex(posService.shot.rgbAtOffset(barBackground(tester))),
          hex(rgbOf(zinc.background)),
          reason: 'DL-S1 the bar: zinc\'s background, not the derived one');
      expect(rgbOf(zinc.background), isNot(standardBar),
          reason: 'DL-S1 premise: the two looks\' bars differ');
      expect(hex(posService.shot.rgbAtOffset(surround(c))),
          hex(rgbOf(pos.canvasBackground!)),
          reason: 'service: the surround is the canvas colour');
      expect(overlay(tester).selectionStrokePixels, 3);
      expect(overlay(tester).paper.selection, posSelection);
      expect(posService.selectionPixels,
          greaterThan(standardService.selectionPixels * 1.4),
          reason: 'service: 3 px of the theme\'s colour where 2 px were '
              '(${posService.selectionPixels} against '
              '${standardService.selectionPixels})');
      if (light) {
        // The POS look's fill opacity is 0.8 (the plan's), not read back.
        final drawn = billFill.a * 0.8;
        // Decided: over the Garden's tint, as above.
        expect(
            posService.shot.count(screenBox(c, '2'),
                (p) => p == inRoom(over(billFill, drawn, 0xFFFFFF))),
            greaterThan(1000),
            reason: 'Bill at 0.6 x 0.8 over the Garden\'s tint');
      }
      final caption = pos.statusCaptionStyle!;
      expect((
        caption.fontSize,
        caption.fontWeight,
        caption.fontFamily
      ), (
        12.0,
        FontWeight.bold,
        'Roboto'
      ), reason: 'the caption style the view resolves');

      // Standard again, switched in the design: today's pixels, in both
      // modes. (Switched in the service, the bar's 8 px go and the plan
      // moves up with the canvas, as on any host layout change: S-10.)
      await tester.tap(byKey('mode-design'));
      await settleTheme(tester);
      await tester.tap(byKey('look-standard'));
      await settleTheme(tester);
      expect(seen(tester).ambient, isNull);
      expect(seen(tester).view, isNull);
      final againDesign =
          await check('Standard again, design', standardSet.selection);
      expect(againDesign.view, standardDesign.view);
      expect(againDesign.shot.region(againDesign.view),
          standardDesign.shot.region(standardDesign.view),
          reason: 'design: today\'s pixels again');
      await tester.tap(byKey('mode-service'));
      await settleTheme(tester);
      expect(tester.getSize(byKey('service-bar')).height, 44);
      final againService =
          await check('Standard again, service', standardSet.selection);
      expect(againService.view, standardService.view);
      expect(againService.shot.region(againService.view),
          standardService.shot.region(standardService.view),
          reason: 'service: today\'s pixels again');

      // The caption's size, zoomed in on 2 in the service: the caption's
      // ink grows from 11 to 12 px glyphs (the test font draws each glyph
      // a full em; its weight is the resolved style's, above).
      final centre =
          c.unitDetails.singleWhere((d) => d.unit.label == '2').center!;
      c.centerOn(centre, scale: c.cameraValue.value.scale * 3);
      await settleTheme(tester);
      bool ink(int p) => light
          ? [16, 8, 0].every((s) => ((p >> s) & 0xFF) < 120)
          : [16, 8, 0].every((s) => ((p >> s) & 0xFF) > 200);
      final standardInk = (await shoot(tester)).count(captionBand(c, '2'), ink);
      await tester.tap(byKey('look-pos'));
      await settleTheme(tester);
      final posInk = (await shoot(tester)).count(captionBand(c, '2'), ink);
      // 4 glyphs of 12 x 12 against 4 of 11 x 11: 92 pixels more.
      expect(posInk - standardInk, greaterThanOrEqualTo(80),
          reason: 'the 12 px caption ($posInk against $standardInk)');
    });
  }

  testWidgets('DL3 the look switch in German and Turkish', (tester) async {
    await pumpDemo(tester);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.byTooltip('Look'), findsOneWidget);
    await tester.tap(byKey('lang-de'));
    await settleTheme(tester);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Kasse'), findsOneWidget);
    expect(find.byTooltip('Aussehen'), findsOneWidget);
    await tester.tap(byKey('lang-tr'));
    await settleTheme(tester);
    expect(find.text('Standart'), findsOneWidget);
    expect(find.text('Kasa'), findsOneWidget);
    expect(find.byTooltip('Görünüm'), findsOneWidget);
    await tester.tap(byKey('look-pos'));
    await settleTheme(tester);
    expect(seen(tester).ambient, kPosPlanLight,
        reason: 'the switch works in any language');
  });
}
