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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

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
  _PainterHost(this.painter, this.camera);

  final DraftPainter painter;
  final ViewportTransform camera;

  @override
  void paint(Canvas canvas, Size size) {
    // These goldens measure paper-space stroke width and the shape of an
    // anisotropic instance.
    final sink =
        CanvasDrawSink(canvas: canvas, pixelsPerPaperMm: kPixelsPerPaperMm);
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

      await tester.pumpWidget(canvasOver(doc, index, cameraAt(zoom)));
      await expectLater(find.byKey(kCanvasKey), matchesGoldenFile(name));
    }
  });

  testWidgets('an anisotropic instance draws exact per-axis widths',
      (tester) async {
    await tester.binding.setSurfaceSize(kGoldenViewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final doc = anisotropicFixture(scaleY: 8.0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    await tester.pumpWidget(canvasOver(
        doc, index, ViewportTransform.fit(doc.extents, kGoldenViewport)));
    await expectLater(
        find.byKey(kCanvasKey), matchesGoldenFile('anisotropy_bypass.png'));
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
