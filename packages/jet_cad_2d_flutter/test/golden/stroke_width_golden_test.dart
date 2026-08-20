@Tags(['golden'])
library;

// Font- and platform-dependent rendering makes goldens fragile, so this file
// holds the two cases the operation record genuinely cannot cover: whether a
// stroke *looks* the right width, and whether the anisotropy bypass produces
// the right shape. Everything else in this package is asserted on
// `RecordingDrawSink`, where a number can be compared instead of a picture.
//
// These drive `DraftPainter` through `CanvasDrawSink` directly rather than
// through `DraftCanvas`, which does not exist yet. That is the honest coupling
// anyway: stroke width is computed in the sink and the bypass in the painter,
// and neither becomes more or less correct for being inside a widget.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import '../support/triangle_rasterizer.dart';

const Size kGoldenViewport = Size(400, 300);

/// Chosen so a 0.5 mm lineweight lands on 4 device pixels: thick enough that a
/// wrong width is obvious by eye, thin enough that the shapes stay readable.
const double kPixelsPerPaperMm = 8.0;

/// 1/100 mm, so 0.5 mm.
const int kHalfMillimetre = 50;

const Key kCanvasKey = Key('golden-canvas');

Handle _addLine(
        DraftDocument doc, Handle owner, Handle handle, List<double> coords) =>
    _add(doc, owner, handle, EntityKind.polyline, coords);

Handle _add(DraftDocument doc, Handle owner, Handle handle, EntityKind kind,
    List<double> coords,
    [List<double> scalars = const []]) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      // Concrete black, not ByLayer: layer 0 resolves to ACI 7, which is white
      // on this white background and would make an empty golden look like a
      // passing one.
      color: const TrueColor(0x000000),
      lineweight: kHalfMillimetre,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

/// Two rules through the origin and a small square around it.
///
/// The rules are long enough to cross the viewport at every zoom below, so
/// they show thickness and nothing else. The square is what makes the
/// comparison meaningful: it must visibly *grow* with zoom while the strokes
/// stay put. Three images that differ in no way at all would also be produced
/// by a camera that ignored its scale.
DraftDocument strokeWidthFixture() {
  final doc = DraftDocument.empty();
  final root = doc.rootHandle;
  _addLine(doc, root, const Handle(900), [-4000, 0, 4000, 0]);
  _addLine(doc, root, const Handle(901), [0, -3000, 0, 3000]);
  _addLine(doc, root, const Handle(902),
      [-10, -10, 10, -10, 10, 10, -10, 10, -10, -10]);
  return doc;
}

/// The same shape placed twice: once conformally, once stretched 8:1.
///
/// Both instances must show the same stroke width on every edge. Without the
/// bypass the stretched one's horizontal edges would be eight times thicker
/// than its vertical ones, because `Paint.strokeWidth` is one scalar and Skia
/// would scale it with the residual.
DraftDocument anisotropicFixture({double scaleY = 8.0}) {
  final doc = DraftDocument.empty();
  const shape = Handle(600);
  doc.tree.addDefinition(Definition(
      handle: shape,
      name: 'shape',
      basePoint: Vector2.zero(),
      children: const []));
  _addLine(doc, shape, const Handle(910), [0, 0, 20, 0, 20, 10, 0, 10, 0, 0]);
  _addLine(doc, shape, const Handle(911), [0, 0, 20, 10]);

  // Conformal, and deliberately not the identity: an identity scale would make
  // this instance prove nothing about composition, and 1.3 keeps the ratio at
  // 1.0 all the same.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(920),
    parent: doc.rootHandle,
    transform:
        Transform2.translation(-40, 0).multiply(Transform2.scale(1.3, 1.3)),
    definition: shape,
    layer: ReservedHandles.layerZero,
  )));

  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(930),
    parent: doc.rootHandle,
    transform: Transform2.translation(10, -40)
        .multiply(Transform2.scale(1.3, 1.3 * scaleY)),
    definition: shape,
    layer: ReservedHandles.layerZero,
  )));
  return doc;
}

