@Tags(['golden'])
library;

// One fixture, four fills at three zoom levels, so a mutant that only shows
// up at one scale -- the circle's per-frame fan, chiefly -- cannot hide
// behind a lucky rung.
//
// The fixture carries five properties in one drawing, each a named mutant
// from an earlier task that a normal-looking fixture would let through (see
// this task's brief):
//
// - An **L-shaped** (concave) boundary, bottom-left, whose first vertex is
//   chosen so a fan from it is *not* star-shaped: the segment from that
//   vertex to the far corner of the notch's rectangle crosses outside the
//   polygon. A fan mistakenly covers the notch; ear-clipping does not.
// - A **clockwise** boundary, bottom-right: a simple square listed in
//   clockwise order, so it only fills at all if winding normalisation
//   reverses it before ear-clipping, which assumes counter-clockwise.
// - A **circle** boundary, top-left: fanned per frame at the step count its
//   own stroke uses, never triangulated ahead of time.
// - A fill on a **hairline** layer, top-right: its own resolved lineweight
//   is thin enough (0.01 mm) that routing it through `_coveredArgb` -- the
//   vertices sink's sub-pixel stroke fade -- would visibly dim it, where a
//   fill has no width of its own and must not fade at all.
//
// Every fill's colour differs from its boundary's black stroke, so an
// inverted fill/boundary handle order -- the fill painting over its own
// outline instead of under it -- is visible rather than merely wrong.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import '../support/triangle_rasterizer.dart';

const Size kGoldenViewport = Size(400, 300);
const Key kCanvasKey = Key('fill-golden-canvas');

