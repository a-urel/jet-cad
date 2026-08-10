import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/spy_canvas.dart';

const Size kViewport = Size(800, 600);
const double kPixelsPerPaperMm = 4.0;

/// Conformal and fixed, so the only thing varying between fixtures is the
/// instance transform. `fit` would change with the document and hide the
/// effect being measured. The translation puts the world origin at the middle
/// of the viewport, so geometry on either side of it is visible — with a bare
/// scale, everything above y = 0 culls away and the fixtures draw nothing.
final ViewportTransform kCamera = ViewportTransform(
    worldToScreenMatrix:
        Transform2.translation(400, 300).multiply(Transform2.scale(3, -3)));

Handle addEntity(DraftDocument doc, Handle owner, Handle handle,
    EntityKind kind, List<double> coords, List<double> scalars) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const IndexedColor(1),
      lineweight: 25, // 0.25 mm on paper
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

/// One entity inside one definition, placed once by [instance].
DraftDocument fixture(Transform2 instance,
    {EntityKind kind = EntityKind.line,
    List<double> coords = const [0, 0, 4, 0],
    List<double> scalars = const []}) {
  final doc = DraftDocument.empty();
  doc.tree.addDefinition(Definition(
      handle: const Handle(500),
      name: 'sym',
      basePoint: Vector2.zero(),
      children: const []));
  addEntity(doc, const Handle(500), const Handle(700), kind, coords, scalars);
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(600),
    parent: doc.rootHandle,
    transform: instance,
    definition: const Handle(500),
    layer: ReservedHandles.layerZero,
  )));
  return doc;
}

({DraftPainter painter, RecordingDrawSink sink}) paintFixture(
    Transform2 instance,
    {EntityKind kind = EntityKind.line,
    List<double> coords = const [0, 0, 4, 0],
    List<double> scalars = const []}) {
  final doc = fixture(instance, kind: kind, coords: coords, scalars: scalars);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  final sink = RecordingDrawSink();
  painter.paint(sink, kCamera, kViewport);
  return (painter: painter, sink: sink);
}

/// The width the stroke actually comes out on screen: `Paint.strokeWidth` is
/// measured in the residual's units, so the residual's scale multiplies it
/// back up.
double screenStrokeWidthUnder(Transform2 instance) {
  final doc = fixture(instance);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final canvas = SpyCanvas();
  DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc))
      .paint(
          CanvasDrawSink(canvas: canvas, pixelsPerPaperMm: kPixelsPerPaperMm),
          kCamera,
          kViewport);

  final transform = canvas.named('transform').last.args.single as Float64List;
  final residual = Transform2(transform[0], transform[1], transform[4],
      transform[5], transform[12], transform[13]);
  return canvas.named('drawPath').last.strokeWidth! * residual.scaleMagnitude;
}

