// Host embedding API spec T-1's selection and canvas rows (Slice 3 plan
// Task 2): `selectionOnLight`, `selectionOnDark` and `selectionWidth` reach
// the selection overlay in both modes, per paper; `canvasBackground` is the
// surround and a page-less plan's paper, so the ink, the paper's set and
// the selection follow it as they follow `scheme.surface` today. The theme
// reaches neither `designJson()` nor the PNG export (invariant 4).
//
// Read back in pixels on the dark theme's planner fixture
// (support/palette_fixture.dart: the real seed's themes at zero animation,
// White, Blueprint and the dark canvas, a page or none, a y-up, off-origin
// camera at 0.125 px/mm with the lines on pixel centres), through
// `FloorPlanView` in both modes, and on a bare `PlannerShell` for the
// ambient-only path. The theme's colours are none of the sets' colours.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_theme.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/service_view.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/palette_fixture.dart';

/// The theme's colours: none is a palette colour or another's.
const Color onLight = Color(0xFFD81B60);
const Color onDark = Color(0xFFFFD54F);
const Color canvas = Color(0xFF263238);

/// A theme with every field set to a value that is not today's.
const FloorPlanTheme fullTheme = FloorPlanTheme(
  statusCaptionStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.5,
  groupFrameColor: Color(0xFF00897B),
  groupFrameWidth: 3,
  groupFrameMargin: 300,
  groupChipColor: Color(0xFF3949AB),
  groupChipTextStyle: TextStyle(fontSize: 13),
  groupChipRadius: 8,
  groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4),
  selectionOnLight: onLight,
  selectionOnDark: onDark,
  selectionWidth: 4,
  focusVeilColor: Color(0xFF6D4C41),
  focusVeilOpacity: 0.35,
  canvasBackground: canvas,
  serviceBarHeight: 60,
);

/// A controller over the fixture's document on [paper] (null: no page),
/// with the selected line's and the ink witness's handles (a decode keeps
/// handles).
({FloorPlanController c, Handle selected, Handle ink}) controllerOn(
    int? paper) {
  final m = FlutterTextMeasurer();
  final f = paletteDoc(m, paper: paper);
  final json = DraftDocumentCodec.encodeToString(f.doc);
  f.doc.dispose();
  m.clear();
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  return (c: c, selected: f.selected, ink: f.ink);
}

/// The fixture's light and dark themes, each carrying [ambient] when given.
ThemeData withExtension(ThemeData theme, FloorPlanTheme? ambient) =>
    ambient == null ? theme : theme.copyWith(extensions: [ambient]);

/// [home] under the seed's themes (carrying [ambient]) in [mode], at zero
/// theme animation, inside the capture boundary. The tree keeps its shape
/// across calls, so every state below survives a re-pump.
Future<void> pumpHome(WidgetTester tester, Widget home, ThemeMode mode,
        {FloorPlanTheme? ambient}) =>
    tester.pumpWidget(MaterialApp(
      theme: withExtension(lightTheme, ambient),
      darkTheme: withExtension(darkTheme, ambient),
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: RepaintBoundary(key: shotKey, child: home),
    ));

Widget viewOf(FloorPlanController c,
        {FloorPlanTheme? theme, void Function(FloorPlanExport)? onExport}) =>
    Scaffold(
        body: FloorPlanView(controller: c, theme: theme, onExport: onExport));

/// Pumps [v]'s view in [viewMode] under [mode], sets the fixture's camera
/// and selects the line.
Future<void> pumpView(
    WidgetTester tester,
    ({FloorPlanController c, Handle selected, Handle ink}) v,
    ThemeMode mode,
    FloorPlanMode viewMode,
    {FloorPlanTheme? theme,
    FloorPlanTheme? ambient,
    void Function(FloorPlanExport)? onExport}) async {
  windowAt(tester, const Size(1440, 900));
  v.c.setMode(viewMode);
  await pumpHome(tester, viewOf(v.c, theme: theme, onExport: onExport), mode,
      ambient: ambient);
  await tester.pump();
  await tester.pump();
  v.c.cameraController.value = paletteCamera;
  v.c.activeSelection.replace([SelectionKey.root(v.selected)]);
  await tester.pump();
  expect(find.byType(ServiceView),
      findsNWidgets(viewMode == FloorPlanMode.selection ? 1 : 0));
}

/// The selection overlay's painter in the view.
SelectionOverlayPainter overlayOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(
        of: find.byType(PlannerView), matching: find.byType(CustomPaint)))
    .map((p) => p.painter)
    .whereType<SelectionOverlayPainter>()
    .single;

