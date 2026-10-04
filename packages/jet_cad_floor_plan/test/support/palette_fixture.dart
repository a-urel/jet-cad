// The dark theme's planner fixture (spec D1, D4, D5; plan Task 4): the real
// seed's light and dark themes switched at zero animation, a page or none,
// two horizontal ACI 7 lines (one to select, one as the ink witness), an
// axis-aligned, y-up, off-origin camera at 0.125 px/mm that puts the lines
// and the sheet's left edge on pixel centres, and a capture of the whole
// window at device pixel ratio 1.
//
// The pixel alignment is what lets a sample read a colour exactly: a 2 px
// selection stroke centred on y = n + 0.5 covers row n fully, and the 1 px
// sheet edge centred on x = m + 0.5 covers column m. The grid is off so no
// grid line half-covers the edge column (the grid is not what these tests
// are about; Task 2's painter tests carry it).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The floor planner app's seed (F-1), its real light and dark schemes.
const Color seed = Color(0xFF2266CC);
final ThemeData lightTheme = ThemeData(colorSchemeSeed: seed);
final ThemeData darkTheme =
    ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark);

/// The page panel's White and Blueprint swatches (F-7).
const int white = 0xFFFFFFFF;
const int blueprint = 0xFF1F3A5F;

/// The capture: a repaint boundary around the whole window.
final GlobalKey shotKey = GlobalKey(debugLabel: 'shot');

/// The sheet's lower-left corner (the page's origin) and its extent at 1:20
/// (A4 landscape, 297 x 210 paper mm).
const double sheetMinX = 7000, sheetMinY = 3000;
const double sheetMaxY = sheetMinY + 210 * 20;

/// The two lines, horizontal, inside the sheet: [selectedY] is selected,
/// [inkY] is the ACI 7 ink witness. Both lie a whole number of 8 mm (one
/// pixel at 0.125 px/mm) below the sheet's top, so both sit on pixel
/// centres when the top does.
const double lineX0 = 7600, lineX1 = 9800;
const double selectedY = 4600, inkY = 3904;

/// The sample column along the lines: a quarter of the way, clear of the
/// end and middle grips.
const double sampleX = lineX0 + (lineX1 - lineX0) / 4;

/// The camera's scale, px/mm: a power of two, so whole millimetre steps of
/// 8 mm are whole pixels.
const double pxPerMm = 0.125;

/// Where the camera puts the sheet's left edge and top, in the drawing
/// area's pixels: on pixel centres.
const double edgeColumn = 40, topRow = 30;

/// Y up, off the origin, at [pxPerMm]: the sheet's left edge at
/// x = [edgeColumn] + 0.5, its top at y = [topRow] + 0.5.
final ViewportTransform paletteCamera = ViewportTransform(
    worldToScreenMatrix: const Transform2(
        pxPerMm,
        0,
        0,
        -pxPerMm,
        edgeColumn + 0.5 - pxPerMm * sheetMinX,
        topRow + 0.5 + pxPerMm * sheetMaxY));

/// A document with the app's set-up, two ACI 7 lines (ByLayer, layer 0)
/// and, unless [paper] is null, a 1:20 page of that background with the
/// grid off. Null [paper] is the page-less document a file saved without a
/// page decodes to (spec "Not in scope": every new document gets
/// `defaultPage()`): [prepareDocument] attaches no page.
({DraftDocument doc, Handle selected, Handle ink}) paletteDoc(
    TextMeasurer measurer,
    {required int? paper}) {
  final doc = prepareDocument(measurer);
  if (paper != null) {
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        PageComponent(
            scaleDenominator: 20,
            originX: sheetMinX,
            originY: sheetMinY,
            background: paper,
            gridVisible: false,
            snapToGrid: false)));
  }
  Handle line(double y) {
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(lineX0, y), Vector2(lineX1, y)),
        layer: ReservedHandles.layerZero);
    doc.commands.execute(add);
    return add.record.handle;
  }

  final selected = line(selectedY);
  final ink = line(inkY);
  doc.commands.clearHistory();
  expect(doc.entities.colorAt(doc.entities.slotOf(ink)!), kByLayer);
  expect(doc.tables.layers[ReservedHandles.layerZero]!.color,
      const IndexedColor(7));
  return (doc: doc, selected: selected, ink: ink);
}

/// The window at [size] logical pixels, device pixel ratio 1, reset after
/// the test.
void windowAt(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pumps [home] under the seed's themes in [mode], at zero theme animation,
/// inside the capture boundary. Pumping it again with another [mode] keeps
/// every state below: the tree has the same shape.
Future<void> pumpThemed(WidgetTester tester, Widget home, ThemeMode mode) =>
    tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: RepaintBoundary(key: shotKey, child: home),
    ));

