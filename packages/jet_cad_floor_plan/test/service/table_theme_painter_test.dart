// Host embedding API spec, Slice 3, T-1's status, groups and focus rows,
// T-3, T-4 (Slice 3 plan Task 3): the selection mode's three painters
// under a `FloorPlanTheme`, built directly with the theme as a notifier, as
// `ServiceView` builds them. Every style value is derived when a painter
// rebuilds, never per frame: the counters' themed siblings (SP1, TG-L9,
// FP3) pass the same objects and build nothing across frames (invariant
// 7, M-H31). Each field is read back once, in pixels (a `PictureRecorder`
// under `runAsync`) or in what reaches a recording canvas.
//
// Fixtures as the painters' own tests: tables turned, mirrored and 40 m
// off the origin; the groups `{12, 3, 7}` placed out of handle order;
// cameras off identity. The themes' values are none of today's: colours
// none of the palette's, widths and sizes not 2, 150, 4, 5/2 or 11,
// asymmetric chip padding, opacities not 0, 0.6 or 1. Expected colours are
// computed here (straight alpha over the paper), never read from the code.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart'
    show Color, EdgeInsets, FontWeight, TextStyle;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_theme.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/service/table_focus_painter.dart';
import 'package:jet_cad_floor_plan/src/service/table_group_painter.dart';
import 'package:jet_cad_floor_plan/src/service/table_picker.dart';
import 'package:jet_cad_floor_plan/src/service/table_status_painter.dart';

import '../host/zone_fixture.dart' show TestQuad, quadsNumbered, quadsOf;
import 'table_focus_painter_test.dart' as fp;
import 'table_group_painter_test.dart' as gp;
import 'table_status_painter_test.dart' show SpyCanvas, cameraOn, rowOfTables;

/// A theme with every field set to a value that is not today's (Slice 3
/// plan, Global constraints, Fixtures).
const FloorPlanTheme fullTheme = FloorPlanTheme(
  statusCaptionStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.5,
  groupFrameColor: frameColour,
  groupFrameWidth: 3,
  groupFrameMargin: 300,
  groupChipColor: chipColour,
  groupChipTextStyle: TextStyle(fontSize: 13),
  groupChipRadius: 8,
  groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4),
  selectionOnLight: Color(0xFFD81B60),
  selectionOnDark: Color(0xFFFFD54F),
  selectionWidth: 4,
  focusVeilColor: veilColour,
  focusVeilOpacity: 0.35,
  canvasBackground: Color(0xFF263238),
  serviceBarHeight: 60,
);

const Color frameColour = Color(0xFF00897B);
const Color chipColour = Color(0xFF3949AB);
const Color veilColour = Color(0xFF6D4C41);

/// The demo's translucent Bill, a dark opaque and a light opaque fill.
const Color bill = Color(0x99E53935);
const Color darkFill = Color(0xFF1B1B1B);
const Color lightFill = Color(0xFFFFE082);

const int white = 0xFFFFFFFF;
const int blueprint = 0xFF1F3A5F;

/// `0xRRGGBB` of [colour] at [alpha] (straight) over [under] (`0xRRGGBB`),
/// rounded per channel: the test's own composite.
int composite(Color colour, double alpha, int under) {
  final argb = colour.toARGB32();
  var rgb = 0;
  for (final shift in const [16, 8, 0]) {
    final s = (argb >> shift) & 0xFF, u = (under >> shift) & 0xFF;
    rgb |= (alpha * s + (1 - alpha) * u).round() << shift;
  }
  return rgb;
}

int channelDistance(int a, int b) => [16, 8, 0]
    .map((s) => (((a >> s) & 0xFF) - ((b >> s) & 0xFF)).abs())
    .reduce(math.max);

String hex(int rgb) => '0x${rgb.toRadixString(16).padLeft(6, '0')}';

/// [painter] over a [paper]-filled canvas of [size], read back.
Future<ByteData> render(WidgetTester tester, CustomPainter painter, int paper,
        ui.Size size) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(Color(paper), ui.BlendMode.src);
      painter.paint(canvas, size);
      final image = await recorder
          .endRecording()
          .toImage(size.width.toInt(), size.height.toInt());
      final data = await image.toByteData();
      image.dispose();
      return data!;
    }))!;

int rgbAt(ByteData bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return (bytes.getUint8(i) << 16) |
      (bytes.getUint8(i + 1) << 8) |
      bytes.getUint8(i + 2);
}

/// A status painter over [doc] that follows [theme], as `ServiceView`
/// builds it: the theme in the repaint merge and the rebuild key.
TableStatusPainter themedStatus(
    DraftDocument doc,
    ValueNotifier<ViewportTransform> camera,
    ValueNotifier<Map<String, TableStatus>> statuses,
    ValueNotifier<FloorPlanTheme?> theme,
    {ValueNotifier<int>? paper,
    ValueNotifier<Map<String, TableGroup>>? groups,
    ValueNotifier<Map<String, TableStatus>>? groupStatuses}) {
  final p = paper ?? ValueNotifier<int>(white);
  final g = groups ?? ValueNotifier<Map<String, TableGroup>>(const {});
  final gs = groupStatuses ?? ValueNotifier<Map<String, TableStatus>>(const {});
  return TableStatusPainter(
      document: doc,
      camera: camera,
      statuses: statuses,
      tableGroups: g,
      groupStatuses: gs,
      paper: p,
      theme: theme,
      repaint: Listenable.merge([camera, statuses, g, gs, p, theme]));
}

/// A group painter of [layer] over [doc] that follows [theme] and, when
/// given, [focus].
TableGroupPainter themedGroups(
    TableGroupLayer layer,
    DraftDocument doc,
    ValueNotifier<ViewportTransform> camera,
    ValueNotifier<Map<String, TableGroup>> groups,
    ValueNotifier<FloorPlanTheme?> theme,
    {ValueNotifier<int>? paper,
    ValueNotifier<Set<String>?>? focus,
    TablePicker? picker}) {
  final p = paper ?? ValueNotifier<int>(white);
  return TableGroupPainter(
      layer: layer,
      document: doc,
      picker: picker ?? TablePicker(doc),
      camera: camera,
      groups: groups,
      paper: p,
      tableFocus: focus,
      theme: theme,
      repaint: Listenable.merge(
          [camera, groups, p, theme, if (focus != null) focus]));
}

/// A veil painter over [doc] that follows [theme].
TableFocusPainter themedVeil(
        DraftDocument doc,
        ValueNotifier<ViewportTransform> camera,
        ValueNotifier<Set<String>?> focus,
        ValueNotifier<int> paper,
        ValueNotifier<FloorPlanTheme?> theme) =>
    TableFocusPainter(
        document: doc,
        camera: camera,
        focus: focus,
        paper: paper,
        theme: theme,
        repaint: Listenable.merge([camera, focus, paper, theme]));

