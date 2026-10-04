// Dark theme spec D6c, R-6, F-16 (plan Task 5, M-DT-13): in the selection
// mode's `ServiceView`, a table status caption's ink follows what it sits
// on, the status colour over the paper. The paper reaches the status
// painter through `ServiceView`'s `_paper` notifier, set in
// `didChangeDependencies` and `_onPage`, and in the painter's repaint merge:
// with no page, a theme switch changes the paper with no document change and
// no camera move, so only that notifier can repaint the status layer (it
// sits behind its own repaint boundary).
//
// Read back in pixels under the floor planner's seed (support/
// palette_fixture.dart), with the demo's translucent Bill status.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/service_view.dart';
import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/service/table_status_painter.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../service/table_status_painter_test.dart' show SpyCanvas;
import '../support/palette_fixture.dart';
import '../tables/table_fixture.dart';

/// The demo's Bill status (`apps/restaurant_demo/lib/main.dart`).
const Color bill = Color(0x99E53935);

/// Where table 1's top is centred, in world millimetres: inside the
/// fixture's 1:20 sheet, off its origin.
const double tableX = 9000, tableY = 5000;

/// A controller over a document with the app's set-up and one table
/// (number 1) at ([tableX], [tableY]); a 1:20 page of [paper] with the grid
/// off, or no page when [paper] is null (a file saved without one).
FloorPlanController statusController(int? paper) {
  final m = FlutterTextMeasurer();
  final doc = prepareDocument(m);
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
  doc.commands.execute(
      placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(tableX, tableY)));
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  m.clear();
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  final d = c.activeDocument;
  expect(TableSurvey.of(d).withNumber('1'), hasLength(1));
  expect(d.components.get<PageComponent>(d.rootHandle)?.background, paper);
  return c;
}

Widget view(FloorPlanController c) =>
    Scaffold(body: FloorPlanView(controller: c));

/// Pumps [c]'s selection mode in [mode], puts table 1's top at the drawing
/// area's (700, 400) at 0.07 px/mm, and gives it Bill.
///
/// The scale keeps the caption clear of the number: the caption sits at
/// least 11 px below the label's anchor (S7), and in the test font the
/// label's glyph box reaches about 0.68 of its 200 mm height below the
/// anchor, 9.5 px at this scale (at 0.25 px/mm it covers the caption's top
/// rows). The 1200 x 800 mm top is 84 x 56 px, wider than the caption.
Future<void> pumpService(
    WidgetTester tester, FloorPlanController c, ThemeMode mode) async {
  windowAt(tester, const Size(1440, 900));
  c.setMode(FloorPlanMode.selection);
  await pumpThemed(tester, view(c), mode);
  await tester.pump();
  await tester.pump();
  expect(find.byType(ServiceView), findsOneWidget);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: const Transform2(
          0.07, 0, 0, -0.07, 700 - 0.07 * tableX, 400 + 0.07 * tableY));
  c.setTableStatus({'1': TableStatus(color: bill, caption: 'Bill')});
  await tester.pump();
}

/// The caption's glyph run, in global pixels: the paragraph's centred
/// text, one pixel in from its top and bottom (clear of the number above
/// it). Read through a recording canvas on the live painter; the position
/// does not depend on the ink.
Rect captionBox(WidgetTester tester) {
  final layer = find.byKey(const Key('table-status-layer'));
  final painter =
      tester.widget<CustomPaint>(layer).painter! as TableStatusPainter;
  final spy = SpyCanvas();
  painter.paint(spy, tester.getSize(layer));
  final p = spy.paragraphs.single;
  final t = spy.translations.single;
  final o = tester.getTopLeft(layer);
  final inset = (p.width - p.maxIntrinsicWidth) / 2;
  return Rect.fromLTRB(o.dx + t.dx + inset, o.dy + t.dy + 1,
      o.dx + t.dx + inset + p.maxIntrinsicWidth, o.dy + t.dy + p.height - 1);
}

/// The [box]'s darkest (smallest largest channel) and brightest (largest
/// smallest channel) pixels.
(int, int) glyphs(Shot shot, Rect box) {
  var darkest = 0, brightest = 0, dMax = 256, bMin = -1;
  for (var y = box.top.ceil(); y < box.bottom.floor(); y++) {
    for (var x = box.left.ceil(); x < box.right.floor(); x++) {
      final rgb = shot.rgbAt(x, y);
      final ch = [(rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF];
      final hi = ch.reduce((a, b) => a > b ? a : b);
      final lo = ch.reduce((a, b) => a < b ? a : b);
      if (hi < dMax) (dMax, darkest) = (hi, rgb);
      if (lo > bMin) (bMin, brightest) = (lo, rgb);
    }
  }
  return (darkest, brightest);
}

void expectDarkCaption(Shot shot, Rect box, String reason) =>
    expect(hex(glyphs(shot, box).$1), hex(rgbOf(kStatusCaptionOnLight)),
        reason: '$reason: the caption\'s darkest pixel');

void expectLightCaption(Shot shot, Rect box, String reason) =>
    expect(hex(glyphs(shot, box).$2), hex(rgbOf(kStatusCaptionOnDark)),
        reason: '$reason: the caption\'s brightest pixel');

void main() {
  test(
      'premise: Bill over the seed\'s light surface takes the dark caption, '
      'over its dark surface the light one; over White dark, over Blueprint '
      'light', () {
    expect(statusCaptionInk(bill, lightTheme.colorScheme.surface.toARGB32()),
        kStatusCaptionOnLight);
    expect(statusCaptionInk(bill, darkTheme.colorScheme.surface.toARGB32()),
        kStatusCaptionOnDark);
    expect(statusCaptionInk(bill, white), kStatusCaptionOnLight);
    expect(statusCaptionInk(bill, blueprint), kStatusCaptionOnDark);
  });

  testWidgets(
      'M-DT-13, F-16: ServiceView with no page, light then dark theme with '
      'no camera move: the caption repaints light on the dark surface, and '
      'back', (tester) async {
    final c = statusController(null);
    await pumpService(tester, c, ThemeMode.light);
    final box = captionBox(tester);
    final camera = c.camera.value;
    expectDarkCaption(await shoot(tester), box, 'no page, light');

    await pumpThemed(tester, view(c), ThemeMode.dark);
    await tester.pump();
    expect(identical(c.camera.value, camera), isTrue);
    expectLightCaption(
        await shoot(tester), box, 'no page, after the switch to dark');

    await pumpThemed(tester, view(c), ThemeMode.light);
    await tester.pump();
    expectDarkCaption(await shoot(tester), box, 'no page, back to light');
  });

  testWidgets(
      'D6c: ServiceView in the dark theme on White keeps the dark caption '
      '(the paper decides, not the theme); White to Blueprint repaints it '
      'light', (tester) async {
    final c = statusController(white);
    await pumpService(tester, c, ThemeMode.dark);
    final box = captionBox(tester);
    expectDarkCaption(await shoot(tester), box, 'dark theme, White');

    final doc = c.activeDocument;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        doc.components
            .get<PageComponent>(doc.rootHandle)!
            .copyWith(background: blueprint)));
    await tester.pump();
    // The page notifier hears the change on the document's change stream,
    // a microtask after the command: a second frame shows it.
    await tester.pump();
    expectLightCaption(await shoot(tester), box, 'dark theme, Blueprint');
  });
}
