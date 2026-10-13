// The renderer's scenes R1-R5 (package READMEs spec D5, A3): the sample
// flat in the renderer's own widgets (`RendererStage`, no planner widget),
// and the furniture library in `SymbolGallery`, written to
// jet_cad_2d_flutter/doc/screenshots/ under UPDATE_SCREENSHOTS=1. Public
// API only: the barrels, and `editor.dart` for the drawing and the
// gallery's grouping.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show BandMode;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/editor.dart'
    show startupPlan, symbolThumbnailDocument, searchSymbols, symbolIdOf;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart'
    show SymbolLibraryLoader, SymbolLibraryReady, furnitureSymbolSource;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/renderer_stage.dart';
import 'support/shots.dart';

const _package = 'jet_cad_2d_flutter';

/// The canvas inside the rulers: the wide frame less one ruler each way.
final Size _canvas =
    Size(kWide.width - kRulerThickness, kWide.height - kRulerThickness);

/// The sample flat over its own measurer, the stage's key, and the app
/// around them. The rulers draw their digits in the ambient family
/// (`RulerFrame`), which the app's `Material` sets to Roboto.
({GlobalKey<RendererStageState> key, Widget app}) _scene({bool dark = false}) {
  final key = GlobalKey<RendererStageState>();
  final document = startupPlan(FlutterTextMeasurer());
  return (
    key: key,
    app: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          fontFamily: 'Roboto'),
      home: Material(
        child: RendererStage(
            key: key, document: document, dark: dark, canvas: _canvas),
      ),
    ),
  );
}

/// The stage pumped at [kWide], its canvas at the size it was fitted to.
Future<RendererStageState> _pumpStage(WidgetTester tester,
    {bool dark = false}) async {
  final (:key, :app) = _scene(dark: dark);
  await pumpScene(tester, app);
  await settle(tester);
  expect(tester.getSize(find.byType(DraftCanvas)), _canvas,
      reason: 'the camera was fitted to the canvas it draws on');
  return key.currentState!;
}

/// [world] (millimetres, y up) as a global position on the canvas.
Offset _global(WidgetTester tester, RendererStageState stage, Offset world) {
  final s = stage.camera.value.worldToScreen(Vector2(world.dx, world.dy));
  return tester.getTopLeft(find.byType(DraftCanvas)) + Offset(s.x, s.y);
}

// The sample flat's outer corner (startup_plan.dart's kPlanOriginX/Y,
// unexported): the bedrooms are its top-left quarter.
const double _x0 = 12000, _y0 = 8000;