SpyCanvas statusFrame(TableStatusPainter p, [ui.Size size = gp.kSize]) {
  final spy = SpyCanvas();
  p.paint(spy, size);
  return spy;
}

/// One table (number 1) at screen (400, 300), [scale] px/mm: the status
/// painter's single-table fixture, turned and mirrored 40 m off the origin.
({DraftDocument doc, ValueNotifier<ViewportTransform> camera}) oneTable(
    double scale) {
  final doc = rowOfTables(1);
  final at = cameraOn(doc).value.worldToScreenMatrix;
  // cameraOn puts the table's top centre at (400, 300) at 0.1 px/mm.
  final cx = (400 - at.e) / 0.1, cy = (at.f - 300) / 0.1;
  return (
    doc: doc,
    camera: ValueNotifier(ViewportTransform(
        worldToScreenMatrix: Transform2(
            scale, 0, 0, -scale, 400 - scale * cx, 300 + scale * cy)))
  );
}

/// The caption's box on the canvas: its translation and its paragraph's
/// size, one pixel in from its top and bottom.
ui.Rect captionBox(SpyCanvas spy) {
  final p = spy.paragraphs.single;
  final t = spy.translations.single;
  final inset = (p.width - p.maxIntrinsicWidth) / 2;
  return ui.Rect.fromLTRB(t.dx + inset, t.dy + 1,
      t.dx + inset + p.maxIntrinsicWidth, t.dy + p.height - 1);
}

