import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const Size kViewport = Size(800, 600);

Handle _add(
  DraftDocument doc,
  Handle owner,
  EntityKind kind,
  List<double> coords,
  List<double> scalars, {
  Handle layer = ReservedHandles.layerZero,
  DraftColor color = const ByLayerColor(),
  int flags = 0,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: layer,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: flags,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

Handle addLine(DraftDocument doc, Handle owner, double x1, double y1, double x2,
        double y2,
        {int flags = 0}) =>
    _add(doc, owner, EntityKind.line, [x1, y1, x2, y2], const [], flags: flags);

/// Builds the index and paints the whole document into a recording sink.
///
/// [view] overrides the camera's world box, for culling tests.
({DraftPainter painter, RecordingDrawSink sink, ViewportTransform camera})
    paintAll(DraftDocument doc, {Aabb2? view}) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  final camera = ViewportTransform.fit(view ?? doc.extents, kViewport);
  final sink = RecordingDrawSink();
  painter.paint(sink, camera, kViewport);
  return (painter: painter, sink: sink, camera: camera);
}

void main() {
  test('a group-owned leaf is drawn through its folded transform', () {
    // Group nodes are flattened into the enclosing container and the leaf's
    // composed transform is kept in ContainerIndex._leafTransforms. A painter
    // that reads coordinates straight out of GeometryStore and skips
    // transformOfLeaf draws every group-owned leaf at its unplaced position —
    // and a fixture whose group transform is the identity cannot tell.
    final doc = DraftDocument.empty();
    const group = Handle(400);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(1000, 2000)
          .multiply(Transform2.rotation(0.7))
          .multiply(Transform2.scale(2.0, 3.0)),
      children: const [],
    )));
    addLine(doc, group, 0, 0, 1, 0);

    final run = paintAll(doc);
    final begin = run.sink.ops.whereType<BeginResidualOp>().single;
    final line = run.sink.ops.whereType<PolylineOp>().single;

    // Reconstruct the screen position from what actually reached the sink.
    final p =
        begin.residual.transformPoint(Vector2(line.points[2], line.points[3]));
    final expected = run.camera.worldToScreen(
        Vector2(1000 + 2 * math.cos(0.7), 2000 + 2 * math.sin(0.7)));
    expect(p.x, closeTo(expected.x, 1e-6));
    expect(p.y, closeTo(expected.y, 1e-6));
  });

  test('nothing absolute reaches the sink at site-plan magnitude', () {
    // The rebase exists so `Canvas` never sees 4.5e6. If the origin were
    // subtracted in the wrong space — or not at all — the numbers below would
    // still reconstruct correctly, but float32 would eat them downstream.
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 4500000.125, 1200000.5, 4500100.25, 1200080.5);

    final run = paintAll(doc);
    final line = run.sink.ops.whereType<PolylineOp>().single;
    for (final v in line.points) {
      expect(v.abs(), lessThan(1 << 20),
          reason: 'a residual, not a world coordinate');
    }

    final begin = run.sink.ops.whereType<BeginResidualOp>().single;
    final p =
        begin.residual.transformPoint(Vector2(line.points[0], line.points[1]));
    final expected = run.camera.worldToScreen(Vector2(4500000.125, 1200000.5));
    expect(p.x, closeTo(expected.x, 1e-6));
    expect(p.y, closeTo(expected.y, 1e-6));
  });

  test('a rotated, scaled group still reaches the sink rebased', () {
    // The two rules meet here: the origin is a world point, the stored
    // coordinates are leaf-local, and the group transform is neither identity
    // nor a translation. Subtracting the world origin from local coordinates
    // reconstructs to the wrong place; this is the case that proves it.
    final doc = DraftDocument.empty();
    const group = Handle(400);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(4500000, 1200000)
          .multiply(Transform2.rotation(0.7))
          .multiply(Transform2.scale(2.0, 3.0)),
      children: const [],
    )));
    addLine(doc, group, 0, 0, 10, 4);

    final run = paintAll(doc);
    final begin = run.sink.ops.whereType<BeginResidualOp>().single;
    final line = run.sink.ops.whereType<PolylineOp>().single;

    for (final v in line.points) {
      expect(v.abs(), lessThan(1 << 20));
    }
    final local = Transform2.translation(4500000, 1200000)
        .multiply(Transform2.rotation(0.7))
        .multiply(Transform2.scale(2.0, 3.0))
        .transformPoint(Vector2(10, 4));
    final p =
        begin.residual.transformPoint(Vector2(line.points[2], line.points[3]));
    final expected = run.camera.worldToScreen(local);
    expect(p.x, closeTo(expected.x, 1e-6));
    expect(p.y, closeTo(expected.y, 1e-6));
  });

  test('a singular group transform does not take the frame down', () {
    // `invert()` throws on a zero-determinant transform, and this one is
    // reached per leaf, per frame.
    final doc = DraftDocument.empty();
    const group = Handle(400);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.scale(0, 0),
      children: const [],
    )));
    addLine(doc, group, 0, 0, 1, 0);
    addLine(doc, doc.rootHandle, 0, 0, 10, 10);

    final run = paintAll(doc);
    expect(run.sink.ops.whereType<PolylineOp>(), hasLength(2),
        reason: 'the healthy sibling must still be drawn');
  });

  group('per kind', () {
    test('a circle keeps its radius while its centre is rebased', () {
      // A transform applies to points and must not apply to a radius. Rebasing
      // the radius would shrink every circle by the distance to the origin.
      final doc = DraftDocument.empty();
      _add(doc, doc.rootHandle, EntityKind.circle, [4500000, 1200000],
          const [25]);

      final run = paintAll(doc);
      final circle = run.sink.ops.whereType<CircleOp>().single;
      expect(circle.r, 25.0);
      expect(circle.cx.abs(), lessThan(1 << 20));
      expect(circle.cy.abs(), lessThan(1 << 20));
    });

    test('an arc keeps its radius and both angles', () {
      final doc = DraftDocument.empty();
      _add(doc, doc.rootHandle, EntityKind.arc, [4500000, 1200000],
          const [25, 0.5, 1.5]);

      final run = paintAll(doc);
      final arc = run.sink.ops.whereType<ArcOp>().single;
      expect(arc.r, 25.0);
      expect(arc.start, 0.5);
      expect(arc.sweep, 1.5);
      expect(arc.cx.abs(), lessThan(1 << 20));
    });

    test('a point entity is drawn as a point', () {
      final doc = DraftDocument.empty();
      _add(doc, doc.rootHandle, EntityKind.point, [4500000, 1200000], const []);
      _add(doc, doc.rootHandle, EntityKind.circle, [4500050, 1200050],
          const [10]);

      final run = paintAll(doc);
      expect(run.sink.ops.whereType<PointOp>(), hasLength(1));
    });

    test('a polyline draws every stored vertex', () {
      final doc = DraftDocument.empty();
      _add(doc, doc.rootHandle, EntityKind.polyline,
          [0, 0, 10, 0, 10, 10, 0, 10], const []);

      final run = paintAll(doc);
      final poly = run.sink.ops.whereType<PolylineOp>().single;
      expect(poly.points, hasLength(8));
      expect(poly.closed, isFalse,
          reason: 'the model carries no closed flag yet — see the ledger');
    });
  });

  test('the resolved style reaches the sink', () {
    final doc = DraftDocument.empty();
    const red = Handle(100);
    doc.tables.layers.add(const LayerRecord(
      handle: red,
      name: 'red',
      color: IndexedColor(1),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 0,
    ));
    _add(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 1], const [],
        layer: red);

    final run = paintAll(doc);
    final line = run.sink.ops.whereType<PolylineOp>().single;
    expect(line.style.argb, 0xFFFF0000);
    expect(line.style.lineweightHundredths, 50);
  });

  test('geometry outside the view is not drawn', () {
    // The painter must query the camera's visible world, not the document
    // extents. Passing the extents would draw the whole document every frame
    // and every measurement in the results note would be meaningless.
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 10, 10);
    addLine(doc, doc.rootHandle, 100000, 100000, 100010, 100010);

    final run = paintAll(doc, view: Aabb2(Vector2(-5, -5), Vector2(15, 15)));
    expect(run.sink.ops.whereType<PolylineOp>(), hasLength(1));
  });

  test('an invisible entity is not drawn', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 10, 10);
    addLine(doc, doc.rootHandle, 0, 0, 10, 10, flags: EntityFlags.invisible);

    final run = paintAll(doc);
    expect(run.sink.ops.whereType<PolylineOp>(), hasLength(1));
  });

  test('the leaf buffer does not grow after warm-up', () {
    final doc = generateDocument(5000, definitionCount: 10);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    painter.paint(NullDrawSink(), camera, kViewport);
    final warm = painter.leafBufferCapacity;
    for (var i = 0; i < 20; i++) {
      painter.paint(NullDrawSink(), camera, kViewport);
    }
    expect(painter.leafBufferCapacity, warm);
  });

  test('text entities are counted, not silently dropped', () {
    // The corpus generates a few hundred text entities. If they vanished with
    // no counter, the results note would read as a complete measurement.
    final doc = generateDocument(30000, definitionCount: 100);
    final run = paintAll(doc);
    expect(run.painter.skippedTextCount, greaterThan(0));
    expect(
        run.sink.ops.whereType<PointOp>().length + run.painter.skippedTextCount,
        greaterThan(0));
  });
}