/// Four regions, one of each property this task names, all within a
/// [-50, 50] world box so half-span 60 frames the whole drawing.
DraftDocument fillLadderFixture() {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = DraftDocument.empty(measurer: measurer);

  // A layer whose lineweight is thin enough (0.01 mm) that at this file's
  // scale and a device pixel ratio of 3.0 the device width is about 0.11
  // device pixels -- comfortably under `VerticesDrawSink.kMinStrokeDevicePixels`
  // (1.0), so `_coveredArgb` would fade a stroke of this width hard. A fill
  // routed through it by mistake would dim visibly; routed correctly (never
  // through `_coveredArgb`) it stays opaque regardless.
  final hairline = doc.handleSeed.next();
  doc.tables.layers.add(LayerRecord(
    handle: hairline,
    name: 'HAIRLINE',
    color: const IndexedColor(7),
    linetype: ReservedHandles.continuousLinetype,
    lineweight: 1,
    transparency: 0,
  ));

  // The L-shape, bottom-left: vertex 0 sits at the far corner from the
  // notch's own far corner, so the chord from vertex 0 to the boundary
  // vertex across the notch (index 3 below) passes through removed area --
  // the segment from (-50, -10) to (-10, -30) crosses (-30, -20), which lies
  // in the excised square [-30, -10] x [-30, -10]. A fan from vertex 0 draws
  // a triangle straight across that gap; ear-clipping never proposes it as
  // an ear at all.
  _region(
    doc,
    boundaryKind: EntityKind.polyline,
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList([
        -50, -10, //
        -50, -50, //
        -10, -50, //
        -10, -30, //
        -30, -30, //
        -30, -10, //
        -50, -10, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
    fillColor: const TrueColor(0x3366CC),
    boundaryColor: const TrueColor(0x000000),
  );

  // The clockwise square, bottom-right: listed (10,-50) -> (10,-10) ->
  // (50,-10) -> (50,-50), signed area negative. Only fills if winding
  // normalisation reverses it before ear-clipping, which assumes
  // counter-clockwise input.
  _region(
    doc,
    boundaryKind: EntityKind.polyline,
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList([
        10, -50, //
        10, -10, //
        50, -10, //
        50, -50, //
        10, -50, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
    fillColor: const TrueColor(0x33CC33),
    boundaryColor: const TrueColor(0x000000),
  );

  // The circle, top-left: never triangulated ahead of time, fanned per frame
  // at whatever step count its own stroke uses -- the only one of the four
  // whose tessellation is scale-dependent, which is why this fixture is
  // drawn at three zoom levels rather than one.
  _region(
    doc,
    boundaryKind: EntityKind.circle,
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList([-30, 30]),
      scalars: Float64List.fromList([15]),
    ),
    fillColor: const TrueColor(0xCC6633),
    boundaryColor: const TrueColor(0x000000),
  );

  // The hairline-layer square, top-right: an ordinary simple square, whose
  // *fill* -- not its boundary -- sits on the thin layer above via BYLAYER.
  // The boundary stays on layer 0 at the default lineweight, so only the
  // fill's own resolved style is thin.
  _region(
    doc,
    boundaryKind: EntityKind.polyline,
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList([
        10, 10, //
        50, 10, //
        50, 50, //
        10, 50, //
        10, 10, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
    fillColor: const TrueColor(0x9933CC),
    boundaryColor: const TrueColor(0x000000),
    fillLayer: hairline,
    fillLineweight: kByLayer,
  );

  return doc;
}

/// Adds one region (fill + boundary pair), built with [AddRegionCommand]'s
/// raw constructor rather than [AddRegionCommand.allocate] so the fill's own
/// layer and lineweight can differ from its boundary's -- `.allocate` gives
/// both halves the same `layer` argument and hard-codes the fill's own
/// lineweight to `kLineweightDefault`, neither of which reaches the
/// hairline-layer fill this fixture needs.
void _region(
  DraftDocument doc, {
  required EntityKind boundaryKind,
  required GeometryPayload boundaryPayload,
  required DraftColor fillColor,
  required DraftColor boundaryColor,
  Handle? fillLayer,
  int fillLineweight = kLineweightDefault,
}) {
  final fillHandle = doc.handleSeed.next();
  final boundaryHandle = doc.handleSeed.next();
  doc.commands.execute(AddRegionCommand(
    fill: EntityRecord(
      handle: fillHandle,
      owner: doc.rootHandle,
      kind: EntityKind.fill,
      layer: fillLayer ?? ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: fillColor,
      lineweight: fillLineweight,
      transparency: 0,
      flags: 0,
    ),
    boundary: EntityRecord(
      handle: boundaryHandle,
      owner: doc.rootHandle,
      kind: boundaryKind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: boundaryColor,
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: boundaryPayload,
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
            // The canvas backend explicitly, exactly as `dash_ladder_golden_test`
            // does: these three PNGs are the canvas backend's suite and the
            // vertices backend renders the same fixture into a second set.
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
/// Follows `dash_ladder_golden_test.dart`'s `_rung` exactly -- see that file
/// for why the two backends are captured so differently and why each of the
/// assertions below is required rather than incidental.
Future<void> _rung(WidgetTester tester, DraftDocument doc, double halfSpan,
    String name, RenderBackend backend) async {
  if (backend == RenderBackend.canvas) {
    await tester.pumpWidget(_at(doc, halfSpan));
    await expectLater(
        find.byKey(kCanvasKey), matchesGoldenFile('fill_ladder_$name.png'));
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

  // Required, not absorbable by `--update-goldens`: see
  // `dash_ladder_golden_test.dart`'s `_rung` for the full argument. Without
  // this a sink left at its constructor default of 1.0 draws the wrong
  // stroke widths -- and, for this fixture, the wrong hairline threshold --
  // and every vertices golden would fail only on image size, which
  // `--update-goldens` silently repairs by writing the wrong picture down.
  final dpr = tester.view.devicePixelRatio;
  expect(key.currentState!.vertices!.devicePixelRatio, dpr,
      reason: 'the sink must be at the binding\'s device pixel ratio: '
          'DraftCanvas rebinds it per frame from MediaQuery, and a sink left '
          'at its constructor default draws stroke widths for the wrong '
          'device. Do NOT regenerate the goldens to make this pass.');
  final rasterizer = TriangleRasterizer((kGoldenViewport.width * dpr).round(),
      (kGoldenViewport.height * dpr).round());
  key.currentState!.vertices!.observer = (positions, colors) {
    final scaled = Float32List(positions.length);
    for (var i = 0; i < positions.length; i++) {
      scaled[i] = positions[i] * dpr;
    }
    rasterizer.observe(scaled, colors);
  };
  // The first pump already painted once, without an observer attached;
  // `markNeedsPaint` forces the same picture to paint again through the
  // now-attached observer. See `dash_ladder_golden_test.dart` for the probe
  // that established a bare `tester.pump()` here finds nothing dirty.
  tester
      .renderObject<RenderObject>(find.descendant(
          of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)))
      .markNeedsPaint();
  await tester.pump();

  final image = (await tester.runAsync(rasterizer.toImage))!;
  addTearDown(image.dispose);

  // A golden that never inks a pixel passes forever and pins nothing -- see
  // `dash_ladder_golden_test.dart`. Every rung here draws four fills and
  // their boundaries, so this must always ink something.
  expect(rasterizer.pixels.any((p) => p != 0), isTrue,
      reason: 'rung $name drew nothing: four fills and their boundaries are '
          'always present, so a blank surface means the picture never '
          'reached the rasterizer');
  await expectLater(image, matchesGoldenFile('vertices/fill_ladder_$name.png'));
}

void main() {
  for (final (name, halfSpan) in const [
    ('1', 60.0),
    ('2', 400.0),
    ('3', 4000.0),
  ]) {
    for (final backend in RenderBackend.values) {
      // Skip the GPU-resident backend: it has no sink until Task 8 and will
      // never render in a test environment without actual GPU support.
      if (backend == RenderBackend.residentGpu) continue;
      testWidgets('fill ladder rung $name ($backend)', (tester) async {
        await _rung(tester, fillLadderFixture(), halfSpan, name, backend);
      });
    }
  }
}