void main() {
  setUpAll(loadManifestFonts);

  testWidgets('R1 canvas_light.png: the sample flat, rulers, light',
      (tester) async {
    await _pumpStage(tester);
    await shoot(tester, package: _package, file: 'canvas_light.png');
  });

  testWidgets('R2 canvas_dark.png: the same on the dark canvas',
      (tester) async {
    await _pumpStage(tester, dark: true);
    await shoot(tester, package: _package, file: 'canvas_dark.png');
  });

  testWidgets('R3 selection_grips.png: a window selection, one hovered',
      (tester) async {
    final stage = await _pumpStage(tester);
    final select = stage.tools.active as SelectTool;
    // A window, left to right, from the empty sheet above-left of the flat
    // down to the bedrooms' partition: both bedrooms' beds, rooms and
    // partition, their doors and windows -- and nothing that runs out of
    // the box, so the exterior walls stay unselected.
    final from = _global(tester, stage, const Offset(_x0 - 400, _y0 + 9400));
    final to = _global(tester, stage, const Offset(_x0 + 5080, _y0 + 4880));
    expect(from.dx < to.dx, isTrue, reason: 'a window runs left to right');
    final drag = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await drag.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump();
    expect(select.dragKind, DragKind.band, reason: 'pressed on no entity');
    await drag.moveTo(to);
    await tester.pump();
    expect(select.bandMode, BandMode.window);
    await drag.up();
    await drag.removePointer();
    await tester.pump();
    expect(stage.selection.length, greaterThan(2), reason: 'a few selected');
    // The mouse back, over the sofa's long lower edge, outside the window.
    final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await hover.addPointer(
        location: _global(tester, stage, const Offset(_x0 + 4400, _y0 + 3800)));
    await hover
        .moveTo(_global(tester, stage, const Offset(_x0 + 7500, _y0 + 4500)));
    await tester.pump();
    expect(stage.selection.hover, isNotNull, reason: 'one entity hovered');
    expect(stage.selection.contains(stage.selection.hover!), isFalse);
    await shoot(tester, package: _package, file: 'selection_grips.png');
    await hover.removePointer();
  });

  testWidgets('R4 selection_band.png: a crossing band mid-drag',
      (tester) async {
    final stage = await _pumpStage(tester);
    final select = stage.tools.active as SelectTool;
    // Right to left, held: from the empty surround right of the flat, past
    // the overall depth's dimension, over the bath, the kitchen and the
    // living room's sofa -- a crossing band.
    final from = _global(tester, stage, const Offset(_x0 + 15500, _y0 + 1600));
    final to = _global(tester, stage, const Offset(_x0 + 6500, _y0 + 6200));
    expect(from.dx > to.dx, isTrue, reason: 'a crossing runs right to left');
    final drag = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await drag.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump();
    expect(select.dragKind, DragKind.band, reason: 'pressed on no entity');
    await drag.moveTo(to);
    await tester.pump();
    expect(select.bandMode, BandMode.crossing);
    await shoot(tester, package: _package, file: 'selection_band.png');
    await drag.up();
    await tester.pump();
  });

  testWidgets('R5 symbol_gallery.png: the furniture library, at kPanel',
      (tester) async {
    final loader = SymbolLibraryLoader(sources: const [furnitureSymbolSource]);
    addTearDown(loader.dispose);
    await tester.runAsync(loader.load);
    final library = (loader.state as SymbolLibraryReady).library;
    // English, the library's own words: `searchSymbols`'s default
    // (`SymbolWords.english`, which editor.dart does not export), whose
    // name and category are the entry's own.
    final groups = searchSymbols(library.entries, '');
    expect(groups, isNotEmpty);
    final measurer = FlutterTextMeasurer();
    final thumbnails = SymbolThumbnails(maxEntries: 128);
    addTearDown(thumbnails.dispose);
    final gallery = SymbolGallery(
      categories: [
        for (final g in groups)
          GalleryCategory(
            id: g.category,
            name: g.category,
            symbols: [
              for (final e in g.symbols)
                GallerySymbol(
                  id: symbolIdOf(e),
                  label: e.name,
                  thumbnailKey: symbolIdOf(e),
                  thumbnailDocument: () => symbolThumbnailDocument(e, measurer),
                ),
            ],
          ),
      ],
      selectedId: null,
      enabled: true,
      onSelect: (_) {},
      thumbnails: thumbnails,
      foreground: 0x1F1F1F,
      selectedForeground: 0x0B57D0,
      cellColor: const Color(0xFFFFFFFF),
    );
    await pumpScene(
        tester,
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Material(child: gallery),
        ),
        size: kPanel);
    // One category open (spec D5): every other header collapsed, so the
    // panel shows the library's categories and one of them whole.
    const open = 'Bathroom';
    expect(groups.map((g) => g.category), contains(open));
    for (final g in groups) {
      if (g.category == open) continue;
      final header = find.byKey(Key('symbol-group-${g.category}'));
      await tester.ensureVisible(header);
      await tester.tap(header);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // No state to wait on: the thumbnails paint asynchronously, over
    // settle's forty rounds (an eyes-on check confirms they did).
    await settle(tester);
    await shoot(tester,
        package: _package, file: 'symbol_gallery.png', size: kPanel);
  });
}
