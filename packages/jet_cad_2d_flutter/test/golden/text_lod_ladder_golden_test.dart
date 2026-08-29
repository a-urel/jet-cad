@Tags(['golden'])
library;

// Three rungs, one axis: the level-of-detail threshold. One drawing carrying
// three text heights, framed so the smallest is culled, the largest is not,
// and the middle sits near the boundary — so the ladder pins
// `kMinTextCapPixels` visually and goes red if the constant moves.
//
// The three strings share one document and one camera; only
// `DraftCanvas.minTextCapPixels` changes between rungs. Rung 1 renders at the
// default threshold (3.0): the small string's on-screen cap height sits well
// under it and is culled, the middle and large strings sit above it and are
// drawn. Rung 2 renders the same document at `minTextCapPixels: 0.0` — the
// control arm, disabling the cull, so all three are drawn regardless of size.
// Rung 3 renders it at a threshold above every string's on-screen cap height,
// so none are drawn.
//
// **Ahem is enough, and that is not an oversight.** The other text ladder
// (`text_ladder_golden_test.dart`) needs `fonts/Roboto-Regular.ttf` because it
// asserts things about glyph *shape* — justification, rotation, shear,
// mirroring. The cull decision reads no metrics at all —
// `layout.height * chain.scaleMagnitude` against a constant, in
// `DraftPainter._drawText` — so nothing here depends on which font is loaded,
// and the default test font (Ahem-like solid glyph boxes) is exactly as good
// a witness as a real one.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import '../support/triangle_rasterizer.dart';

const Size kGoldenViewport = Size(400, 300);
const Key kCanvasKey = Key('golden-canvas');

/// The world box every rung is framed to, at the viewport's own aspect ratio
/// so `ViewportTransform.fit` adds no letterbox: `fit`'s scale is
/// `0.95 * min(400 / 200, 300 / 150)` = `0.95 * 2.0` = `1.9` on both axes.
///
/// On-screen cap height is `height * 1.9` (no instance transform sits between
/// these entities and the camera, so `chain.scaleMagnitude` is this scale
/// exactly):
///
/// - small,  world height  1.0 -> 1.9 px  (below 3.0, culled at the default)
/// - middle, world height  1.8 -> 3.42 px (above 3.0, drawn at the default;
///   this is the "near the boundary" rung — 14% above the threshold, not
///   exactly on it, so the comparison stays unambiguous under `expectLater`'s
///   own tolerance)
/// - large,  world height 20.0 -> 38.0 px (drawn at the default with room to
///   spare)
final Aabb2 kWorld = Aabb2(Vector2(0, 0), Vector2(200, 150));

/// World heights of the three strings — see [kWorld]'s doc comment for the
/// on-screen cap heights they produce at this ladder's fixed camera.
const double kSmallHeight = 1.0;
const double kMiddleHeight = 1.8;
const double kLargeHeight = 20.0;

/// Rung 3's threshold, chosen above every string's on-screen cap height
/// (38.0, the large string's) so all three are culled.
const double kAboveAllThreshold = 50.0;

/// One document, one word ("LOD") at three world heights, each with a short
/// anchor tick at its baseline start so the vertices backend — which never
/// receives text; see [_rung] — still inks something at every rung, and a
/// reader can see where a culled string *would* have started.
DraftDocument _lodLadderFixture() {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = DraftDocument.empty(measurer: measurer);
  for (final (height, y, rgb) in const [
    (kSmallHeight, 30.0, 0xB71C1C),
    (kMiddleHeight, 75.0, 0x1B5E20),
    (kLargeHeight, 120.0, 0x0D47A1),
  ]) {
    _tick(doc, 20, y);
    _text(doc, 'LOD', x: 20, y: y, height: height, rgb: rgb);
  }
  return doc;
}

void _text(
  DraftDocument doc,
  String text, {
  required double x,
  required double y,
  required double height,
  required int rgb,
}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(rgb),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y]),
      scalars: Float64List.fromList([height, 0.0, 1.0, 0.0]),
    ),
  ));
}

/// A short horizontal tick at a text anchor, so the anchor is visible even
/// when the string above it is culled.
void _tick(DraftDocument doc, double x, double y) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 9,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList([x - 4, y, x, y]),
        scalars: Float64List.fromList(const [])),
  ));
}

