// Ported from jet_cad_floor_plan/test/host/theme_canvas_test.dart; assertions unchanged.
//
// Host embedding API spec T-1's selection and canvas rows (Slice 3 plan
// Task 2): `selectionOnLight`, `selectionOnDark` and `selectionWidth` reach
// the selection overlay, per paper; `canvasBackground` is the surround and
// a page-less plan's paper, so the ink, the paper's set and the selection
// follow it as they follow `scheme.surface` today, a translucent one by its
// RGB. Each test of today's mode loop runs in both modes: design through
// `PlanCanvas`, service through `PlanServiceView` (today's selection-mode
// runs, 2b Task 16: P-6, M-H33 twice, selectionOnDark, only
// selectionOnLight, selectionWidth, the guide, T2-d and R-1); invariant 4
// (the export and the plan's text) is 2a Tasks 19 and 20's and, in service,
// theme_service_test.dart's.
//
// Read back in pixels on the dark theme's planner fixture
// (support/canvas_fixture.dart: the real seed's themes at zero animation,
// White, Blueprint and the dark canvas, a page or none, a y-up, off-origin
// camera at 0.125 px/mm with the lines on pixel centres), through
// `PlanCanvas` under a `PlanThemeScope`, and on a bare `PlanCanvas` for the
// ambient-only path. The theme's colours are none of the sets' colours.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart' show PlanThemeScope;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_fixture.dart';

/// The theme's colours: none is a palette colour or another's.
const Color onLight = Color(0xFFD81B60);
const Color onDark = Color(0xFFFFD54F);
const Color canvas = Color(0xFF263238);

/// A controller over the fixture's document on [paper] (null: no page),
/// with the selected line's and the ink witness's handles (a decode keeps
/// handles).
({PlanController c, Handle selected, Handle ink}) controllerOn(int? paper) =>
    paletteController(paper: paper);

/// The fixture's light and dark themes, each carrying [ambient] when given.
ThemeData withExtension(ThemeData theme, PlanTheme? ambient) =>
    ambient == null ? theme : theme.copyWith(extensions: [ambient]);

/// [home] under the seed's themes (carrying [ambient]) in [mode], at zero
/// theme animation, inside the capture boundary. The tree keeps its shape
/// across calls, so every state below survives a re-pump.
Future<void> pumpHome(WidgetTester tester, Widget home, ThemeMode mode,
        {PlanTheme? ambient}) =>
    tester.pumpWidget(MaterialApp(
      theme: withExtension(lightTheme, ambient),
      darkTheme: withExtension(darkTheme, ambient),
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: RepaintBoundary(key: shotKey, child: home),
    ));

/// [c]'s canvas under the view's own [theme] (Task 9's PlanThemeScope:
/// the view's theme over the ambient one, as `FloorPlanView(theme:)`
/// resolved it).
Widget viewOf(PlanController c,
        {PlanTheme? theme, PlanMode viewMode = PlanMode.design}) =>
    Scaffold(
        body: viewMode == PlanMode.design
            ? PlanThemeScope(view: theme, child: PlanCanvas(controller: c))
            : PlanServiceView(controller: c, theme: theme));

/// Pumps [v]'s canvas under [mode], sets the fixture's camera and selects
/// the line.
Future<void> pumpView(WidgetTester tester,
    ({PlanController c, Handle selected, Handle ink}) v, ThemeMode mode,
    {PlanTheme? theme,
    PlanTheme? ambient,
    PlanMode viewMode = PlanMode.design}) async {
  windowAt(tester, const Size(1440, 900));
  v.c.setMode(viewMode);
  await pumpHome(tester, viewOf(v.c, theme: theme, viewMode: viewMode), mode,
      ambient: ambient);
  await tester.pump();
  await tester.pump();
  v.c.camera.value = paletteCamera;
  v.c.activeSelection.replace([SelectionKey.root(v.selected)]);
  await tester.pump();
}