/// `0xRRGGBB` of a colour.
int rgbOf(Color c) => c.toARGB32() & 0xFFFFFF;

String hex(int rgb) => '0x${rgb.toRadixString(16).padLeft(6, '0')}';

/// The largest per-channel difference of two `0xRRGGBB` values.
int channelDistance(int a, int b) => [16, 8, 0]
    .map((s) => (((a >> s) & 0xFF) - ((b >> s) & 0xFF)).abs())
    .reduce(math.max);

/// One captured frame of the window, at device pixel ratio 1.
final class Shot {
  Shot(this.bytes, this.width, this.height);

  final ByteData bytes;
  final int width, height;

  /// `0xRRGGBB` at pixel ([x], [y]).
  int rgbAt(int x, int y) {
    final i = (y * width + x) * 4;
    return (bytes.getUint8(i) << 16) |
        (bytes.getUint8(i + 1) << 8) |
        bytes.getUint8(i + 2);
  }

  Iterable<int> _block(int x, int y) sync* {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        yield rgbAt(x + dx, y + dy);
      }
    }
  }

  /// The pixel of the 3 x 3 block around ([x], [y]) nearest [rgb].
  int nearest(int x, int y, int rgb) => _block(x, y).reduce(
      (a, b) => channelDistance(a, rgb) <= channelDistance(b, rgb) ? a : b);

  /// The 3 x 3 block's brightest (largest smallest channel) pixel.
  int brightest(int x, int y) =>
      _block(x, y).reduce((a, b) => _minChannel(a) >= _minChannel(b) ? a : b);

  /// The 3 x 3 block's darkest (smallest largest channel) pixel.
  int darkest(int x, int y) =>
      _block(x, y).reduce((a, b) => _maxChannel(a) <= _maxChannel(b) ? a : b);

  /// The most common colour of row [y] from [x0] to [x1] (exclusive).
  int modeOfRow(int y, int x0, int x1) {
    final counts = <int, int>{};
    for (var x = x0; x < x1; x++) {
      counts.update(rgbAt(x, y), (n) => n + 1, ifAbsent: () => 1);
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

int _minChannel(int rgb) =>
    math.min((rgb >> 16) & 0xFF, math.min((rgb >> 8) & 0xFF, rgb & 0xFF));
int _maxChannel(int rgb) =>
    math.max((rgb >> 16) & 0xFF, math.max((rgb >> 8) & 0xFF, rgb & 0xFF));

/// Captures the window as it is now.
Future<Shot> shoot(WidgetTester tester) async {
  final boundary =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final shot = Shot(raw!, image.width, image.height);
    image.dispose();
    return shot;
  }))!;
}

/// The global pixel of world [w] in the [view]th drawing area: the pixel
/// whose square holds the point.
(int, int) pixelOf(WidgetTester tester, Vector2 w, {int view = 0}) {
  final area = find.byType(InteractionLayer).at(view);
  final camera = tester
      .widget<CameraGestureDetector>(find
          .ancestor(of: area, matching: find.byType(CameraGestureDetector))
          .first)
      .camera
      .value;
  final topLeft = tester.getTopLeft(area);
  // The alignment needs a drawing area on whole pixels.
  expect(topLeft.dx, topLeft.dx.roundToDouble());
  expect(topLeft.dy, topLeft.dy.roundToDouble());
  final s = camera.worldToScreen(w);
  return ((topLeft.dx + s.x).floor(), (topLeft.dy + s.y).floor());
}

/// The global pixel at the drawing area's own ([x], [y]).
(int, int) areaPixel(WidgetTester tester, double x, double y, {int view = 0}) {
  final topLeft = tester.getTopLeft(find.byType(InteractionLayer).at(view));
  return ((topLeft.dx + x).floor(), (topLeft.dy + y).floor());
}

/// What the canvas showed, sampled.
final class Seen {
  Seen(
      {required this.selection,
      required this.ink,
      required this.rulerBar,
      required this.corner,
      required this.edge});

  /// The pixel of the selected line's 3 x 3 block nearest [expected].
  final int Function(int expected) selection;

  /// The ink witness's block: its brightest and darkest pixels.
  final (int, int) ink;

  /// The top ruler's most common colour on a row clear of the labels and
  /// minor ticks, and the corner box's pixel; null without rulers.
  final int? rulerBar, corner;