class _PainterHost extends CustomPainter {
  _PainterHost(this.painter, this.camera, this.textStyleOf);

  final DraftPainter painter;
  final ViewportTransform camera;
  final TextStyleRecord Function(Handle) textStyleOf;

  @override
  void paint(Canvas canvas, Size size) {
    // These goldens measure paper-space stroke width and the shape of an
    // anisotropic instance; neither draws text yet.
    final sink = CanvasDrawSink(
        canvas: canvas,
        pixelsPerPaperMm: kPixelsPerPaperMm,
        measurer: FlutterTextMeasurer(),
        textStyleOf: textStyleOf);
    painter.paint(sink, camera, size);
  }

  @override
  bool shouldRepaint(_PainterHost old) => true;
}

Widget canvasOver(
        DraftDocument doc, SpatialIndex index, ViewportTransform camera) =>
    Center(
      child: RepaintBoundary(
        key: kCanvasKey,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: CustomPaint(
            size: kGoldenViewport,
            painter: _PainterHost(
              DraftPainter(
                  document: doc,
                  index: index,
                  resolver: DocumentStyleResolver(doc)),
              camera,
              doc.textStyleOf,
            ),
          ),
        ),
      ),
    );

/// The world origin at the centre of the viewport, scaled by [zoom].
///
/// Written out rather than fitted, because the point of the first golden is
/// that three *different* scales produce one stroke width — a fit camera would
/// choose the scale and hide the variable.
ViewportTransform cameraAt(double zoom) => ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              kGoldenViewport.width / 2, kGoldenViewport.height / 2)
          .multiply(Transform2.scale(zoom, -zoom)),
    );

/// `devicePixelRatio` this file's vertices sink is given.
///
/// There is no widget's `MediaQuery` here to read a real device pixel ratio
/// from — `_renderVertices` drives `VerticesDrawSink` directly, the same way
/// [canvasOver] drives `CanvasDrawSink` directly. `1.0` matches the canvas
/// half of this suite's own capture (both goldens are exactly
/// `kGoldenViewport` in size, unscaled), and it is what makes the class
/// comment's "0.5 mm lands on 4 device pixels" true of this rasterization
/// too. Named so the rasterizer below is built at the *same* ratio rather
/// than a second, independently-typed `1.0` that could drift from it.
const double _kVerticesDevicePixelRatio = 1.0;

/// Renders [doc] through `VerticesDrawSink` and the coverage rasterizer,
/// driven directly the same way [canvasOver] drives `CanvasDrawSink` —
/// `DraftCanvas` does not own either of this file's fixtures.
///
/// Returns the rasterizer alongside the image so a caller can assert ink was
/// actually produced before trusting the golden comparison — see the note
/// beside `_rung` in `dash_ladder_golden_test.dart` for why that assertion
/// exists at all.
Future<(ui.Image, TriangleRasterizer)> _renderVertices(WidgetTester tester,
    DraftDocument doc, SpatialIndex index, ViewportTransform camera) async {
  final recorder = ui.PictureRecorder();
  // The rasterizer has to sample at the same resolution Impeller actually
  // rasterizes at (a *device*-pixel quantity, which is what
  // `VerticesDrawSink`'s width floor and colour fade are computed in), not
  // at the logical resolution the sink's positions are expressed in — see
  // the fuller version of this note in `dash_ladder_golden_test.dart`. Here
  // that ratio is `_kVerticesDevicePixelRatio`, so scaling is a no-op, but
  // the rasterizer is still built and fed through the same
  // resolution/scaling shape the other two files use rather than a
  // logical-resolution special case, so a future change to the ratio here
  // does not silently reintroduce the bug.
  final rasterizer = TriangleRasterizer(
      (kGoldenViewport.width * _kVerticesDevicePixelRatio).round(),
      (kGoldenViewport.height * _kVerticesDevicePixelRatio).round());
  final sink = VerticesDrawSink(
    pixelsPerPaperMm: kPixelsPerPaperMm,
    canvas: Canvas(recorder),
    devicePixelRatio: _kVerticesDevicePixelRatio,
  )..observer = (positions, colors) {
      final scaled = Float32List(positions.length);
      for (var i = 0; i < positions.length; i++) {
        scaled[i] = positions[i] * _kVerticesDevicePixelRatio;
      }
      rasterizer.observe(scaled, colors);
    };
  DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc))
      .paint(sink, camera, kGoldenViewport);
  sink.flush();
  recorder.endRecording().dispose();
  // `rasterizer.toImage()` completes through `decodeImageFromPixels`, a real
  // engine callback. Confirmed by a minimal repro: once this test binding has
  // actually pumped a widget (as `canvasOver` already has by the time this is
  // called), the fake-async test zone never delivers that callback and the
  // await hangs forever; before any pump it resolves immediately. `runAsync`
  // steps outside the fake zone for the one call that needs it.
  final image = (await tester.runAsync(rasterizer.toImage))!;
  return (image, rasterizer);
}

