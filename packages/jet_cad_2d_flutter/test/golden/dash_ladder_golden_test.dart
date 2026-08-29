@Tags(['golden'])
library;

// One fixture, the same dashed geometry at five zoom levels, so the collapse
// floor's effect is visible as a ladder rather than as a number.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import '../support/triangle_rasterizer.dart';

const Size kGoldenViewport = Size(400, 300);
const Key kCanvasKey = Key('golden-canvas');

/// Six horizontal dashed rules, and one dashed circle, spanning the width.
DraftDocument dashLadderFixture() {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = DraftDocument.empty(measurer: measurer);
  final dashed = doc.handleSeed.next();
  doc.tables.linetypes.add(LinetypeRecord(
    handle: dashed,
    name: 'DASHED',
    description: '__ __ __',
    pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
  ));
  for (var i = 0; i < 6; i++) {
    _dashedEntity(doc, dashed, EntityKind.polyline,
        [-500, -60.0 + i * 24, 500, -60.0 + i * 24], const []);
  }
  _dashedEntity(doc, dashed, EntityKind.circle, [0, 0], const [90]);
  return doc;
}

void _dashedEntity(DraftDocument doc, Handle linetype, EntityKind kind,
    List<double> coords, List<double> scalars) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: linetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars)),
  ));
}

Widget _at(DraftDocument doc, double halfSpan) {
  final index = SpatialIndex(doc);
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          key: kCanvasKey,
          width: kGoldenViewport.width,
          height: kGoldenViewport.height,
          child: DraftCanvas(
            // The canvas backend explicitly: these 14 PNGs are the canvas
            // backend's suite, and Plan 3d Task 10 renders the same fixtures
            // through the vertices backend into a second set. Left at the
            // platform default they would follow whatever
            // `defaultRenderBackend()` returns, which is not what a golden
            // named for one renderer should do.
            backend: RenderBackend.canvas,
            document: doc,
            index: index,
            resolver: DocumentStyleResolver(doc),
            camera: CameraController(ViewportTransform.fit(
                Aabb2(
                    Vector2(-halfSpan, -halfSpan), Vector2(halfSpan, halfSpan)),
                kGoldenViewport)),
          ),
        ),
      ),
    ),
  );
}

/// Renders one rung on one backend and compares it to that backend's PNG.
///
/// The canvas backend goes through [_at] unchanged, so these five PNGs stay
/// pixel-identical to what they were before this backend loop existed. The
/// vertices backend cannot go through `matchesGoldenFile` on the widget:
/// software Skia does not finish a `drawVertices` of this size, so its
/// triangles are scan-converted by `TriangleRasterizer` and the *image* is
/// matched instead.
///
/// The two sets are framed differently, and this does not try to reconcile
/// it: [_at] matches on `find.byKey(kCanvasKey)`, which sits on the outer
/// `SizedBox`, and `matchesGoldenFile` walks up from there to the nearest
/// `RepaintBoundary` -- not necessarily the one `DraftCanvas` owns
/// internally. The vertices path below rasterizes exactly `DraftCanvas`'s
/// own surface. The two PNGs are not pixel-registered captures of the same
/// boundary; each is the right instrument for its own backend.
Future<void> _rung(WidgetTester tester, DraftDocument doc, double halfSpan,
    String name, RenderBackend backend) async {
  if (backend == RenderBackend.canvas) {
    await tester.pumpWidget(_at(doc, halfSpan));
    await expectLater(
        find.byKey(kCanvasKey), matchesGoldenFile('dash_ladder_$name.png'));
    return;
  }

  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera = CameraController(ViewportTransform.fit(
      Aabb2(Vector2(-halfSpan, -halfSpan), Vector2(halfSpan, halfSpan)),
      kGoldenViewport));
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
              backend: backend),
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
  // version of this golden green with zero geometry drawn. Every rung draws
  // at least the six dashed rules, so this must always ink something.
  expect(rasterizer.pixels.any((p) => p != 0), isTrue,
      reason: 'rung $name drew nothing: the dashed rules and circle are '
          'always present, so a blank surface means the picture never '
          'reached the rasterizer');
  await expectLater(image, matchesGoldenFile('vertices/dash_ladder_$name.png'));
}

void main() {
  for (final (name, halfSpan) in const [
    ('1', 60.0),
    ('2', 150.0),
    ('3', 400.0),
    ('4', 1200.0),
    ('5', 4000.0),
  ]) {
    for (final backend in RenderBackend.values) {
      // Skip the GPU-resident backend: it has no sink until Task 8 and will
      // never render in a test environment without actual GPU support.
      if (backend == RenderBackend.residentGpu) continue;
      testWidgets('dash ladder rung $name ($backend)', (tester) async {
        await _rung(tester, dashLadderFixture(), halfSpan, name, backend);
      });
    }
  }
}