/// The selection colour at the selected line's pixel is [want], within 3
/// per channel.
void expectSelectionRgb(
    Shot shot, WidgetTester tester, Color want, String reason) {
  final (sx, sy) = pixelOf(tester, Vector2(sampleX, selectedY));
  final got = shot.nearest(sx, sy, rgbOf(want));
  expect(channelDistance(got, rgbOf(want)), lessThanOrEqualTo(3),
      reason: '$reason: selection ${hex(got)}, want ${hex(rgbOf(want))}');
}

/// Whether the rows one above and one below the selected line's are the
/// selection colour [want] (within 3): a 2 px stroke centred on the row's
/// centre covers them half, a 4 px one fully.
(bool, bool) outerRowsAre(Shot shot, WidgetTester tester, Color want) {
  final (sx, sy) = pixelOf(tester, Vector2(sampleX, selectedY));
  bool near(int y) => channelDistance(shot.rgbAt(sx, y), rgbOf(want)) <= 3;
  return (near(sy - 1), near(sy + 1));
}

/// The drawing area's pixel ([x], [y]) left of the sheet (whose left edge
/// is at [edgeColumn]), or anywhere on a page-less plan: the surround.
int surroundAt(Shot shot, WidgetTester tester) {
  final (x, y) = areaPixel(tester, edgeColumn - 20, topRow + 150);
  return shot.rgbAt(x, y);
}