void main() {
  testWidgets('paper-space stroke width at three zoom levels', (tester) async {
    // "Paper space" means the width is a property of the paper, not of the
    // camera: 0.5 mm stays 0.5 mm on screen however far in the view is.
    await tester.binding.setSurfaceSize(kGoldenViewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final (zoom, name) in const [
      (0.5, 'stroke_width_0_5x.png'),
      (1.0, 'stroke_width_1_0x.png'),
      (8.0, 'stroke_width_8_0x.png'),
    ]) {
      final doc = strokeWidthFixture();
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final camera = cameraAt(zoom);

      await tester.pumpWidget(canvasOver(doc, index, camera));
      await expectLater(find.byKey(kCanvasKey), matchesGoldenFile(name));

      final (image, rasterizer) =
          await _renderVertices(tester, doc, index, camera);
      addTearDown(image.dispose);
      // A golden that never inks a pixel passes forever and pins nothing --
      // the two rules and the square are always present.
      expect(rasterizer.pixels.any((p) => p != 0), isTrue,
          reason: '$name drew nothing');
      await expectLater(image, matchesGoldenFile('vertices/$name'));
    }
  });

  testWidgets('an anisotropic instance draws exact per-axis widths',
      (tester) async {
    await tester.binding.setSurfaceSize(kGoldenViewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final doc = anisotropicFixture(scaleY: 8.0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = ViewportTransform.fit(doc.extents, kGoldenViewport);

    await tester.pumpWidget(canvasOver(doc, index, camera));
    await expectLater(
        find.byKey(kCanvasKey), matchesGoldenFile('anisotropy_bypass.png'));

    final (image, rasterizer) =
        await _renderVertices(tester, doc, index, camera);
    addTearDown(image.dispose);
    // A golden that never inks a pixel passes forever and pins nothing --
    // both instances' outlines and diagonals are always present.
    expect(rasterizer.pixels.any((p) => p != 0), isTrue,
        reason: 'anisotropy_bypass drew nothing');
    await expectLater(
        image, matchesGoldenFile('vertices/anisotropy_bypass.png'));
  });

  testWidgets('the anisotropic instance really took the bypass',
      (tester) async {
    // A golden records whatever the code did. This says the picture above is
    // the bypass being exercised and not the fallback quietly drawing
    // something plausible — the one thing about that image an eye cannot
    // check.
    final doc = anisotropicFixture(scaleY: 8.0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    painter.paint(RecordingDrawSink(),
        ViewportTransform.fit(doc.extents, kGoldenViewport), kGoldenViewport);

    expect(painter.screenSpaceLeafCount, 4,
        reason: 'both instances place two polylines each, and every '
            'polyline takes the screen-space path now, conformal or not');
    expect(painter.anisotropicCurveCount, 0,
        reason: 'the fixture holds no curves, so nothing may fall through to '
            'the approximate path');
  });
}