void main() {
  test('paper-space width survives a 0.1x and a 10x instance identically', () {
    // A lineweight is 1/100 mm on paper. If it were treated as a world
    // quantity, the same wall would render 100x thicker under one instance
    // than the other.
    final thin = screenStrokeWidthUnder(Transform2.scale(0.1, 0.1));
    final thick = screenStrokeWidthUnder(Transform2.scale(10.0, 10.0));

    // 1e-6, not 1e-9: `Paint.strokeWidth` is a float32 on the dart:ui side,
    // so a width that survives the round trip is equal to about seven digits.
    expect(thin, closeTo(thick, 1e-6));
    expect(thin, closeTo(25 / 100 * kPixelsPerPaperMm, 1e-6),
        reason: '0.25 mm at 4 px/mm is one logical pixel, at any zoom');
  });

  test('an instance past the anisotropy threshold takes the bypass', () {
    // Under scale(1, 8) no single stroke width is correct. The answer is to
    // bypass: transform the points in Float64, push a translation-only
    // residual, and use the exact width.
    final run = paintFixture(Transform2.scale(1.0, 8.0));

    expect(run.painter.screenSpaceLeafCount, 1);
    final begin = run.sink.ops.whereType<BeginResidualOp>().single;
    expect(begin.residual.a, closeTo(1.0, 1e-12));
    expect(begin.residual.d, closeTo(1.0, 1e-12));
    expect(begin.residual.b, closeTo(0.0, 1e-12));
    expect(begin.residual.c, closeTo(0.0, 1e-12));
  });

  test('a mirrored but conformal instance also takes the screen-space path',
      () {
    // scale(-2, 2) has determinant -4 and anisotropyRatio 1: mirroring alone
    // is conformal. The screen-space path is the rule for every line-like
    // leaf now, regardless of anisotropy, so this one takes it too.
    expect(
        paintFixture(Transform2.scale(-2.0, 2.0)).painter.screenSpaceLeafCount,
        1);
  });

  test('a bypassed leaf lands exactly where the residual path would put it',
      () {
    // The bypass is a different arithmetic path to the same picture. If it
    // only got the stroke width right, it would be a rendering bug that the
    // width tests could not see.
    final run =
        paintFixture(Transform2.scale(1.0, 8.0), coords: const [3, 5, 4, 6]);
    final begin = run.sink.ops.whereType<BeginResidualOp>().single;
    final line = run.sink.ops.whereType<PolylineOp>().single;

    for (var i = 0; i < 2; i++) {
      final drawn = begin.residual
          .transformPoint(Vector2(line.points[i * 2], line.points[i * 2 + 1]));
      final expected = kCamera.worldToScreen(
          Transform2.scale(1.0, 8.0).transformPoint(Vector2(3.0 + i, 5.0 + i)));
      expect(drawn.x, closeTo(expected.x, 1e-6));
      expect(drawn.y, closeTo(expected.y, 1e-6));
    }
  });

  test('a bypassed leaf hands the sink small numbers', () {
    // The bypass rebases in *screen* space, because that is the space its
    // points are now in. Subtracting the world origin instead reconstructs to
    // exactly the same place — the residual carries whatever was subtracted —
    // so position alone cannot catch it. What it destroys is the magnitude:
    // the values reaching Canvas would be world-sized again, which is the one
    // thing the rebase exists to prevent.
    final doc = fixture(Transform2.scale(1.0, 8.0),
        coords: const [4500000, 1200000, 4500004, 1200000]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();
    painter.paint(
        sink, ViewportTransform.fit(doc.extents, kViewport), kViewport);

    expect(painter.screenSpaceLeafCount, 1);
    for (final v in sink.ops.whereType<PolylineOp>().single.points) {
      expect(v.abs(), lessThan(1 << 20),
          reason: 'a screen-space residual, not a world coordinate');
    }
  });

  test('a bypassed leaf gets the exact paper width', () {
    // The residual is translation-only, so its scale is 1 and the width the
    // sink computes is the paper width in device pixels with nothing divided
    // out of it.
    expect(screenStrokeWidthUnder(Transform2.scale(1.0, 8.0)),
        closeTo(25 / 100 * kPixelsPerPaperMm, 1e-6));
  });

  group('curves cannot be bypassed', () {
    test('an anisotropic circle stays on the residual path and is counted', () {
      // A circle under scale(1, 8) is an ellipse, and `DrawSink.circle` takes
      // one radius. Pre-transforming its points is not available, so it keeps
      // the residual path — where Canvas draws the ellipse correctly and the
      // stroke width is the approximation this counter records.
      final run = paintFixture(Transform2.scale(1.0, 8.0),
          kind: EntityKind.circle, coords: const [0, 0], scalars: const [5]);

      expect(run.painter.screenSpaceLeafCount, 0);
      expect(run.painter.anisotropicCurveCount, 1);
      expect(run.sink.ops.whereType<CircleOp>(), hasLength(1));
      final begin = run.sink.ops.whereType<BeginResidualOp>().single;
      expect((begin.residual.d / begin.residual.a).abs(), closeTo(8.0, 1e-9),
          reason: 'the anisotropy is still in the residual, as it must be; '
              'the sign is the camera y flip');
    });

    test('an anisotropic arc is counted too', () {
      final run = paintFixture(Transform2.scale(1.0, 8.0),
          kind: EntityKind.arc,
          coords: const [0, 0],
          scalars: const [5, 0.5, 1.5]);

      expect(run.painter.anisotropicCurveCount, 1);
      expect(run.sink.ops.whereType<ArcOp>(), hasLength(1));
    });

    test('a conformal circle is not counted', () {
      final run = paintFixture(Transform2.scale(2.0, 2.0),
          kind: EntityKind.circle, coords: const [0, 0], scalars: const [5]);
      expect(run.painter.anisotropicCurveCount, 0);
    });

    test(
        'the threshold is exclusive, so a circle exactly at 2.0 is not counted',
        () {
      // kAnisotropyThreshold no longer gates whether a line-like leaf takes
      // the screen-space path — only whether a curve counts as anisotropic.
      expect(
          paintFixture(Transform2.scale(1.0, kAnisotropyThreshold),
              kind: EntityKind.circle,
              coords: const [0, 0],
              scalars: const [5]).painter.anisotropicCurveCount,
          0);
      expect(
          paintFixture(Transform2.scale(1.0, kAnisotropyThreshold + 0.001),
              kind: EntityKind.circle,
              coords: const [0, 0],
              scalars: const [5]).painter.anisotropicCurveCount,
          1);
    });
  });
}