Widget _framed(DraftDocument doc, double minTextCapPixels) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            key: kCanvasKey,
            width: kGoldenViewport.width,
            height: kGoldenViewport.height,
            child: DraftCanvas(
              // See the note in `dash_ladder_golden_test.dart`: these are the
              // canvas backend's goldens, pinned rather than left to the
              // platform default.
              backend: RenderBackend.canvas,
              document: doc,
              index: SpatialIndex(doc),
              resolver: DocumentStyleResolver(doc),
              camera: CameraController(
                  ViewportTransform.fit(kWorld, kGoldenViewport)),
              minTextCapPixels: minTextCapPixels,
            ),
          ),
        ),
      ),
    );

/// Renders one rung on one backend and compares it to that backend's PNG.
///
/// The canvas backend goes through [_framed] unchanged, matching the pattern
/// `dash_ladder_golden_test.dart` and `text_ladder_golden_test.dart` both use.
/// The vertices backend cannot go through `matchesGoldenFile` on the widget:
/// software Skia does not finish a `drawVertices` of this size, so its
/// triangles are scan-converted by `TriangleRasterizer` and the *image* is
/// matched instead.
///
/// **Text never reaches that triangle buffer, at all, on any rung — this is
/// load-bearing for reading the three `vertices/text_lod_ladder_*.png`
/// goldens, so it is traced rather than asserted.** `VerticesDrawSink.text`
/// (`vertices_draw_sink.dart`) flushes whatever is pending, then calls
/// `_fallback?.text(...)`; `_fallback` is the very `CanvasDrawSink` the
/// vertices backend already carries (wired up in `DraftCanvas._attach`,
/// `draft_canvas.dart`), and `CanvasDrawSink.text` (`canvas_draw_sink.dart`)
/// draws it with `canvas.drawParagraph`, a call this test's `observer` never
/// sees — it is wired to `VerticesDrawSink`'s own `flush`, i.e. to
/// `canvas.drawVertices` submissions only. A paragraph painted straight onto
/// the real `Canvas` and a triangle buffer's flush are two different calls on
/// two different code paths; nothing here chooses between them per rung, so
/// nothing about `minTextCapPixels` can move what the rasterizer sees.
///
/// This is not a property of this fixture. `text_ladder_golden_test.dart`'s
/// own vertices goldens carry the identical limitation and say so in their
/// own doc comment ("none of its glyphs ... never reaches the triangle
/// buffer") — confirmed by opening `vertices/text_ladder_1.png` and
/// `vertices/text_ladder_3.png` by eye: rung 1 is one red rule and nothing
/// else, rung 3 is four crosses and nothing else, in both cases exactly the
/// anchor geometry and no glyph of "JUSTIFY" or "ROTATE" anywhere. Those five
/// PNGs differ from each other only because each rung there is a *different
/// fixture* with different anchor rules or crosses — not because any of them
/// carries text.
///
/// This ladder's three rungs share one fixture and one camera and vary only
/// the threshold, so once text is out of reach the three
/// `vertices/text_lod_ladder_*.png` goldens have nothing left to differ on:
/// they carry the same three anchor ticks and are byte-identical by
/// construction, not by omission. Each still guards the same regression the
/// rest of this suite's vertices goldens guard — that flushing before an
/// unbatchable op does not corrupt the batch, and that the picture reaching
/// the rasterizer is never empty — and the threshold itself is pinned by the
/// three canvas PNGs beside them.
Future<void> _rung(WidgetTester tester, DraftDocument doc, String name,
    double minTextCapPixels, RenderBackend backend) async {
  if (backend == RenderBackend.canvas) {
    await tester.pumpWidget(_framed(doc, minTextCapPixels));
    await expectLater(
        find.byKey(kCanvasKey), matchesGoldenFile('text_lod_ladder_$name.png'));
    return;
  }

  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera =
      CameraController(ViewportTransform.fit(kWorld, kGoldenViewport));
  addTearDown(camera.dispose);

  final key = GlobalKey<DraftCanvasState>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: kGoldenViewport.width,
          height: kGoldenViewport.height,
          child: DraftCanvas(
              key: key,
              document: doc,
              index: index,
              resolver: DocumentStyleResolver(doc),
              camera: camera,
              backend: backend,
              minTextCapPixels: minTextCapPixels),
        ),
      ),
    ),
  ));

  // `VerticesDrawSink`'s width floor (`kMinStrokeDevicePixels`) and the
  // colour fade below it are *device*-pixel quantities, but the buffer's
  // positions — what `TriangleRasterizer` scan-converts — are logical
  // pixels. A rasterizer built at logical resolution asks the wrong
  // question: at this widget's own device pixel ratio a stroke can be a
  // full device pixel wide (inked by Impeller) while covering under half a
  // *logical* pixel, which a logical-resolution, no-AA, pixel-centre sampler
  // can miss along its whole length. So the rasterizer is built at the
  // device resolution Impeller would rasterize at.
  //
  // The ratio is the **binding's**, and the sink is asserted against it
  // rather than read back from it. Reading it back made the rasterization
  // resolution follow any mutation of `devicePixelRatio`: deleting
  // `DraftCanvas`'s per-frame rebind (`draft_canvas.dart`, `vertices
  // ?.devicePixelRatio = MediaQuery.devicePixelRatioOf(context)`) leaves the
  // sink at its constructor default of 1.0, and every vertices golden then
  // failed only on *image size* — which one `flutter test
  // --update-goldens` absorbs, writing the wrong stroke widths into the PNGs
  // and locking the break in green forever. A named assertion is the one
  // thing `--update-goldens` cannot absorb.
  final dpr = tester.view.devicePixelRatio;
  expect(key.currentState!.vertices!.devicePixelRatio, dpr,
      reason: 'the sink must be at the binding\'s device pixel ratio: '
          'DraftCanvas rebinds it per frame from MediaQuery, and a sink left '
          'at its constructor default draws stroke widths for the wrong '
          'device. Do NOT regenerate the goldens to make this pass.');
  final rasterizer = TriangleRasterizer((kGoldenViewport.width * dpr).round(),
      (kGoldenViewport.height * dpr).round());
  // Attached after the first pump, and the widget pumped again: the state —
  // and the vertices sink it owns — does not exist until the first build.
  // The observer scales every position by `dpr` before handing it to the
  // device-resolution rasterizer above.
  key.currentState!.vertices!.observer = (positions, colors) {
    final scaled = Float32List(positions.length);
    for (var i = 0; i < positions.length; i++) {
      scaled[i] = positions[i] * dpr;
    }
    rasterizer.observe(scaled, colors);
  };
  // The first pump already painted once — the picture this golden pins —
  // but without an observer attached. Nothing about the document or the
  // camera changes for the second pump, `_DraftCustomPainter.shouldRepaint`
  // is unconditionally false, and the painter's own `repaint` listenable
  // never fires on its own, so a bare `tester.pump()` here finds nothing
  // dirty and skips the repaint entirely — confirmed by a probe that pumped
  // this exact sequence and read the observer back having seen zero
  // triangles. `markNeedsPaint` forces the same picture to paint again, this
  // time through the now-attached observer.
  tester
      .renderObject<RenderObject>(find.descendant(
          of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)))
      .markNeedsPaint();
  await tester.pump();

  // `rasterizer.toImage()` completes through `decodeImageFromPixels`, a real
  // engine callback. Confirmed by a minimal repro: once this test binding has
  // actually pumped a widget, the fake-async test zone never delivers that
  // callback and the await hangs forever; before any pump it resolves
  // immediately. `runAsync` steps outside the fake zone for the one call that
  // needs it.
  final image = (await tester.runAsync(rasterizer.toImage))!;
  addTearDown(image.dispose);

  // A golden that never inks a pixel passes forever and pins nothing --
  // confirmed by a `polyline` no-op mutation that left a logical-resolution
  // version of a golden green with zero geometry drawn. The three anchor
  // ticks are always present, regardless of the threshold, so this must
  // always ink something.
  expect(rasterizer.pixels.any((p) => p != 0), isTrue,
      reason: 'rung $name drew nothing: the three anchor ticks are always '
          'present, so a blank surface means the picture never reached the '
          'rasterizer');
  await expectLater(
      image, matchesGoldenFile('vertices/text_lod_ladder_$name.png'));
}

void main() {
  for (final (name, minTextCapPixels) in const [
    ('1', kMinTextCapPixels),
    ('2', 0.0),
    ('3', kAboveAllThreshold),
  ]) {
    for (final backend in RenderBackend.values) {
      // Skip the GPU-resident backend: it has no sink until Task 8 and will
      // never render in a test environment without actual GPU support.
      if (backend == RenderBackend.residentGpu) continue;
      testWidgets('text lod ladder rung $name ($backend)', (tester) async {
        await _rung(
            tester, _lodLadderFixture(), name, minTextCapPixels, backend);
      });
    }
  }
}