/// Exports a 96 dpi PNG through the view's Export and returns its bytes.
Future<Uint8List> exportPng(
    WidgetTester tester, String button, List<FloorPlanExport> got) async {
  final before = got.length;
  await tester.tap(find.byKey(Key(button)));
  await tester.pump();
  await tester.pump();
  expect(find.byKey(const Key('export-dialog')), findsOneWidget);
  await tester.tap(find.byKey(const Key('export-format-png')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('export-dpi-96')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('export-ok')));
  await tester.pump();
  for (var i = 0; i < 400 && got.length == before; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(got, hasLength(before + 1));
  expect(got.last.mimeType, 'image/png');
  return got.last.bytes;
}

void main() {
  test('premise: the theme\'s colours are none of the sets\'', () {
    for (final c in [onLight, onDark, canvas]) {
      for (final set in [PaperPalette.light, PaperPalette.dark]) {
        expect(c, isNot(set.selection));
        expect(c, isNot(set.hover));
      }
    }
    // The canvas colour is a dark paper: ACI 7 inks white on it, and the
    // overlays take the dark set. The seed's light surface takes black.
    expect(foregroundFor(canvas.toARGB32() & 0xFFFFFF), 0xFFFFFF);
    expect(foregroundFor(lightTheme.colorScheme.surface.toARGB32() & 0xFFFFFF),
        0x000000);
    expect(rgbOf(canvas), isNot(rgbOf(lightTheme.colorScheme.surface)));
    expect(rgbOf(canvas), isNot(rgbOf(darkTheme.colorScheme.surface)));
  });

  test('paperPaletteFor: today\'s const sets with no colour for the set', () {
    expect(identical(paperPaletteFor(white, null), PaperPalette.light), isTrue);
    expect(
        identical(paperPaletteFor(blueprint, null), PaperPalette.dark), isTrue);
    const lightOnly = FloorPlanTheme(selectionOnLight: onLight);
    const darkOnly = FloorPlanTheme(selectionOnDark: onDark);
    expect(identical(paperPaletteFor(blueprint, lightOnly), PaperPalette.dark),
        isTrue);
    expect(identical(paperPaletteFor(white, darkOnly), PaperPalette.light),
        isTrue);
    expect(paperPaletteFor(white, lightOnly),
        PaperPalette.light.withSelection(onLight));
    expect(paperPaletteFor(blueprint, darkOnly),
        PaperPalette.dark.withSelection(onDark));
    expect(
        identical(
            paperPaletteFor(white, const FloorPlanTheme(selectionWidth: 4)),
            PaperPalette.light),
        isTrue);
  });

  for (final viewMode in FloorPlanMode.values) {
    final m = viewMode.name;

    testWidgets(
        'P-6 ($m): with no theme the view hands the overlay today\'s const '
        'set and 2 px', (tester) async {
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, viewMode);
      final view = tester.widget<PlannerView>(find.byType(PlannerView));
      expect(identical(view.paper, PaperPalette.light), isTrue);
      expect(view.selectionStrokePixels, kSelectionStrokePixels);
      expect(overlayOf(tester).selectionStrokePixels, kSelectionStrokePixels);
      final shot = await shoot(tester);
      expectSelectionRgb(shot, tester, PaperPalette.light.selection, 'none');
      expect(surroundAt(shot, tester), rgbOf(lightTheme.colorScheme.surface));
    });

    testWidgets(
        'M-H33(the editor\'s selection) ($m): White under the light theme '
        'takes selectionOnLight, Blueprint selectionOnDark', (tester) async {
      const theme =
          FloorPlanTheme(selectionOnLight: onLight, selectionOnDark: onDark);
      for (final (paper, want, set) in [
        (white, onLight, PaperPalette.light),
        (blueprint, onDark, PaperPalette.dark),
      ]) {
        final v = controllerOn(paper);
        await pumpView(tester, v, ThemeMode.light, viewMode, theme: theme);
        final shot = await shoot(tester);
        expectSelectionRgb(shot, tester, want, hex(paper));
        expect(tester.widget<PlannerView>(find.byType(PlannerView)).paper,
            set.withSelection(want));
        expect(overlayOf(tester).paper, set.withSelection(want));
        // A fresh tree for the next paper.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
        'selectionOnDark on the dark canvas ($m): a White page under the '
        'dark theme shows dark (K1) and takes the dark colour', (tester) async {
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.dark, viewMode,
          theme: const FloorPlanTheme(
              selectionOnLight: onLight, selectionOnDark: onDark));
      final shot = await shoot(tester);
      expectSelectionRgb(shot, tester, onDark, 'dark canvas');
      expectLightInk(look(tester, shot), 'dark canvas');
    });

    testWidgets(
        'only selectionOnLight ($m): Blueprint keeps the dark set\'s '
        '0xFF7FB2FF, White takes the theme\'s (per paper)', (tester) async {
      const theme = FloorPlanTheme(selectionOnLight: onLight);
      var v = controllerOn(blueprint);
      await pumpView(tester, v, ThemeMode.light, viewMode, theme: theme);
      var shot = await shoot(tester);
      expectSelectionRgb(shot, tester, const Color(0xFF7FB2FF), 'Blueprint');
      expect(
          identical(tester.widget<PlannerView>(find.byType(PlannerView)).paper,
              PaperPalette.dark),
          isTrue);
      await tester.pumpWidget(const SizedBox());

      v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, viewMode, theme: theme);
      shot = await shoot(tester);
      expectSelectionRgb(shot, tester, onLight, 'White');
    });

    testWidgets(
        'selectionWidth: 4 ($m) covers the rows a 2 px stroke covers only '
        'half; the outline stays the paper\'s colour', (tester) async {
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, viewMode);
      var shot = await shoot(tester);
      expect(outerRowsAre(shot, tester, PaperPalette.light.selection),
          (false, false),
          reason: 'the control: 2 px covers the rows beside its own half');

      await pumpHome(
          tester,
          viewOf(v.c, theme: const FloorPlanTheme(selectionWidth: 4)),
          ThemeMode.light);
      expect(tester.widget<PlannerView>(find.byType(PlannerView)).paper,
          same(PaperPalette.light));
      expect(overlayOf(tester).selectionStrokePixels, 4);
      shot = await shoot(tester);
      // T2-b: one pump, no camera move: the painter's width alone changed.
      expect(outerRowsAre(shot, tester, PaperPalette.light.selection),
          (true, true));
      expectSelectionRgb(
          shot, tester, PaperPalette.light.selection, 'the row itself');
    });

    testWidgets(
        'M-H33(canvasBackground) ($m): a page-less plan under the light '
        'theme on a dark canvasBackground: the surround is it, the ink '
        'white, the selection the dark set\'s', (tester) async {
      final v = controllerOn(null);
      await pumpView(tester, v, ThemeMode.light, viewMode,
          theme: const FloorPlanTheme(canvasBackground: canvas));
      final shot = await shoot(tester);
      expect(hex(surroundAt(shot, tester)), hex(rgbOf(canvas)));
      final (cx, cy) = areaPixel(tester, 700, 20);
      expect(hex(shot.rgbAt(cx, cy)), hex(rgbOf(canvas)),
          reason: 'right of where a sheet would be: no sheet, all canvas');
      expectLightInk(look(tester, shot), 'page-less on the canvas');
      expectSelectionRgb(shot, tester, const Color(0xFF7FB2FF), 'page-less');
      expect(
          identical(tester.widget<PlannerView>(find.byType(PlannerView)).paper,
              PaperPalette.dark),
          isTrue);
    });

    testWidgets(
        'T2-d ($m): with a page, canvasBackground colours the surround only; '
        'the sheet, the ink and the selection are the White page\'s',
        (tester) async {
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, viewMode,
          theme: const FloorPlanTheme(canvasBackground: canvas));
      final shot = await shoot(tester);
      expect(hex(surroundAt(shot, tester)), hex(rgbOf(canvas)),
          reason: 'the pixel beside the sheet');
      final (fx, fy) = areaPixel(tester, edgeColumn + 60, topRow + 60);
      expect(hex(shot.rgbAt(fx, fy)), hex(0xFFFFFF),
          reason: 'the sheet is the page\'s White');
      final seen = look(tester, shot);
      expectDarkInk(seen, 'White page');
      expectSelection(seen, PaperPalette.light, 'White page');
      expect(
          identical(tester.widget<PlannerView>(find.byType(PlannerView)).paper,
              PaperPalette.light),
          isTrue);
    });

    testWidgets(
        'invariant 4 ($m): designJson and the PNG export are the same with '
        'and without a full theme', (tester) async {
      final got = <FloorPlanExport>[];
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, viewMode, onExport: got.add);
      final button = viewMode == FloorPlanMode.design
          ? 'toolbar-export'
          : 'service-export';
      final plainJson = v.c.designJson();
      final plain = await exportPng(tester, button, got);
      expect(plain.sublist(1, 4), 'PNG'.codeUnits);

      await pumpHome(tester, viewOf(v.c, theme: fullTheme, onExport: got.add),
          ThemeMode.light,
          ambient: const FloorPlanTheme(selectionWidth: 3));
      await tester.pump();
      expect(overlayOf(tester).selectionStrokePixels, 4,
          reason: 'the theme is in force');
      final themed = await exportPng(tester, button, got);
      expect(themed, plain);
      expect(v.c.designJson(), plainJson);
    });
  }

  testWidgets(
      'T2-a: a hovered line in the design mode reads the theme\'s selection '
      'at 60% over what lies under it', (tester) async {
    final v = controllerOn(white);
    await pumpView(tester, v, ThemeMode.light, FloorPlanMode.design,
        theme: const FloorPlanTheme(selectionOnLight: onLight));
    final (ix, iy) = pixelOf(tester, Vector2(sampleX, inkY));
    final under = (await shoot(tester)).rgbAt(ix, iy);

    v.c.activeSelection.setHover(SelectionKey.root(v.ink));
    await tester.pump();
    final hovered = (await shoot(tester)).rgbAt(ix, iy);
    // Straight alpha at 0x99 / 0xFF over the pixel without the hover.
    const alpha = 0x99 / 0xFF;
    int channel(int s) => (((rgbOf(onLight) >> s) & 0xFF) * alpha +
            ((under >> s) & 0xFF) * (1 - alpha))
        .round();
    final want = (channel(16) << 16) | (channel(8) << 8) | channel(0);
    expect(channelDistance(hovered, want), lessThanOrEqualTo(3),
        reason: 'hover ${hex(hovered)} over ${hex(under)}, want ${hex(want)}');
    // Cleared before the tree goes: a hover alive at teardown makes the
    // interaction layer's release notify the selection panel while it is
    // being deactivated (an existing behaviour, not this test's subject).
    v.c.activeSelection.setHover(null);
    await tester.pump();
  });

  testWidgets(
      'a bare PlannerShell reads the ambient extension: a page-less plan on '
      'its canvasBackground, its selectionOnDark and its width',
      (tester) async {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final f = paletteDoc(m, paper: null);
    windowAt(tester, const Size(1440, 900));
    const ambient = FloorPlanTheme(
        canvasBackground: canvas, selectionOnDark: onDark, selectionWidth: 4);
    await pumpHome(tester, PlannerShell(document: f.doc), ThemeMode.light,
        ambient: ambient);
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    view.camera.value = paletteCamera;
    view.selection.replace([SelectionKey.root(f.selected)]);
    await tester.pump();

    final shot = await shoot(tester);
    expect(hex(surroundAt(shot, tester)), hex(rgbOf(canvas)));
    expectLightInk(look(tester, shot), 'bare shell');
    expectSelectionRgb(shot, tester, onDark, 'bare shell');
    expect(outerRowsAre(shot, tester, onDark), (true, true));
  });

  for (final viewMode in FloorPlanMode.values) {
    testWidgets(
        'R-1 (${viewMode.name}): a page-less plan under the dark theme on a '
        'light canvasBackground: the surround is it, the ink black, the '
        'selection selectionOnLight', (tester) async {
      const lightCanvas = Color(0xFFFFF3E0);
      expect(foregroundFor(lightCanvas.toARGB32() & 0xFFFFFF), 0x000000);
      final v = controllerOn(null);
      await pumpView(tester, v, ThemeMode.dark, viewMode,
          theme: const FloorPlanTheme(
              canvasBackground: lightCanvas,
              selectionOnLight: onLight,
              selectionOnDark: onDark));
      final shot = await shoot(tester);
      expect(hex(surroundAt(shot, tester)), hex(rgbOf(lightCanvas)));
      expectDarkInk(look(tester, shot), 'page-less on a light canvas');
      expectSelectionRgb(shot, tester, onLight, 'page-less, dark theme');
    });
  }
}
