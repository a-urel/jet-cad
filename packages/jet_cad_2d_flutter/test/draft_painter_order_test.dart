import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const Size kViewport = Size(800, 600);

Handle addLineAt(
    DraftDocument doc, Handle owner, Handle handle, double x, double y) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y, x + 1, y]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Handle addDefinitionWithLine(DraftDocument doc, Handle def) {
  doc.tree.addDefinition(Definition(
      handle: def, name: 'sym', basePoint: Vector2.zero(), children: const []));
  addLineAt(doc, def, doc.handleSeed.next(), 0, 0);
  return def;
}

Handle placeInstance(
    DraftDocument doc, Handle handle, Handle def, double x, double y) {
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: doc.rootHandle,
    transform: Transform2.translation(x, y)
        // Mirrored and non-uniform: an instance chain that quietly drops the
        // scale still lands in the right place under a pure translation.
        .multiply(Transform2.scale(1.0, -2.0)),
    definition: def,
    layer: ReservedHandles.layerZero,
  )));
  return handle;
}

({DraftPainter painter, RecordingDrawSink sink}) paintToRecording(
    DraftDocument doc,
    {Aabb2? view}) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  final sink = RecordingDrawSink();
  painter.paint(
      sink, ViewportTransform.fit(view ?? doc.extents, kViewport), kViewport);
  return (painter: painter, sink: sink);
}

/// The handle the painter recorded alongside each residual it pushed, in the
/// order they were pushed.
List<Handle> handleOrderOf(List<DrawOp> ops) => ops
    .whereType<BeginResidualOp>()
    .map((op) => op.debugHandle)
    .where((h) => !h.isNone)
    .toList();

void main() {
  test('leaves and instances interleave by ascending handle', () {
    // Draw order is ascending handle, globally. Running the two queries back to
    // back gives "all leaves, then all instances", which is a different order.
    // It is invisible in 3a — nothing is filled — and decides what covers what
    // as soon as 3b adds fills, by which time the painter would need rewriting.
    final doc = DraftDocument.empty();
    final def = addDefinitionWithLine(doc, const Handle(500));

    final lowLeaf = addLineAt(doc, doc.rootHandle, const Handle(600), 0, 0);
    final instance = placeInstance(doc, const Handle(601), def, 5, 5);
    final highLeaf = addLineAt(doc, doc.rootHandle, const Handle(602), 10, 10);

    final run = paintToRecording(doc);
    expect(handleOrderOf(run.sink.ops), [lowLeaf, instance, highLeaf]);
  });

  test('an instance below every leaf is flushed before the first one', () {
    final doc = DraftDocument.empty();
    final def = addDefinitionWithLine(doc, const Handle(500));
    final instance = placeInstance(doc, const Handle(600), def, 5, 5);
    final leafA = addLineAt(doc, doc.rootHandle, const Handle(601), 0, 0);
    final leafB = addLineAt(doc, doc.rootHandle, const Handle(602), 10, 10);

    final run = paintToRecording(doc);
    expect(handleOrderOf(run.sink.ops), [instance, leafA, leafB]);
  });

  test('an instance above every leaf is flushed after the last one', () {
    // The tail drain after the leaf stream ends is its own branch, and a
    // fixture whose instances all sort between two leaves never reaches it.
    final doc = DraftDocument.empty();
    final def = addDefinitionWithLine(doc, const Handle(500));
    final leafA = addLineAt(doc, doc.rootHandle, const Handle(600), 0, 0);
    final leafB = addLineAt(doc, doc.rootHandle, const Handle(601), 10, 10);
    final instance = placeInstance(doc, const Handle(602), def, 5, 5);

    final run = paintToRecording(doc);
    expect(handleOrderOf(run.sink.ops), [leafA, leafB, instance]);
  });

  test('several instances between two leaves all flush, not just one', () {
    // The flush is a while loop, not an if. With a single instance per gap the
    // two spell the same thing.
    final doc = DraftDocument.empty();
    final def = addDefinitionWithLine(doc, const Handle(500));
    final leafA = addLineAt(doc, doc.rootHandle, const Handle(600), 0, 0);
    final i1 = placeInstance(doc, const Handle(601), def, 5, 5);
    final i2 = placeInstance(doc, const Handle(602), def, 6, 6);
    final i3 = placeInstance(doc, const Handle(603), def, 7, 7);
    final leafB = addLineAt(doc, doc.rootHandle, const Handle(604), 10, 10);

    final run = paintToRecording(doc);
    expect(handleOrderOf(run.sink.ops), [leafA, i1, i2, i3, leafB]);
  });

  test('an instance outside the view is not drawn', () {
    final doc = DraftDocument.empty();
    final def = addDefinitionWithLine(doc, const Handle(500));
    final leaf = addLineAt(doc, doc.rootHandle, const Handle(600), 0, 0);
    placeInstance(doc, const Handle(601), def, 100000, 100000);

    final run =
        paintToRecording(doc, view: Aabb2(Vector2(-5, -5), Vector2(15, 15)));
    expect(handleOrderOf(run.sink.ops), [leaf]);
  });

  test('the instance buffer grows past its initial capacity and then stops',
      () {
    // The buffer starts at 64. A document with more visible instances than
    // that must grow it once and reuse it forever after — and must not drop
    // the instances that arrive after the growth.
    final doc = DraftDocument.empty();
    final def = addDefinitionWithLine(doc, const Handle(500));
    final placed = <Handle>[];
    for (var i = 0; i < 100; i++) {
      placed.add(placeInstance(
          doc, Handle(1000 + i), def, i.toDouble() * 10, i.toDouble() * 10));
    }

    final run = paintToRecording(doc);
    expect(handleOrderOf(run.sink.ops), placed);
    expect(run.painter.instanceBufferCapacity, greaterThanOrEqualTo(100));

    final warm = run.painter.instanceBufferCapacity;
    for (var i = 0; i < 5; i++) {
      run.painter.paint(NullDrawSink(),
          ViewportTransform.fit(doc.extents, kViewport), kViewport);
    }
    expect(run.painter.instanceBufferCapacity, warm);
  });

  test('painting never issues a SpatialIndex-level query from inside a visit',
      () {
    // The merge exists to stay on the legal side of Plan 2's non-reentrancy.
    // A future edit that reaches for forEachInstanceInRect inside the leaf
    // stream fails here rather than in a rig, where it would look like a
    // rendering bug.
    final doc = generateDocument(2000, definitionCount: 10);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(
      () => DraftPainter(
              document: doc, index: index, resolver: DocumentStyleResolver(doc))
          .paint(NullDrawSink(), ViewportTransform.fit(doc.extents, kViewport),
              kViewport),
      returnsNormally,
    );
  });

  test('the diagnostic handle is not part of op equality', () {
    // The oracle compares op lists. If the handle joined `==`, two painters
    // that drew the same picture from different slots would compare unequal.
    final residual = Transform2.translation(1, 2);
    expect(BeginResidualOp(residual, debugHandle: const Handle(7)),
        BeginResidualOp(residual, debugHandle: const Handle(9)));
    expect(BeginResidualOp(residual, debugHandle: const Handle(7)).hashCode,
        BeginResidualOp(residual).hashCode);
  });
}
