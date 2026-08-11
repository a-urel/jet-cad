import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/fixtures.dart';

void main() {
  test('a conformal leaf reaches the sink under a translation-only residual',
      () {
    final doc = DraftDocument.empty();
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    addEntity(doc, def, doc.handleSeed.next(), EntityKind.line, [0, 0, 10, 4],
        const []);
    // Conformal: equal scale on both axes, plus a rotation. Ratio is 1.0, so
    // this leaf took the residual path before this task.
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: Transform2(2.4, 1.1, -1.1, 2.4, 60, 45),
      layer: ReservedHandles.layerZero,
    )));

    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final residuals = recording.ops.whereType<BeginResidualOp>().toList();
    expect(residuals, isNotEmpty);
    for (final r in residuals) {
      expect(r.residual.a, 1.0);
      expect(r.residual.b, 0.0);
      expect(r.residual.c, 0.0);
      expect(r.residual.d, 1.0);
    }
  });

  test('every frame pushes one residual value for its line-like leaves', () {
    // Two leaves in different definitions at different placements. If the
    // residual still carried the placement, these would differ — which is
    // exactly what stops a sink from batching them.
    //
    // Filtered to the residuals whose linear part is the exact identity.
    // `_emitScreenSpace` always pushes `Transform2.translation(...)`, so that
    // is the signature of the screen-space path and only that path — a
    // curve's residual still composes the camera matrix (unchanged by this
    // task), so it is never (1, 0, 0, 1) by coincidence in this fixture.
    // Left unfiltered, `generateDocument`'s default kind mix includes circles,
    // arcs and text, whose per-placement residuals still carry floating-point
    // noise from the unrelated chain path (about 41 distinct values here) and
    // would fail this assertion for a reason outside this task's scope.
    final doc = generateDocument(400, definitionCount: 8, instanceCount: 40);
    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final translations = recording.ops
        .whereType<BeginResidualOp>()
        .where((op) =>
            op.residual.a == 1.0 &&
            op.residual.b == 0.0 &&
            op.residual.c == 0.0 &&
            op.residual.d == 1.0)
        .map((op) => '${op.residual.e},${op.residual.f}')
        .toSet();
    expect(translations.length, 1,
        reason: 'one rebase origin per frame means one residual value; '
            'more than one means a placement is still riding along');
  });

  DraftDocument dashedFixture({required Transform2 placement}) {
    final doc = DraftDocument.empty();
    final dashed = doc.handleSeed.next();
    doc.tables.linetypes.add(LinetypeRecord(
      handle: dashed,
      name: 'DASHED',
      description: '__ __ __',
      pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
    ));
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: def,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: dashed,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 25,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 360, 0]),
          scalars: Float64List(0)),
    ));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: placement,
      layer: ReservedHandles.layerZero,
    )));
    return doc;
  }

  List<PolylineOp> paintDashed(DraftDocument doc, ViewportTransform camera) {
    final recording = RecordingDrawSink();
    DraftPainter(
            document: doc,
            index: SpatialIndex(doc),
            resolver: DocumentStyleResolver(doc))
        .paint(recording, camera, kViewport);
    return recording.ops.whereType<PolylineOp>().toList();
  }

  test('a dashed entity reaches the sink as many spans, not one polyline', () {
    final doc = dashedFixture(placement: Transform2(1.4, 0.3, -0.3, 1.4, 5, 7));
    final ops = paintDashed(doc, ViewportTransform.fit(doc.extents, kViewport));
    expect(ops.length, greaterThan(4));
    for (final op in ops) {
      expect(op.points.length, 4, reason: 'each span is one two-point run');
    }
  });

  test('the instance scale multiplies the on-screen dash length', () {
    // Same geometry, same camera, twice the placement scale: each span must be
    // twice as long on screen. This is the scale chain, and nothing else in the
    // suite can see it.
    final cam = ViewportTransform.fit(
        Aabb2(Vector2(-50, -50), Vector2(1200, 1200)), kViewport);
    double firstSpanLength(DraftDocument doc) {
      final op = paintDashed(doc, cam).first;
      final dx = op.points[2] - op.points[0];
      final dy = op.points[3] - op.points[1];
      return math.sqrt(dx * dx + dy * dy);
    }

    final one =
        firstSpanLength(dashedFixture(placement: Transform2(1, 0, 0, 1, 0, 0)));
    final two =
        firstSpanLength(dashedFixture(placement: Transform2(2, 0, 0, 2, 0, 0)));
    expect(two / one, closeTo(2.0, 1e-6));
  });

  test('globalLinetypeScale multiplies it too', () {
    final cam = ViewportTransform.fit(
        Aabb2(Vector2(-50, -50), Vector2(1200, 1200)), kViewport);
    final doc = dashedFixture(placement: Transform2(1, 0, 0, 1, 0, 0));
    final before = paintDashed(doc, cam).length;
    doc.header.globalLinetypeScale = 3.0;
    final after = paintDashed(doc, cam).length;
    expect(after, lessThan(before),
        reason: 'a longer pattern means fewer spans over the same line');
  });

  test('a continuous entity is drawn as one polyline and is not counted', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, doc.handleSeed.next(), EntityKind.line,
        [0, 0, 360, 0], const []);
    final ops = paintDashed(doc, ViewportTransform.fit(doc.extents, kViewport));
    expect(ops.length, 1);
  });
}