/// The [box]'s darkest (smallest largest channel) and brightest (largest
/// smallest channel) pixels in [bytes] of [width].
(int, int) glyphs(ByteData bytes, int width, ui.Rect box) {
  var darkest = 0, brightest = 0, dMax = 256, bMin = -1;
  for (var y = box.top.ceil(); y < box.bottom.floor(); y++) {
    for (var x = box.left.ceil(); x < box.right.floor(); x++) {
      final rgb = rgbAt(bytes, width, x, y);
      final ch = [(rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF];
      final hi = ch.reduce(math.max), lo = ch.reduce(math.min);
      if (hi < dMax) (dMax, darkest) = (hi, rgb);
      if (lo > bMin) (bMin, brightest) = (lo, rgb);
    }
  }
  return (darkest, brightest);
}

/// The glyphs of one status caption [caption] in [colour] on table 1 over
/// White at 0.2 px/mm under [theme]. The premise: without a caption, every
/// pixel of the caption's box is the fill (the box lies inside the top).
Future<(int, int)> captionGlyphs(
    WidgetTester tester, Color colour, FloorPlanTheme? theme,
    {String caption = 'Bill'}) async {
  const size = ui.Size(800, 600);
  final f = oneTable(0.2);
  final statuses = ValueNotifier<Map<String, TableStatus>>(
      {'1': TableStatus(color: colour, caption: caption)});
  final painter = themedStatus(f.doc, f.camera, statuses, ValueNotifier(theme));
  final box = captionBox(statusFrame(painter, size));
  final bare = themedStatus(f.doc, f.camera,
      ValueNotifier({'1': TableStatus(color: colour)}), ValueNotifier(theme));
  final fill = await render(tester, bare, white, size);
  final drawn = composite(colour.withValues(alpha: 1),
      colour.a * (theme?.statusFillOpacity ?? 1), 0xFFFFFF);
  for (var y = box.top.ceil(); y < box.bottom.floor(); y++) {
    for (var x = box.left.ceil(); x < box.right.floor(); x++) {
      expect(
          channelDistance(rgbAt(fill, 800, x, y), drawn), lessThanOrEqualTo(1),
          reason: 'premise: ($x, $y) inside the fill');
    }
  }
  return glyphs(await render(tester, painter, white, size), 800, box);
}

/// The world corners of the boxes of the tables numbered [numbers] in
/// [doc] (the group painters' `cornersOf`).
List<(double, double)> cornersOfAll(DraftDocument doc, List<String> numbers) =>
    [for (final n in numbers) ...gp.cornersOf(doc, n)];

/// The frame bounds' top line at their centre x for [corners] grown by
/// [margin]: the chip's anchor (fixes X3).
(double, double) anchorOf(List<(double, double)> corners, double margin) {
  final xs = [for (final c in corners) c.$1];
  final ys = [for (final c in corners) c.$2];
  return (
    (xs.reduce(math.min) + xs.reduce(math.max)) / 2,
    ys.reduce(math.max) + margin
  );
}

void main() {
  group('invariant 7 with a theme (M-H31)', () {
    test(
        'SP1 themed: N = 60 statused tables under a full theme: after '
        'warm-up every frame passes the same objects, the camera moving; '
        'nothing built, nothing rebuilt', () {
      final doc = rowOfTables(60);
      final camera = cameraOn(doc);
      final statuses = ValueNotifier<Map<String, TableStatus>>({
        for (var i = 1; i <= 60; i++)
          '$i': TableStatus(
              color: Color(0xFF000000 | (i * 0x030507)),
              caption: i.isEven ? 'Bill' : null),
      });
      final painter =
          themedStatus(doc, camera, statuses, ValueNotifier(fullTheme));
      const size = ui.Size(1600, 1200);
      for (var i = 0; i < 3; i++) {
        statusFrame(painter, size);
      }
      final made = painter.debugAllocations;
      final rebuilt = painter.debugRebuilds;
      final first = statusFrame(painter, size);
      final reference = first.seen;
      expect(reference.whereType<ui.Path>(), hasLength(60));
      expect(first.paints.first.color.a, closeTo(0.5, 1e-9),
          reason: 'premise: the theme is in force (opacity 0.5)');
      expect(first.paragraphs, isNotEmpty);
      for (var i = 0; i < 10; i++) {
        camera.value = ViewportTransform(
            worldToScreenMatrix: Transform2(0.09 + 0.004 * i, 0, 0,
                -0.09 - 0.004 * i, -3500.5 + 13 * i, 2700.25 - 7 * i));
        statusFrame(painter, size);
      }
      camera.value = cameraOn(doc).value;
      final again = statusFrame(painter, size).seen;
      expect(again.length, reference.length);
      for (var i = 0; i < again.length; i++) {
        expect(identical(again[i], reference[i]), isTrue, reason: 'item $i');
      }
      expect(painter.debugAllocations, made, reason: 'nothing new per frame');
      expect(painter.debugRebuilds, rebuilt, reason: 'no rebuild per frame');
    });

    test(
        'TG-L9 themed: ten frames panning under a full theme: the frames, '
        'the chips and the status painter build nothing and pass the same '
        'objects', () {
      final doc = gp.groupedPlan(duplicate: true);
      final camera = ValueNotifier(gp.cameraAt(0.1));
      final theme = ValueNotifier<FloorPlanTheme?>(fullTheme);
      final groups = ValueNotifier<Map<String, TableGroup>>({
        'G7': gp.tg({'12', '3', '7'}),
        'G2': gp.tg({'20', '9', '5'}),
      });
      final focus = ValueNotifier<Set<String>?>({'20'});
      final picker = TablePicker(doc);
      final frames = themedGroups(
          TableGroupLayer.frames, doc, camera, groups, theme,
          focus: focus, picker: picker);
      final chips = themedGroups(
          TableGroupLayer.chips, doc, camera, groups, theme,
          focus: focus, picker: picker);
      final status = themedStatus(
          doc,
          camera,
          ValueNotifier({'20': TableStatus(color: gp.eating, caption: 'Eat')}),
          theme,
          groups: groups,
          groupStatuses:
              ValueNotifier({'G7': TableStatus(color: bill, caption: 'Bill')}));
      List<Object> seenOf(CustomPainter p) =>
          p is TableStatusPainter ? statusFrame(p).seen : gp.frame(p).seen;
      final painters = <CustomPainter>[frames, chips, status];
      for (final p in painters) {
        for (var i = 0; i < 3; i++) {
          seenOf(p);
        }
      }
      List<int> made() => [
            frames.debugAllocations,
            chips.debugAllocations,
            status.debugAllocations
          ];
      List<int> rebuilt() =>
          [frames.debugRebuilds, chips.debugRebuilds, status.debugRebuilds];
      final made0 = made(), rebuilt0 = rebuilt();
      final reference = [for (final p in painters) seenOf(p)];
      expect(reference[0].whereType<ui.Path>(), hasLength(1));
      expect(reference[1].whereType<ui.Paragraph>(), hasLength(1));
      expect(reference[1].whereType<ui.RRect>(), hasLength(2),
          reason: 'G7 faded (focus on 20): its chip and the veil over it');
      expect(reference[2].whereType<ui.Paragraph>(), hasLength(2));
      final spy = gp.frame(frames);
      expect(spy.paints.single.color.toARGB32() & 0xFFFFFF, 0x00897B,
          reason: 'premise: the theme is in force');
      for (var i = 0; i < 10; i++) {
        camera.value = ViewportTransform(
            worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1,
                500 - 0.1 * 42600 + 17.5 * i, 400 - 0.1 * 26500 - 9.25 * i));
        for (final p in painters) {
          seenOf(p);
        }
      }
      camera.value = gp.cameraAt(0.1);
      final again = [for (final p in painters) seenOf(p)];
      for (var k = 0; k < 3; k++) {
        expect(again[k].length, reference[k].length);
        for (var i = 0; i < again[k].length; i++) {
          expect(identical(again[k][i], reference[k][i]), isTrue,
              reason: 'painter $k item $i');
        }
      }
      expect(made(), made0, reason: 'nothing new per frame');
      expect(rebuilt(), rebuilt0, reason: 'no rebuild per frame');
    });

    test(
        'FP3 themed: N = 60 tables, half focused, under a host veil colour '
        'and opacity: every frame passes the same matrix, path and paint, '
        'the camera panning and zooming; nothing built, nothing recoloured',
        () {
      final doc = rowOfTables(60);
      final first = quadsOf(doc, (t) => t.number == '1').single;
      final camera = ValueNotifier(fp.cameraOn(first));
      final focus =
          ValueNotifier<Set<String>?>({for (var i = 1; i <= 30; i++) '$i'});
      final painter = themedVeil(doc, camera, focus,
          ValueNotifier<int>(fp.kPaper), ValueNotifier(fullTheme));
      for (var i = 0; i < 3; i++) {
        fp.spyFrame(painter);
      }
      final made = painter.debugAllocations;
      final rebuilt = painter.debugRebuilds;
      final recoloured = painter.debugRecolours;
      final reference = fp.spyFrame(painter).seen;
      expect(reference, hasLength(3));
      final paint = reference[2] as ui.Paint;
      expect(paint.color.toARGB32() & 0xFFFFFF, 0x6D4C41,
          reason: 'premise: the theme is in force');
      final colour = paint.color;
      for (var i = 0; i < 10; i++) {
        camera.value = ViewportTransform(
            worldToScreenMatrix: Transform2(0.37 - 0.03 * i, 0, 0,
                -0.37 + 0.03 * i, -14700.5 + 31 * i, -9800.25 + 17 * i));
        final seen = fp.spyFrame(painter).seen;
        expect(seen, hasLength(3));
        for (var k = 0; k < 3; k++) {
          expect(identical(seen[k], reference[k]), isTrue,
              reason: 'frame $i item $k');
        }
        expect(paint.color.toARGB32(), colour.toARGB32(),
            reason: 'frame $i: the theme\'s veil');
      }
      expect(painter.debugAllocations, made, reason: 'nothing new per frame');
      expect(painter.debugRebuilds, rebuilt);
      expect(painter.debugRecolours, recoloured,
          reason: 'the colour is derived when the theme or paper changes only');
    });
  });

  group('status (T-1)', () {
    testWidgets(
        'M-H33(opacity twice): Bill at statusFillOpacity 0.5 draws alpha '
        '0x4D, over White the test\'s composite at 0.3; a second status '
        'drawn after an equal theme keeps 0x4D (no compounding)',
        (tester) async {
      final f = oneTable(0.2);
      final theme = ValueNotifier<FloorPlanTheme?>(
          const FloorPlanTheme(statusFillOpacity: 0.5));
      final statuses = ValueNotifier<Map<String, TableStatus>>(
          {'1': TableStatus(color: bill)});
      final painter = themedStatus(f.doc, f.camera, statuses, theme);
      const size = ui.Size(800, 600);
      final spy = statusFrame(painter, size);
      expect(spy.paints.single.color.toARGB32() >> 24, 0x4D,
          reason: 'round(0.6 x 0.5 x 255) = 77');
      expect(spy.paints.single.color.toARGB32() & 0xFFFFFF, 0xE53935);
      final bytes = await render(tester, painter, white, size);
      // The top's centre (the camera's (400, 300)) and two pixels near it.
      final want = composite(bill, 0.3, 0xFFFFFF);
      for (final (x, y) in const [(400, 300), (380, 290), (415, 312)]) {
        expect(channelDistance(rgbAt(bytes, 800, x, y), want),
            lessThanOrEqualTo(1),
            reason: '($x, $y): ${hex(rgbAt(bytes, 800, x, y))}, '
                'want ${hex(want)}');
      }
      expect(channelDistance(want, composite(bill, 0.15, 0xFFFFFF)),
          greaterThan(15),
          reason: 'premise: twice reads apart');

      // An equal theme (the view's notifier keeps the value it holds),
      // then a second status: both 0x4D.
      theme.value = const FloorPlanTheme(statusFillOpacity: 0.5);
      statuses.value = {
        '1': TableStatus(color: bill),
        '2': TableStatus(color: bill)
      };
      statusFrame(painter, size);
      final two = rowOfTables(2);
      final both = themedStatus(two, cameraOn(two), statuses, theme);
      for (var i = 0; i < 3; i++) {
        final paints = statusFrame(both, size).paints;
        expect(paints, hasLength(2));
        for (final p in paints) {
          expect(p.color.toARGB32() >> 24, 0x4D, reason: 'frame $i');
        }
      }
      theme.value = const FloorPlanTheme(statusFillOpacity: 0.25);
      statusFrame(both, size);
      theme.value = const FloorPlanTheme(statusFillOpacity: 0.5);
      for (final p in statusFrame(both, size).paints) {
        expect(p.color.toARGB32() >> 24, 0x4D,
            reason: 'back to 0.5 after 0.25: not compounded');
      }
    });

    testWidgets(
        'M-H33(null caption colour): a 14 px caption style with no colour: '
        'the dark fill 0xFF1B1B1B on White takes white ink, the light fill '
        '0xFFFFE082 dark ink', (tester) async {
      const style = FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 14));
      final (_, onDark) = await captionGlyphs(tester, darkFill, style);
      expect(hex(onDark), hex(0xFFFFFF),
          reason: 'glyphs lighter than the fill: white ink');
      final (onLight, _) = await captionGlyphs(tester, lightFill, style);
      expect(hex(onLight), hex(rgbOf(kStatusCaptionOnLight)),
          reason: 'dark glyphs on the light fill');
    });

    testWidgets(
        'T3-c: the caption\'s ink is taken on the drawn colour: 0xFF303030 '
        'at statusFillOpacity 0.2 on White is light, dark glyphs; at 1.0 '
        'white glyphs (S-6)', (tester) async {
      const grey = Color(0xFF303030);
      final (dimmed, _) = await captionGlyphs(
          tester, grey, const FloorPlanTheme(statusFillOpacity: 0.2));
      expect(hex(dimmed), hex(rgbOf(kStatusCaptionOnLight)));
      final (_, full) = await captionGlyphs(
          tester, grey, const FloorPlanTheme(statusFillOpacity: 1));
      expect(hex(full), hex(0xFFFFFF));
      expect(foregroundFor(0x303030), 0xFFFFFF,
          reason: 'premise: the undimmed colour takes white ink');
      expect(foregroundFor(composite(grey, 0.2, 0xFFFFFF)), 0x000000,
          reason: 'premise: the drawn one black');
    });

    testWidgets(
        'S-6 on a dark paper (K12): 0xFFFFE082 at statusFillOpacity 0.3 over '
        'Blueprint is dark, so the caption takes white ink', (tester) async {
      const size = ui.Size(800, 600);
      final f = oneTable(0.2);
      final painter = themedStatus(
          f.doc,
          f.camera,
          ValueNotifier({'1': TableStatus(color: lightFill, caption: 'Bill')}),
          ValueNotifier(const FloorPlanTheme(statusFillOpacity: 0.3)),
          paper: ValueNotifier(blueprint));
      final box = captionBox(statusFrame(painter, size));
      final (_, brightest) =
          glyphs(await render(tester, painter, blueprint, size), 800, box);
      expect(hex(brightest), hex(0xFFFFFF));
      expect(foregroundFor(composite(lightFill, 0.3, blueprint)), 0xFFFFFF,
          reason: 'premise: drawn over Blueprint it is dark');
      expect(foregroundFor(composite(lightFill, 0.3, 0xFFFFFF)), 0x000000,
          reason: 'premise: over White it would be light');
    });

    test(
        'a themed caption is centred on its anchor as today\'s is (K14): '
        'its glyphs\' midpoint is the paragraph\'s middle', () {
      final f = oneTable(0.2);
      for (final theme in const [
        null,
        FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 14)),
      ]) {
        final p = statusFrame(themedStatus(
                f.doc,
                f.camera,
                ValueNotifier(
                    {'1': TableStatus(color: lightFill, caption: 'Bill')}),
                ValueNotifier(theme)))
            .paragraphs
            .single;
        final boxes = p.getBoxesForRange(0, 4);
        expect(p.width - p.maxIntrinsicWidth, greaterThan(2),
            reason: 'premise: the paragraph is wider than its text');
        expect((boxes.first.left + boxes.last.right) / 2,
            closeTo(p.width / 2, 0.5),
            reason: '$theme');
      }
    });

    test(
        'a chip style leaves the caption as today (K17): groupChipTextStyle '
        '16 px alone, the caption is the 11 px paragraph', () {
      final f = oneTable(0.2);
      ui.Paragraph captionUnder(FloorPlanTheme? theme) =>
          statusFrame(themedStatus(
                  f.doc,
                  f.camera,
                  ValueNotifier(
                      {'1': TableStatus(color: bill, caption: 'Bill')}),
                  ValueNotifier(theme)))
              .paragraphs
              .single;
      final today = captionUnder(null);
      final chipStyled = captionUnder(
          const FloorPlanTheme(groupChipTextStyle: TextStyle(fontSize: 16)));
      expect(chipStyled.height, today.height);
      expect(chipStyled.maxIntrinsicWidth, today.maxIntrinsicWidth);
      expect(
          captionUnder(const FloorPlanTheme(
                  statusCaptionStyle: TextStyle(fontSize: 16)))
              .height,
          greaterThan(today.height),
          reason: 'premise: 16 px reads apart');
    });

    testWidgets(
        'a caption colour is honoured over the automatic ink; 14 px bold is '
        'the paragraph a 14 px bold style lays out, taller than 11 px, with '
        'more glyph rows', (tester) async {
      const teal = Color(0xFF00897B);
      final (_, plainBright) = await captionGlyphs(tester, lightFill, null);
      expect(plainBright, isNot(rgbOf(teal)), reason: 'premise');
      final coloured = await captionGlyphs(tester, lightFill,
          const FloorPlanTheme(statusCaptionStyle: TextStyle(color: teal)));
      expect(hex(coloured.$1), hex(rgbOf(teal)),
          reason:
              'the darkest glyph pixel is the host\'s colour, not 0x202020');

      final f = oneTable(0.2);
      ui.Paragraph captionUnder(FloorPlanTheme? theme) => statusFrame(
              themedStatus(
                  f.doc,
                  f.camera,
                  ValueNotifier(
                      {'1': TableStatus(color: lightFill, caption: 'Bill')}),
                  ValueNotifier(theme)),
              const ui.Size(800, 600))
          .paragraphs
          .single;
      final plain = captionUnder(null);
      final bold = captionUnder(fullTheme);
      // The test's own paragraph for 14 px bold.
      final want = (ui.ParagraphBuilder(
              ui.ParagraphStyle(fontSize: 14, fontWeight: FontWeight.bold))
            ..pushStyle(ui.TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
            ..addText('Bill'))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 120));
      expect(bold.height, want.height);
      expect(bold.maxIntrinsicWidth, want.maxIntrinsicWidth);
      expect(bold.height, greaterThan(plain.height));
      expect(plain.height, lessThan(14), reason: 'premise: today 11 px');

      // Glyph rows: rows of the caption box holding an ink pixel.
      /// The caption box's rows holding an ink pixel, and its ink summed
      /// (each pixel's distance from the fill).
      Future<(int, int)> inkOf(FloorPlanTheme? theme) async {
        final painter = themedStatus(
            f.doc,
            f.camera,
            ValueNotifier(
                {'1': TableStatus(color: lightFill, caption: 'Bill')}),
            ValueNotifier(theme));
        final spy = statusFrame(painter, const ui.Size(800, 600));
        final p = spy.paragraphs.single;
        final t = spy.translations.single;
        final bytes =
            await render(tester, painter, white, const ui.Size(800, 600));
        var rows = 0, ink = 0;
        for (var y = t.dy.floor(); y < (t.dy + p.height).ceil(); y++) {
          var inked = false;
          for (var x = t.dx.floor(); x < (t.dx + p.width).ceil(); x++) {
            final d =
                channelDistance(rgbAt(bytes, 800, x, y), rgbOf(lightFill));
            // Summed: a bold glyph's edges ink unlike a regular one's.
            ink += d;
            if (d > 60) inked = true;
          }
          if (inked) rows++;
        }
        return (rows, ink);
      }

      // The fill at full opacity in all three: only the caption differs.
      final (boldRows, boldInk) = await inkOf(
          FloorPlanTheme(statusCaptionStyle: fullTheme.statusCaptionStyle));
      final (plainRows, _) = await inkOf(null);
      final (regularRows, regularInk) = await inkOf(
          const FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 14)));
      expect(boldRows, greaterThan(plainRows), reason: '14 px over 11 px');
      expect(regularRows, greaterThan(plainRows), reason: '14 px alone');
      // The engine's synthetic bold inks more on Linux and spreads the ink
      // differently on macOS (176,420 regular against 175,568 bold there),
      // so only the difference is the platform's own.
      expect(boldInk, isNot(regularInk),
          reason: 'the weight reaches the caption: bold renders unlike '
              'regular');
    });

    test(
        'the caption sits at least the resolved font size below the number: '
        '14 px themed against 11 px, both clamped at 0.05 px/mm', () {
      final f = oneTable(0.05);
      ui.Offset at(FloorPlanTheme? theme) => statusFrame(
              themedStatus(
                  f.doc,
                  f.camera,
                  ValueNotifier({'1': TableStatus(color: bill, caption: 'B')}),
                  ValueNotifier(theme)),
              const ui.Size(800, 600))
          .translations
          .single;
      final plain = at(null);
      final themed =
          at(const FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 14)));
      expect(themed.dy - plain.dy, closeTo(14 - kStatusCaptionSize, 1e-9));
    });

    testWidgets(
        'T-4, S-2: a fontFamily the host loaded is honoured: the caption '
        'measures as that family, not as the default; no family is today\'s',
        (tester) async {
      const family = 'ThemeTestFace';
      final bytes = File('lib/fonts/Roboto-Regular.ttf').readAsBytesSync();
      await tester.runAsync(() => (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load());
      final f = oneTable(0.2);
      ui.Paragraph captionUnder(FloorPlanTheme? theme) => statusFrame(
              themedStatus(
                  f.doc,
                  f.camera,
                  ValueNotifier(
                      {'1': TableStatus(color: lightFill, caption: 'Bill 12')}),
                  ValueNotifier(theme)),
              const ui.Size(800, 600))
          .paragraphs
          .single;
      ui.Paragraph reference(String? fontFamily) => (ui.ParagraphBuilder(
              ui.ParagraphStyle(fontSize: 11, fontFamily: fontFamily))
            ..pushStyle(ui.TextStyle(fontSize: 11, fontFamily: fontFamily))
            ..addText('Bill 12'))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 120));
      final loaded = reference(family).maxIntrinsicWidth;
      final fallback = reference(null).maxIntrinsicWidth;
      expect(loaded, isNot(closeTo(fallback, 1)),
          reason: 'premise: the faces measure apart');
      expect(captionUnder(null).maxIntrinsicWidth, fallback,
          reason: 'no family: today\'s default');
      expect(
          captionUnder(const FloorPlanTheme(
                  statusCaptionStyle: TextStyle(fontFamily: family)))
              .maxIntrinsicWidth,
          loaded);
      // The chip honours its own style's family too.
      final doc = gp.groupedPlan();
      final chips = themedGroups(
          TableGroupLayer.chips,
          doc,
          ValueNotifier(gp.cameraAt(0.08)),
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'}, label: 'Bill 12')
          }),
          ValueNotifier(const FloorPlanTheme(
              groupChipTextStyle: TextStyle(fontFamily: family))));
      final chip = gp.frame(chips).paragraphs.single.maxIntrinsicWidth;
      expect(chip, moreOrLessEquals(reference(family).maxIntrinsicWidth));
      expect(chip, isNot(moreOrLessEquals(fallback, epsilon: 1)));
    });

    test(
        'T3-a: the caption style 11 -> 16 px, nothing else changed: the '
        'drawn caption is a new, taller paragraph; the chip\'s likewise', () {
      final f = oneTable(0.2);
      final theme = ValueNotifier<FloorPlanTheme?>(
          const FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 11)));
      final painter = themedStatus(
          f.doc,
          f.camera,
          ValueNotifier({'1': TableStatus(color: bill, caption: 'Bill')}),
          theme);
      final small = statusFrame(painter).paragraphs.single;
      theme.value =
          const FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 16));
      final large = statusFrame(painter).paragraphs.single;
      expect(large.height, greaterThan(small.height));

      final chipTheme = ValueNotifier<FloorPlanTheme?>(
          const FloorPlanTheme(groupChipTextStyle: TextStyle(fontSize: 11)));
      final chips = themedGroups(
          TableGroupLayer.chips,
          gp.groupedPlan(),
          ValueNotifier(gp.cameraAt(0.08)),
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'})
          }),
          chipTheme);
      final chip = gp.frame(chips).paragraphs.single;
      chipTheme.value =
          const FloorPlanTheme(groupChipTextStyle: TextStyle(fontSize: 16));
      expect(
          gp.frame(chips).paragraphs.single.height, greaterThan(chip.height));
    });
  });

  group('groups (T-1)', () {
    test(
        'the frame strokes 3 screen px at 0.125 and 0.04 px/mm in the '
        'theme\'s colour; with no theme 2 px in gripMove', () {
      final doc = gp.groupedPlan();
      final camera = ValueNotifier(gp.cameraAt(0.125));
      final theme = ValueNotifier<FloorPlanTheme?>(fullTheme);
      final frames = themedGroups(
          TableGroupLayer.frames,
          doc,
          camera,
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'})
          }),
          theme);
      for (final scale in [0.125, 0.04]) {
        camera.value = gp.cameraAt(scale);
        final spy = gp.frame(frames);
        expect(spy.strokeWidths.single, closeTo(3 / scale, 1e-9));
        expect(spy.paints.single.color.toARGB32(), frameColour.toARGB32());
      }
      theme.value = null;
      final spy = gp.frame(frames);
      expect(spy.strokeWidths.single, closeTo(2 / 0.04, 1e-9));
      expect(spy.paints.single.color.toARGB32(), 0xFF7A3FD1);
    });

    test(
        'the margin 300 mm (TG-L4\'s geometry): every member corner pushed '
        'out by less than 300 mm is inside, the extreme ones by 330 mm are '
        'not', () {
      final doc = gp.groupedPlan();
      final frames = themedGroups(
          TableGroupLayer.frames,
          doc,
          ValueNotifier(gp.cameraAt(0.05)),
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'})
          }),
          ValueNotifier(const FloorPlanTheme(groupFrameMargin: 300)));
      final path = gp.frame(frames).paths.single;
      final corners = cornersOfAll(doc, ['12', '3', '7']);
      const m = 300.0;
      for (final (x, y) in corners) {
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          expect(
              path.contains(ui.Offset(
                  x + 0.95 * m * math.cos(a), y + 0.95 * m * math.sin(a))),
              isTrue,
              reason: '($x, $y) pushed at $k');
        }
      }
      final xs = [for (final c in corners) c.$1];
      final ys = [for (final c in corners) c.$2];
      final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
      final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
      var extremes = 0;
      for (final (x, y) in corners) {
        for (final (dx, dy, extreme) in [
          (-1.0, 0.0, x == minX),
          (1.0, 0.0, x == maxX),
          (0.0, -1.0, y == minY),
          (0.0, 1.0, y == maxY),
        ]) {
          if (!extreme) continue;
          extremes++;
          expect(path.contains(ui.Offset(x + 0.95 * m * dx, y + 0.95 * m * dy)),
              isTrue);
          expect(path.contains(ui.Offset(x + 1.1 * m * dx, y + 1.1 * m * dy)),
              isFalse,
              reason: 'the margin is $m: ($x, $y) by ${1.1 * m}');
        }
      }
      expect(extremes, 4);
      // Premise: today's 150 would leave the 0.95 x 300 points outside.
      expect(1.1 * kGroupFrameMarginMm, lessThan(0.95 * m));
    });

    test(
        'T3-e: the chip is the asymmetric padding\'s rect (-7, -3, w + 9, '
        'h + 4) with radius 8, its bottom edge on the frame bounds\' top '
        'line (margin 300) and its box centred on their centre x at 0.125 '
        'and 0.04 px/mm (fixes X3, F-4)', () {
      final doc = gp.groupedPlan();
      final camera = ValueNotifier(gp.cameraAt(0.125));
      final chips = themedGroups(
          TableGroupLayer.chips,
          doc,
          camera,
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'})
          }),
          ValueNotifier(fullTheme));
      final (ax, ay) = anchorOf(cornersOfAll(doc, ['12', '3', '7']), 300);
      for (final scale in [0.125, 0.04]) {
        camera.value = gp.cameraAt(scale);
        final spy = gp.frame(chips);
        final p = spy.paragraphs.single;
        expect(
            spy.rrects.single,
            ui.RRect.fromLTRBR(-7, -3, p.width + 9, p.height + 4,
                const ui.Radius.circular(8)));
        final (sx, sy) = gp.screenOf(camera.value, ax, ay);
        final t = spy.translations.single;
        expect(t.dy + spy.rrects.single.bottom, closeTo(sy, 1e-6),
            reason: 'the bottom edge on the top line at $scale');
        final r = spy.rrects.single;
        expect(t.dx + (r.left + r.right) / 2, closeTo(sx, 1e-6),
            reason: 'the box centred at $scale');
        expect(t.dx + p.width / 2 - sx, closeTo(-(9 - 7) / 2, 1e-6),
            reason: 'premise: the label sits off the centre by half the '
                'padding\'s difference');
        expect(spy.paints.single.color.toARGB32(), chipColour.toARGB32());
      }
    });

    test(
        'the margin widens the frame a chip is measured against: at a zoom '
        'where the frame with 150 mm is narrower than the chip and with 300 '
        'mm wider, the chip is drawn only under the theme\'s margin', () {
      final doc = gp.groupedPlan();
      final corners = cornersOfAll(doc, ['12', '3', '7']);
      final xs = [for (final c in corners) c.$1];
      final span = xs.reduce(math.max) - xs.reduce(math.min);
      final groups = ValueNotifier({
        'G7': gp.tg({'12', '3', '7'})
      });
      final camera = ValueNotifier(gp.cameraAt(0.08));
      final theme = ValueNotifier<FloorPlanTheme?>(
          const FloorPlanTheme(groupFrameMargin: 300));
      final chips =
          themedGroups(TableGroupLayer.chips, doc, camera, groups, theme);
      final chipWidth = gp.frame(chips).rrects.single.width;
      // The zoom where the chip is as wide as the frame at 225 mm.
      final scale = chipWidth / (span + 2 * 225);
      expect((span + 2 * 150) * scale, lessThan(chipWidth), reason: 'premise');
      expect((span + 2 * 300) * scale, greaterThan(chipWidth),
          reason: 'premise');
      camera.value = gp.cameraAt(scale);
      expect(gp.frame(chips).rrects, hasLength(1), reason: 'margin 300');
      theme.value = null;
      final plain = gp.frame(chips);
      expect(plain.paragraphs, isEmpty, reason: 'margin 150: skipped');
    });

    test(
        'T3-b, S-7: a theme with groupFrameColor alone fills the chip in '
        'that colour; groupChipColor wins over it', () {
      final doc = gp.groupedPlan();
      final theme = ValueNotifier<FloorPlanTheme?>(
          const FloorPlanTheme(groupFrameColor: frameColour));
      final chips = themedGroups(
          TableGroupLayer.chips,
          doc,
          ValueNotifier(gp.cameraAt(0.08)),
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'})
          }),
          theme);
      expect(gp.frame(chips).paints.single.color.toARGB32(),
          frameColour.toARGB32());
      theme.value = const FloorPlanTheme(
          groupFrameColor: frameColour, groupChipColor: chipColour);
      expect(gp.frame(chips).paints.single.color.toARGB32(),
          chipColour.toARGB32());
    });

    testWidgets(
        'the chip text: with no colour the automatic ink on the chip colour '
        '(white on 0x3949AB, dark on 0xFFE082), a colour honoured; 13 px is '
        'the paragraph a 13 px style lays out', (tester) async {
      final doc = gp.groupedPlan();
      final theme = ValueNotifier<FloorPlanTheme?>(fullTheme);
      final chips = themedGroups(
          TableGroupLayer.chips,
          doc,
          ValueNotifier(gp.cameraAt(0.08)),
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'})
          }),
          theme);
      Future<(int, int)> chipGlyphs() async {
        final spy = gp.frame(chips);
        final t = spy.translations.single;
        final p = spy.paragraphs.single;
        final bytes = await render(tester, chips, white, gp.kSize);
        return glyphs(bytes, gp.kSize.width.toInt(),
            ui.Rect.fromLTWH(t.dx, t.dy, p.width, p.height));
      }

      final p = gp.frame(chips).paragraphs.single;
      final want = (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 13))
            ..pushStyle(ui.TextStyle(fontSize: 13))
            ..addText('3+7+12'))
          .build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
      expect(p.height, want.height);
      expect(p.width, want.maxIntrinsicWidth.ceilToDouble());

      expect(foregroundFor(0x3949AB), 0xFFFFFF, reason: 'premise');
      expect(hex((await chipGlyphs()).$2), hex(0xFFFFFF),
          reason: 'white glyphs on the chip colour');
      theme.value = fullTheme.copyWith(groupChipColor: lightFill);
      expect(hex((await chipGlyphs()).$1), hex(rgbOf(kStatusCaptionOnLight)),
          reason: 'dark glyphs on a light chip');
      theme.value = fullTheme.copyWith(
          groupChipColor: lightFill,
          groupChipTextStyle: const TextStyle(color: Color(0xFFD81B60)));
      expect(hex((await chipGlyphs()).$1), hex(0xD81B60),
          reason: 'the style\'s colour');
    });

    testWidgets(
        'the chip\'s automatic ink is taken on the chip as drawn over the '
        'paper: 0x40FFFFFF on Blueprint (0x576B87) takes white ink, as '
        'chip colour or as the frame colour the chip falls back to; no '
        'theme inks gripMove as today', (tester) async {
      const translucent = Color(0x40FFFFFF);
      final doc = gp.groupedPlan();
      final theme = ValueNotifier<FloorPlanTheme?>(
          const FloorPlanTheme(groupChipColor: translucent));
      final chips = themedGroups(
          TableGroupLayer.chips,
          doc,
          ValueNotifier(gp.cameraAt(0.08)),
          ValueNotifier({
            'G7': gp.tg({'12', '3', '7'})
          }),
          theme,
          paper: ValueNotifier(blueprint));
      final width = gp.kSize.width.toInt();
      Future<(int, int, int)> chipPixels() async {
        final spy = gp.frame(chips);
        final t = spy.translations.single;
        final p = spy.paragraphs.single;
        final r = spy.rrects.single;
        final bytes = await render(tester, chips, blueprint, gp.kSize);
        final (darkest, brightest) = glyphs(
            bytes, width, ui.Rect.fromLTWH(t.dx, t.dy, p.width, p.height));
        // The left padding, clear of the glyphs and the corners.
        final pad = rgbAt(bytes, width, (t.dx + r.left + 1.5).floor(),
            (t.dy + (r.top + r.bottom) / 2).floor());
        return (darkest, brightest, pad);
      }

      final drawn = composite(translucent, 0x40 / 255, blueprint);
      expect(foregroundFor(0xFFFFFF), 0x000000,
          reason: 'premise: on its RGB the ink would be black');
      expect(foregroundFor(drawn), 0xFFFFFF,
          reason: 'premise: on the chip as drawn, white');
      var (_, brightest, pad) = await chipPixels();
      expect(channelDistance(pad, drawn), lessThanOrEqualTo(1),
          reason: 'premise: the chip is drawn translucent: ${hex(pad)}');
      expect(hex(brightest), hex(0xFFFFFF), reason: 'groupChipColor');

      theme.value = const FloorPlanTheme(groupFrameColor: translucent);
      (_, brightest, pad) = await chipPixels();
      expect(channelDistance(pad, drawn), lessThanOrEqualTo(1),
          reason: 'premise: the chip takes the frame colour');
      expect(hex(brightest), hex(0xFFFFFF), reason: 'groupFrameColor');

      // No theme (P-6): gripMove is opaque, so its ink is today's.
      theme.value = null;
      final grip = PaperPalette.forPaper(blueprint).gripMove;
      expect(grip.toARGB32() >> 24, 0xFF, reason: 'premise: opaque');
      final (darkest, bright, _) = await chipPixels();
      if (foregroundFor(rgbOf(grip)) == 0xFFFFFF) {
        expect(hex(bright), hex(0xFFFFFF));
      } else {
        expect(hex(darkest), hex(rgbOf(kStatusCaptionOnLight)));
      }
    });

    test(
        'a caption style leaves the chip as today (K16): statusCaptionStyle '
        '16 px alone, the chip is the 11 px paragraph', () {
      final doc = gp.groupedPlan();
      ui.Paragraph chipUnder(FloorPlanTheme? theme) => gp
          .frame(themedGroups(
              TableGroupLayer.chips,
              doc,
              ValueNotifier(gp.cameraAt(0.08)),
              ValueNotifier({
                'G7': gp.tg({'12', '3', '7'})
              }),
              ValueNotifier(theme)))
          .paragraphs
          .single;
      final today = chipUnder(null);
      final captionStyled = chipUnder(
          const FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 16)));
      expect(captionStyled.height, today.height);
      expect(captionStyled.width, today.width);
      expect(
          chipUnder(const FloorPlanTheme(
                  groupChipTextStyle: TextStyle(fontSize: 16)))
              .height,
          greaterThan(today.height),
          reason: 'premise: 16 px reads apart');
    });

    testWidgets(
        'Z14 under a themed veil: a faded group strokes the frame colour at '
        'alpha 1 - 0.35, its chip veiled in the veil\'s colour at 0.35; with '
        'no veil colour the paper\'s RGB at 0.35 (S-7, S-9)', (tester) async {
      final doc = gp.groupedPlan();
      final camera = ValueNotifier(gp.cameraAt(0.06));
      final groups = ValueNotifier(<String, TableGroup>{
        'GB': gp.tg({'7', '3'}),
        'GA': gp.tg({'12', '20', '9'}),
      });
      final focus = ValueNotifier<Set<String>?>({'3'});
      final paper = ValueNotifier<int>(white);
      final theme = ValueNotifier<FloorPlanTheme?>(fullTheme);
      final picker = TablePicker(doc);
      final frames = themedGroups(
          TableGroupLayer.frames, doc, camera, groups, theme,
          paper: paper, focus: focus, picker: picker);
      final chips = themedGroups(
          TableGroupLayer.chips, doc, camera, groups, theme,
          paper: paper, focus: focus, picker: picker);
      final spy = gp.frame(frames);
      expect(spy.paths, hasLength(2), reason: 'premise: GA, GB');
      final faded = spy.paints[0], normal = spy.paints[1];
      expect(faded.color.toARGB32() & 0xFFFFFF, 0x00897B);
      expect(faded.color.a, closeTo(1 - 0.35, 1e-6));
      expect(normal.color.toARGB32(), frameColour.toARGB32(),
          reason: 'GB straddles the focus');

      final chipSpy = gp.frame(chips);
      expect(chipSpy.rrects, hasLength(3), reason: 'GA, its veil, GB');
      final veil = chipSpy.paints[1].color;
      expect(veil.toARGB32() & 0xFFFFFF, 0x6D4C41);
      expect(veil.a, closeTo(0.35, 1e-6),
          reason: 'the host colour\'s 1 x 0.35');
      // GA's chip padding, read back: the veil at 0.35 over the chip.
      final t = chipSpy.translations[0];
      final r = chipSpy.rrects[0];
      final x = (t.dx + r.left + 2).ceil();
      final y = (t.dy + (r.top + r.bottom) / 2).floor();
      expect(x + 1 <= t.dx + r.left + 7 - 1, isTrue, reason: 'premise');
      var bytes = await render(tester, chips, white, gp.kSize);
      final want = composite(veilColour, 0.35, rgbOf(chipColour));
      expect(channelDistance(rgbAt(bytes, gp.kSize.width.toInt(), x, y), want),
          lessThanOrEqualTo(1));

      // No veil colour: the paper's RGB (its alpha replaced) at 0.35.
      paper.value = 0x801F3A5F;
      theme.value = const FloorPlanTheme(focusVeilOpacity: 0.35);
      final paperVeil = gp.frame(chips).paints[1].color;
      expect(paperVeil.toARGB32() & 0xFFFFFF, 0x1F3A5F);
      expect(paperVeil.a, closeTo(0.35, 1e-6));
      final grip = PaperPalette.forPaper(0x801F3A5F).gripMove;
      final fadedDark = gp.frame(frames).paints[0].color;
      expect(fadedDark.toARGB32() & 0xFFFFFF, grip.toARGB32() & 0xFFFFFF);
      expect(fadedDark.a, closeTo(0.65, 1e-6));
      bytes = await render(tester, chips, 0xFF1F3A5F, gp.kSize);
      final dark = gp.frame(chips);
      final t2 = dark.translations[0];
      final r2 = dark.rrects[0];
      final x2 = (t2.dx + r2.left + 1).ceil();
      final y2 = (t2.dy + (r2.top + r2.bottom) / 2).floor();
      expect(x2 + 1 <= t2.dx + r2.left + kGroupChipPaddingX - 1, isTrue,
          reason: 'premise');
      expect(
          channelDistance(rgbAt(bytes, gp.kSize.width.toInt(), x2, y2),
              composite(const Color(0xFF1F3A5F), 0.35, rgbOf(grip))),
          lessThanOrEqualTo(1));
    });
  });

  group('the veil (T-1, S-9)', () {
    /// The zone fixture's table 7 faded and 3 kept, rendered over [fp.kUnder]:
    /// each pixel well inside 7 is [want] within 1, counted.
    Future<int> veiled(WidgetTester tester, TableFocusPainter painter,
        ViewportTransform camera, TestQuad seven, int want) async {
      final bytes = await fp.render(tester, painter);
      final inv = camera.worldToScreenMatrix.invert();
      var n = 0;
      for (var y = 0; y < fp.kH; y += 3) {
        for (var x = 0; x < fp.kW; x += 3) {
          final px = x + 0.5, py = y + 0.5;
          final wx = inv.a * px + inv.c * py + inv.e;
          final wy = inv.b * px + inv.d * py + inv.f;
          if (!seven.holds(wx, wy, 2 / 0.37)) continue;
          final got = fp.rgbAt(bytes, x, y);
          expect(channelDistance(got, want), lessThanOrEqualTo(1),
              reason: '($x, $y): ${hex(got)}, want ${hex(want)}');
          n++;
        }
      }
      return n;
    }

    testWidgets(
        'a host veil colour\'s alpha is multiplied by the opacity; no colour '
        'is the paper\'s RGB at the opacity; a theme change recolours the '
        'same paint and rebuilds nothing', (tester) async {
      final doc = fp.zoneDoc();
      final seven = quadsNumbered(doc, '7').single;
      final camera = ValueNotifier(fp.cameraOn(seven));
      final focus = ValueNotifier<Set<String>?>({'3'});
      final paper = ValueNotifier<int>(fp.kPaper);
      final theme = ValueNotifier<FloorPlanTheme?>(const FloorPlanTheme(
          focusVeilColor: Color(0x806D4C41), focusVeilOpacity: 0.5));
      final painter = themedVeil(doc, camera, focus, paper, theme);
      final first = fp.spyFrame(painter);
      final paint = first.paints.single;
      // 0x80 / 255 x 0.5.
      expect(paint.color.a, closeTo(0x80 / 255 * 0.5, 1e-6));
      expect(paint.color.toARGB32() & 0xFFFFFF, 0x6D4C41);
      expect(
          await veiled(tester, painter, camera.value, seven,
              composite(veilColour, 0x80 / 255 * 0.5, fp.kUnder)),
          greaterThan(2000));
      final made = painter.debugAllocations;
      final rebuilt = painter.debugRebuilds;
      final recoloured = painter.debugRecolours;
      final path = first.paths.single;

      theme.value = const FloorPlanTheme(focusVeilOpacity: 0.35);
      expect(
          await veiled(tester, painter, camera.value, seven,
              composite(Color(fp.kPaper), 0.35, fp.kUnder)),
          greaterThan(2000),
          reason: 'the paper\'s RGB at 0.35');
      paper.value = 0x401F3A5F;
      expect(
          await veiled(tester, painter, camera.value, seven,
              composite(const Color(0xFF1F3A5F), 0.35, fp.kUnder)),
          greaterThan(2000),
          reason: 'the paper\'s alpha replaced, not multiplied');
      theme.value = null;
      expect(
          await veiled(
              tester,
              painter,
              camera.value,
              seven,
              composite(
                  const Color(0xFF1F3A5F), kTableFocusVeilAlpha, fp.kUnder)),
          greaterThan(2000),
          reason: 'no theme: today\'s 0.6');
      final last = fp.spyFrame(painter);
      expect(identical(last.paints.single, paint), isTrue);
      expect(identical(last.paths.single, path), isTrue);
      expect(painter.debugAllocations, made);
      expect(painter.debugRebuilds, rebuilt, reason: 'recoloured only');
      expect(painter.debugRecolours, recoloured + 3,
          reason: 'once per theme or paper change');
    });

    test(
        'a host veil colour with no opacity is at today\'s 0.6 (K13): its '
        'alpha multiplied by 0.6, its RGB kept', () {
      for (final colour in const [veilColour, Color(0x806D4C41)]) {
        final c =
            focusVeilColour(white, FloorPlanTheme(focusVeilColor: colour));
        expect(c.a, closeTo(colour.a * kTableFocusVeilAlpha, 1e-6));
        expect(rgbOf(c), rgbOf(colour));
      }
    });

    test('focusVeilColour: today\'s veil with no theme, exactly', () {
      for (final paper in [white, 0x801F3A5F, kDarkCanvasPaper]) {
        expect(focusVeilColour(paper, null),
            Color(paper).withValues(alpha: kTableFocusVeilAlpha));
        expect(focusVeilColour(paper, const FloorPlanTheme()),
            Color(paper).withValues(alpha: kTableFocusVeilAlpha));
      }
    });
  });
}

int rgbOf(Color c) => c.toARGB32() & 0xFFFFFF;