  /// The sheet's left edge column, between the lines and the top.
  final int edge;
}

/// Samples the [view]th canvas of [shot].
Seen look(WidgetTester tester, Shot shot, {int view = 0}) {
  final (sx, sy) = pixelOf(tester, Vector2(sampleX, selectedY), view: view);
  final (ix, iy) = pixelOf(tester, Vector2(sampleX, inkY), view: view);
  final (ex, ey) = areaPixel(tester, edgeColumn, topRow + 150, view: view);
  final top = find.byKey(const Key('ruler-top'));
  int? bar, corner;
  if (top.evaluate().isNotEmpty) {
    final r = tester.getRect(top.at(view));
    bar = shot.modeOfRow(r.top.floor() + 15, r.left.ceil(), r.right.floor());
    final c = tester.getRect(find.byKey(const Key('ruler-corner')).at(view));
    corner = shot.rgbAt(c.left.floor() + 2, c.top.floor() + 2);
  }
  return Seen(
      selection: (expected) => shot.nearest(sx, sy, expected),
      ink: (shot.brightest(ix, iy), shot.darkest(ix, iy)),
      rulerBar: bar,
      corner: corner,
      edge: shot.rgbAt(ex, ey));
}

/// The selection colour seen is [paper]'s, within 3 per channel.
void expectSelection(Seen seen, PaperPalette paper, String reason) {
  final want = rgbOf(paper.selection);
  final got = seen.selection(want);
  expect(channelDistance(got, want), lessThanOrEqualTo(3),
      reason: '$reason: selection ${hex(got)}, want ${hex(want)}');
}

/// The ruler bar, the corner box and the sheet edge are [chrome]'s.
void expectChrome(Seen seen, ChromePalette chrome, String reason) {
  expect(hex(seen.rulerBar!), hex(rgbOf(chrome.rulerBackground)),
      reason: '$reason: ruler bar');
  expect(hex(seen.corner!), hex(rgbOf(chrome.rulerBackground)),
      reason: '$reason: ruler corner');
  expectEdge(seen, chrome, reason);
}

/// The sheet edge column is [chrome]'s edge, exactly.
void expectEdge(Seen seen, ChromePalette chrome, String reason) =>
    expect(hex(seen.edge), hex(rgbOf(chrome.sheetEdge)),
        reason: '$reason: sheet edge');

/// The ink witness is light (its brightest pixel above 200 per channel).
void expectLightInk(Seen seen, String reason) =>
    expect(_minChannel(seen.ink.$1), greaterThan(200),
        reason: '$reason: ink brightest ${hex(seen.ink.$1)}');

/// The ink witness is dark (its darkest pixel below 60 per channel).
void expectDarkInk(Seen seen, String reason) =>
    expect(_maxChannel(seen.ink.$2), lessThan(60),
        reason: '$reason: ink darkest ${hex(seen.ink.$2)}');

/// The palettes the [view]th canvas's painters hold: each ruler's and the
/// corner's chrome (none without rulers), the page chrome's chrome and
/// paper set, and the selection overlay's paper set. What `PlannerView`
/// handed down, including the page chrome's paper set, which the pixels
/// here do not show (the fixture's grid is off and its page breaks too).
void expectPainters(WidgetTester tester, ChromePalette chrome,
    PaperPalette paper, String reason,
    {int view = 0, bool withRulers = true}) {
  final painters = [
    for (final p in tester.widgetList<CustomPaint>(find.descendant(
        of: find.byType(PlannerView).at(view),
        matching: find.byType(CustomPaint))))
      if (p.painter case final painter?) painter,
  ];
  final rulers = painters.whereType<RulerPainter>().toList();
  final corners = painters.whereType<RulerCornerPainter>().toList();
  final chromes = painters.whereType<PageChromePainter>().toList();
  final overlays = painters.whereType<SelectionOverlayPainter>().toList();
  expect(rulers, hasLength(withRulers ? 2 : 0), reason: reason);
  expect(corners, hasLength(withRulers ? 1 : 0), reason: reason);
  expect(chromes, hasLength(1), reason: reason);
  expect(overlays, hasLength(1), reason: reason);
  for (final r in rulers) {
    expect(r.chrome, chrome, reason: '$reason: ruler');
  }
  for (final c in corners) {
    expect(c.chrome, chrome, reason: '$reason: corner');
  }
  expect(chromes.single.chrome, chrome, reason: '$reason: page chrome');
  expect(chromes.single.paper, paper, reason: '$reason: page chrome paper');
  expect(overlays.single.paper, paper, reason: '$reason: overlay');
}
