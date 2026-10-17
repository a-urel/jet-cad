// The renderer's scenes R1-R5 (package READMEs spec D5): the sample flat in
// the renderer's own widgets (`RendererStage`, no plan editor widget), and
// the renderer's own `SymbolGallery` over a hand-built library (umbrella A11:
// a package's pictures show what the package itself gives), written to
// jet_cad_2d_flutter/doc/screenshots/ under UPDATE_SCREENSHOTS=1. Public
// API only: the barrels.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show
        BandMode,
        DraftDocument,
        EntityKind,
        GeometryPayload,
        ReservedHandles,
        addDrafted,
        arcPayload,
        circlePayload,
        foregroundFor,
        linePayload,
        rectanglePayload;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
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
  // The plan library builds the sample flat (spec 3a C1.9): the document it
  // owns, with the kit's parametric system, is the renderer's fixture.
  final controller =
      PlanController(kits: [architectureKit], build: buildSampleFlat);
  addTearDown(controller.dispose);
  return (
    key: key,
    app: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          fontFamily: 'Roboto'),
      home: Material(
        child: RendererStage(
            key: key,
            document: controller.document,
            dark: dark,
            canvas: _canvas),
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

// The sample flat's outer corner (buildSampleFlat's kPlanOriginX/Y,
// unexported): the bedrooms are its top-left quarter.
const double _x0 = 12000, _y0 = 8000;

/// The gallery picture's open category (spec D5): its grid, under the three
/// category headers, is what the panel shows.
const String _openCategory = 'openings';

/// The renderer's own gallery (A11): the renderer's public `SymbolGallery`
/// over a library this scene builds from the engine's own shapes -- its
/// categories, and for each symbol a small document its thumbnail paints --
/// because the gallery widget knows no symbol type. Nothing here is another
/// package's: the picture is the renderer's widget and the engine's shapes.
List<GalleryCategory> _library() => [
      GalleryCategory(name: 'Furniture', id: 'furniture', symbols: [
        _symbol('chair', 'Chair', (s) {
          s.rect(0, 0, 450, 450);
          s.line(0, 90, 450, 90);
        }),
        _symbol('table', 'Table', (s) => s.rect(0, 0, 1400, 800)),
        _symbol('round_table', 'Round table', (s) => s.circle(700, 700, 700)),
        _symbol('sofa', 'Sofa', (s) {
          s.rect(0, 0, 1800, 800);
          s.line(250, 0, 250, 800);
          s.line(1550, 0, 1550, 800);
        }),
      ]),
      GalleryCategory(name: 'Openings', id: 'openings', symbols: [
        _symbol('door', 'Door', (s) {
          s.line(-1400, 0, -300, 0);
          s.line(300, 0, 1400, 0);
          s.line(300, 0, 300, 1100);
          s.arc(300, 0, 1100, 0, math.pi / 2);
        }),
        _symbol('window', 'Window', (s) {
          s.rect(-900, -140, 900, 140);
          s.line(-900, 0, 900, 0);
        }),
        _symbol('gap', 'Gap', (s) {
          s.line(-1500, 0, -400, 0);
          s.line(400, 0, 1500, 0);
        }),
        _symbol('sliding_door', 'Sliding door', (s) {
          s.rect(-900, 0, 0, 120);
          s.rect(0, 220, 900, 340);
        }),
      ]),
      GalleryCategory(name: 'Fixtures', id: 'fixtures', symbols: [
        _symbol('sink', 'Sink', (s) {
          s.rect(-500, -350, 500, 350);
          s.circle(0, 0, 180);
        }),
        _symbol('stove', 'Stove', (s) {
          s.rect(-450, -450, 450, 450);
          s.circle(-220, -220, 110);
          s.circle(220, -220, 110);
          s.circle(-220, 220, 110);
          s.circle(220, 220, 110);
        }),
        _symbol('shower', 'Shower', (s) {
          s.rect(-500, -500, 500, 500);
          s.circle(0, 0, 90);
          s.line(-500, -500, 500, 500);
        }),
        _symbol('bath', 'Bath', (s) {
          s.rect(-900, -400, 900, 400);
          s.circle(-500, 0, 250);
        }),
      ]),
    ];

/// One cell of the library: [id] keys the cell and the thumbnail cache,
/// [label] is shown under it, and [draw] fills the thumbnail's document.
GallerySymbol _symbol(String id, String label, void Function(_Sheet) draw) =>
    GallerySymbol(
      id: id,
      label: label,
      thumbnailKey: id,
      thumbnailDocument: () => _document(draw),
    );

/// A document of plain engine shapes for one thumbnail.
DraftDocument _document(void Function(_Sheet) draw) {
  final doc = DraftDocument.empty();
  draw(_Sheet(doc));
  return doc;
}

/// Adds the engine's own entities to a document: what the gallery's
/// thumbnails are made of, since the renderer knows no symbol type.
class _Sheet {
  _Sheet(this.doc);

  final DraftDocument doc;

  void line(double x1, double y1, double x2, double y2) =>
      _add(EntityKind.line, linePayload(Vector2(x1, y1), Vector2(x2, y2)));

  void rect(double x1, double y1, double x2, double y2) => _add(
      EntityKind.polyline, rectanglePayload(Vector2(x1, y1), Vector2(x2, y2)));

  void circle(double x, double y, double r) =>
      _add(EntityKind.circle, circlePayload(Vector2(x, y), r));

  void arc(double x, double y, double r, double start, double sweep) =>
      _add(EntityKind.arc, arcPayload(Vector2(x, y), r, start, sweep));

  void _add(EntityKind kind, GeometryPayload payload) => doc.commands.execute(
      addDrafted(doc, kind, payload, layer: ReservedHandles.layerZero));
}

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

  testWidgets('R5 symbol_gallery.png: the renderer\'s own SymbolGallery',
      (tester) async {
    // The renderer's public `SymbolGallery` (A11): a collapsible library of
    // thumbnails the renderer itself paints, its categories hand-built here
    // so no other package appears in the picture. One category open (spec
    // D5), the rest collapsed.
    final thumbnails = SymbolThumbnails();
    addTearDown(thumbnails.dispose);
    final categories = _library();
    await pumpScene(
        tester,
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Material(
            color: const Color(0xFFFDFDFD),
            child: SymbolGallery(
              categories: categories,
              selectedId: null,
              enabled: true,
              onSelect: (_) {},
              thumbnails: thumbnails,
              foreground: foregroundFor(0xF2F2F2),
              selectedForeground: foregroundFor(0xF2F2F2),
              cellColor: const Color(0xFFF2F2F2),
            ),
          ),
        ),
        size: kPanel);
    await settle(tester);
    // Collapse every category, in the gallery's order: only visible headers
    // are built, so each collapse reveals the next. Then open the one to
    // show.
    for (final c in categories) {
      final header = find.byKey(Key('symbol-group-${c.id}'));
      await tester.ensureVisible(header);
      await tester.tap(header);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final open = find.byKey(Key('symbol-group-$_openCategory'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    // The thumbnails paint asynchronously, over settle's rounds (an eyes-on
    // check confirms they did).
    await settle(tester);
    await shoot(tester,
        package: _package, file: 'symbol_gallery.png', size: kPanel);
  });
}