/// The selection overlay's painter in the view.
SelectionOverlayPainter overlayOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(
        of: find.byType(PlanCanvasView), matching: find.byType(CustomPaint)))
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

  for (final viewMode in PlanMode.values) {
    final m = viewMode.name;

    testWidgets(
        'P-6 ($m): with no theme the view hands the overlay today\'s const '
        'set and 2 px', (tester) async {
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, viewMode: viewMode);
      final view = tester.widget<PlanCanvasView>(find.byType(PlanCanvasView));
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
          PlanTheme(selectionOnLight: onLight, selectionOnDark: onDark);
      for (final (paper, want, set) in [
        (white, onLight, PaperPalette.light),
        (blueprint, onDark, PaperPalette.dark),
      ]) {
        final v = controllerOn(paper);
        await pumpView(tester, v, ThemeMode.light, theme: theme);
        final shot = await shoot(tester);
        expectSelectionRgb(shot, tester, want, hex(paper));
        expect(tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
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
      await pumpView(tester, v, ThemeMode.dark,
          viewMode: viewMode,
          theme: const PlanTheme(
              selectionOnLight: onLight, selectionOnDark: onDark));
      final shot = await shoot(tester);
      expectSelectionRgb(shot, tester, onDark, 'dark canvas');
      expectLightInk(look(tester, shot), 'dark canvas');
    });

    testWidgets(
        'only selectionOnLight ($m): Blueprint keeps the dark set\'s '
        '0xFF7FB2FF, White takes the theme\'s (per paper)', (tester) async {
      const theme = PlanTheme(selectionOnLight: onLight);
      var v = controllerOn(blueprint);
      await pumpView(tester, v, ThemeMode.light, theme: theme);
      var shot = await shoot(tester);
      expectSelectionRgb(shot, tester, const Color(0xFF7FB2FF), 'Blueprint');
      expect(
          identical(
              tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
              PaperPalette.dark),
          isTrue);
      await tester.pumpWidget(const SizedBox());

      v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, theme: theme);
      shot = await shoot(tester);
      expectSelectionRgb(shot, tester, onLight, 'White');
    });

    testWidgets(
        'selectionWidth: 4 ($m) covers the rows a 2 px stroke covers only '
        'half; the outline stays the paper\'s colour', (tester) async {
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light, viewMode: viewMode);
      var shot = await shoot(tester);
      expect(outerRowsAre(shot, tester, PaperPalette.light.selection),
          (false, false),
          reason: 'the control: 2 px covers the rows beside its own half');

      await pumpHome(
          tester,
          viewOf(v.c,
              theme: const PlanTheme(selectionWidth: 4), viewMode: viewMode),
          ThemeMode.light);
      expect(tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
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
      await pumpView(tester, v, ThemeMode.light,
          viewMode: viewMode, theme: const PlanTheme(canvasBackground: canvas));
      final shot = await shoot(tester);
      expect(hex(surroundAt(shot, tester)), hex(rgbOf(canvas)));
      final (cx, cy) = areaPixel(tester, 700, 20);
      expect(hex(shot.rgbAt(cx, cy)), hex(rgbOf(canvas)),
          reason: 'right of where a sheet would be: no sheet, all canvas');
      expectLightInk(look(tester, shot), 'page-less on the canvas');
      expectSelectionRgb(shot, tester, const Color(0xFF7FB2FF), 'page-less');
      expect(
          identical(
              tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
              PaperPalette.dark),
          isTrue);
    });

    testWidgets(
        'the guide ($m): a translucent canvasBackground (0x40000000) on a '
        'page-less plan under the light theme: the ink is chosen on its '
        'RGB, black, so the ink is white and the overlays take the dark set',
        (tester) async {
      const translucent = Color(0x40000000);
      expect(foregroundFor(rgbOf(translucent)), 0xFFFFFF);
      expect(
          foregroundFor(rgbOf(
              Color.alphaBlend(translucent, lightTheme.colorScheme.surface))),
          0x000000,
          reason: 'premise: composited over the surface it would read light');
      final v = controllerOn(null);
      await pumpView(tester, v, ThemeMode.light,
          viewMode: viewMode,
          theme: const PlanTheme(canvasBackground: translucent));
      expect(
          identical(
              tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
              PaperPalette.dark),
          isTrue);
      expect(identical(overlayOf(tester).paper, PaperPalette.dark), isTrue);
      final seen = look(tester, await shoot(tester));
      expectLightInk(seen, 'translucent canvas');
      expectSelection(seen, PaperPalette.dark, 'translucent canvas');
    });

    testWidgets(
        'T2-d ($m): with a page, canvasBackground colours the surround only; '
        'the sheet, the ink and the selection are the White page\'s',
        (tester) async {
      final v = controllerOn(white);
      await pumpView(tester, v, ThemeMode.light,
          viewMode: viewMode, theme: const PlanTheme(canvasBackground: canvas));
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
          identical(
              tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
              PaperPalette.light),
          isTrue);
    });
  }

  testWidgets(
      'T2-a: a hovered line in the design mode reads the theme\'s selection '
      'at 60% over what lies under it', (tester) async {
    final v = controllerOn(white);
    await pumpView(tester, v, ThemeMode.light,
        theme: const PlanTheme(selectionOnLight: onLight));
    final (ix, iy) = pixelOf(tester, Vector2(sampleX, inkY));
    final under = (await shoot(tester)).rgbAt(ix, iy);

    v.c.selection.setHover(SelectionKey.root(v.ink));
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
    v.c.selection.setHover(null);
    await tester.pump();
  });

  testWidgets(
      'a bare PlanCanvas reads the ambient extension: a page-less plan on '
      'its canvasBackground, its selectionOnDark and its width',
      (tester) async {
    final f = paletteController(paper: null);
    windowAt(tester, const Size(1440, 900));
    const ambient = PlanTheme(
        canvasBackground: canvas, selectionOnDark: onDark, selectionWidth: 4);
    await pumpHome(
        tester, Scaffold(body: PlanCanvas(controller: f.c)), ThemeMode.light,
        ambient: ambient);
    await tester.pump();
    f.c.camera.value = paletteCamera;
    f.c.selection.replace([SelectionKey.root(f.selected)]);
    await tester.pump();

    final shot = await shoot(tester);
    expect(hex(surroundAt(shot, tester)), hex(rgbOf(canvas)));
    expectLightInk(look(tester, shot), 'bare shell');
    expectSelectionRgb(shot, tester, onDark, 'bare shell');
    expect(outerRowsAre(shot, tester, onDark), (true, true));
  });

  for (final viewMode in PlanMode.values) {
    testWidgets(
        'R-1 (${viewMode.name}): a page-less plan under the dark theme on a '
        'light canvasBackground: the surround is it, the ink black, the '
        'selection selectionOnLight', (tester) async {
      const lightCanvas = Color(0xFFFFF3E0);
      expect(foregroundFor(lightCanvas.toARGB32() & 0xFFFFFF), 0x000000);
      final v = controllerOn(null);
      await pumpView(tester, v, ThemeMode.dark,
          viewMode: viewMode,
          theme: const PlanTheme(
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
