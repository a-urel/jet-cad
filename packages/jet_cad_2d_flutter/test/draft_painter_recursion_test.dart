import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const Size kViewport = Size(800, 600);

Handle addLineAt(
    DraftDocument doc, Handle owner, Handle handle, double x, double y,
    {DraftColor color = const ByLayerColor()}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
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

Handle defineEmpty(DraftDocument doc, Handle def, [String name = 'sym']) {
  doc.tree.addDefinition(Definition(
      handle: def, name: name, basePoint: Vector2.zero(), children: const []));
  return def;
}

Handle place(DraftDocument doc, Handle handle, Handle def, Transform2 t,
    {Handle parent = Handle.none, DraftColor color = const ByBlockColor()}) {
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: parent.isNone ? doc.rootHandle : parent,
    transform: t,
    definition: def,
    layer: ReservedHandles.layerZero,
    color: color,
  )));
  return handle;
}

({DraftPainter painter, RecordingDrawSink sink, ViewportTransform camera})
    paintAll(DraftDocument doc,
        {Aabb2? view, void Function(SpatialIndex index)? beforePaint}) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  beforePaint?.call(index);
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  final camera = ViewportTransform.fit(view ?? doc.extents, kViewport);
  final sink = RecordingDrawSink();
  painter.paint(sink, camera, kViewport);
  return (painter: painter, sink: sink, camera: camera);
}

List<Handle> handleOrderOf(List<DrawOp> ops) => ops
    .whereType<BeginResidualOp>()
    .map((op) => op.debugHandle)
    .where((h) => !h.isNone)
    .toList();

/// The world point the sink was actually told to draw, reconstructed from the
/// residual that was in force and the first emitted vertex.
Vector2 firstWorldPoint(List<DrawOp> ops, ViewportTransform camera) {
  final begin = ops.whereType<BeginResidualOp>().first;
  final line = ops.whereType<PolylineOp>().first;
  final screen =
      begin.residual.transformPoint(Vector2(line.points[0], line.points[1]));
  return camera.screenToWorld(screen);
}

void main() {
  test('a slot in both the tree and the dirty overlay is drawn once', () {
    // ContainerIndex.searchLeaves visits the packed tree and then the dirty
    // overlay, and documents that a slot in both is visited twice. SpatialIndex
    // deduplicates for its own callers; a ContainerIndex caller gets nothing
    // for free, and a doubled draw is invisible on opaque strokes and wrong the
    // moment 3b adds transparency.
    final doc = DraftDocument.empty();
    final def = defineEmpty(doc, const Handle(500));
    final leaf = addLineAt(doc, def, const Handle(700), 0, 0);
    place(doc, const Handle(600), def, Transform2.translation(5, 5));

    final run = paintAll(doc, beforePaint: (index) {
      // Exactly the documented condition: the same slot alive in the tree and
      // present in the dirty overlay.
      final ci = index.indexFor(def)!;
      final slot = doc.entities.slotOf(leaf)!;
      ci.dirty.put(slot, ci.boxOfLeaf(slot)!, 0, 0);
    });

    expect(run.sink.ops.whereType<PolylineOp>(), hasLength(1));
  });

  test('definition contents are drawn in ascending handle order', () {
    // searchLeaves is not ordered. Adding them out of order is what makes the
    // assertion mean something.
    final doc = DraftDocument.empty();
    final def = defineEmpty(doc, const Handle(500));
    addLineAt(doc, def, const Handle(702), 4, 0);
    addLineAt(doc, def, const Handle(700), 0, 0);
    addLineAt(doc, def, const Handle(701), 2, 0);
    place(doc, const Handle(600), def, Transform2.translation(5, 5));

    final run = paintAll(doc);
    expect(handleOrderOf(run.sink.ops),
        [const Handle(700), const Handle(701), const Handle(702)]);
  });

  test('two levels of nesting compose ancestors outward-in', () {
    // The outer instance scales 2x and the inner translates by 10. Composed
    // outward-in the point lands at 20; inward-out it lands at 10. Neither
    // transform is the identity, so the two cannot coincide.
    final doc = DraftDocument.empty();
    final inner = defineEmpty(doc, const Handle(500), 'inner');
    final outer = defineEmpty(doc, const Handle(501), 'outer');
    addLineAt(doc, inner, const Handle(700), 0, 0);
    place(doc, const Handle(600), inner, Transform2.translation(10, 0),
        parent: outer);
    place(doc, const Handle(601), outer, Transform2.scale(2, 2));

    final run = paintAll(doc);
    final world = firstWorldPoint(run.sink.ops, run.camera);
    expect(world.x, closeTo(20.0, 1e-6));
  });

  test('an instance inside a definition is descended into', () {
    final doc = DraftDocument.empty();
    final inner = defineEmpty(doc, const Handle(500), 'inner');
    final outer = defineEmpty(doc, const Handle(501), 'outer');
    addLineAt(doc, inner, const Handle(700), 0, 0);
    addLineAt(doc, outer, const Handle(701), 20, 0);
    place(doc, const Handle(600), inner, Transform2.translation(10, 0),
        parent: outer);
    place(doc, const Handle(601), outer, Transform2.identity());

    final run = paintAll(doc);
    expect(handleOrderOf(run.sink.ops), [const Handle(700), const Handle(701)],
        reason: 'the nested definition draws before the outer leaf, '
            'because 700 < 701');
  });

  test('the query rectangle is expressed in the container own space', () {
    // A painter that handed the world rectangle straight to searchLeaves would
    // cull against the wrong coordinates. Under a large instance translation
    // it would then draw everything or nothing, and a fixture placed at the
    // origin could not tell.
    final doc = DraftDocument.empty();
    final def = defineEmpty(doc, const Handle(500));
    addLineAt(doc, def, const Handle(700), 0, 0);
    addLineAt(doc, def, const Handle(701), 100000, 0);
    place(
        doc, const Handle(600), def, Transform2.translation(4500000, 1200000));

    final run = paintAll(doc,
        view: Aabb2(Vector2(4499990, 1199990), Vector2(4500010, 1200010)));
    expect(handleOrderOf(run.sink.ops), [const Handle(700)]);
  });

  test('a definition placed by a singular instance does not throw', () {
    final doc = DraftDocument.empty();
    final def = defineEmpty(doc, const Handle(500));
    addLineAt(doc, def, const Handle(700), 0, 0);
    place(doc, const Handle(600), def, Transform2.scale(0, 0));
    addLineAt(doc, doc.rootHandle, const Handle(800), 0, 0);

    final run = paintAll(doc);
    expect(handleOrderOf(run.sink.ops), [const Handle(800)],
        reason: 'the healthy root leaf still draws');
  });

  test('a definition body authored ByBlock takes the instance colour', () {
    // Task 2's context resolution has to reach the painter, threaded through
    // the recursion. Without it every instance of a symbol renders identically.
    final doc = DraftDocument.empty();
    final def = defineEmpty(doc, const Handle(500));
    addLineAt(doc, def, const Handle(700), 0, 0, color: const ByBlockColor());
    place(doc, const Handle(600), def, Transform2.translation(5, 5),
        color: const IndexedColor(1));

    final run = paintAll(doc);
    expect(run.sink.ops.whereType<PolylineOp>().single.style.argb, 0xFFFF0000);
  });

  test('a nested instance composes contexts outward-in', () {
    final doc = DraftDocument.empty();
    final inner = defineEmpty(doc, const Handle(500), 'inner');
    final outer = defineEmpty(doc, const Handle(501), 'outer');
    addLineAt(doc, inner, const Handle(700), 0, 0, color: const ByBlockColor());
    place(doc, const Handle(600), inner, Transform2.translation(10, 0),
        parent: outer, color: const ByBlockColor());
    place(doc, const Handle(601), outer, Transform2.identity(),
        color: const IndexedColor(5));

    final run = paintAll(doc);
    expect(run.sink.ops.whereType<PolylineOp>().single.style.argb, 0xFF0000FF,
        reason: "ACI 5 from the outer instance, through the inner one's "
            'BYBLOCK');
  });

  test('a chain deeper than maxDepth is counted, not walked', () {
    // The tree rejects cycles, so this is defence against a document that
    // arrives another way. It matters because the walk recurses on the frame
    // path, where unbounded depth is a stack overflow rather than a wrong
    // picture — and because a silent cut-off would read as a complete frame.
    final doc = DraftDocument.empty();
    const levels = DraftPainter.maxDepth + 1;
    for (var i = 0; i < levels; i++) {
      defineEmpty(doc, Handle(500 + i), 'level$i');
    }
    // The only geometry sits at the very bottom, one level past the cap.
    addLineAt(doc, Handle(500 + levels - 1), const Handle(9000), 0, 0);
    for (var i = 0; i < levels - 1; i++) {
      place(doc, Handle(2000 + i), Handle(500 + i + 1), Transform2.identity(),
          parent: Handle(500 + i));
    }
    place(doc, const Handle(3000), const Handle(500), Transform2.identity());
    addLineAt(doc, doc.rootHandle, const Handle(9001), 0, 0);

    final run = paintAll(doc);
    expect(run.painter.skippedDeepInstanceCount, greaterThan(0));
    expect(handleOrderOf(run.sink.ops), contains(const Handle(9001)),
        reason: 'the root leaf is unaffected');
    expect(handleOrderOf(run.sink.ops), isNot(contains(const Handle(9000))));
  });

  test('no depth buffer grows after warm-up', () {
    final doc = generateDocument(20000, definitionCount: 200);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    painter.paint(NullDrawSink(), camera, kViewport);
    final warm = List<int>.from(painter.depthBufferCapacities);
    expect(warm, isNotEmpty, reason: 'the corpus must actually recurse');
    for (var i = 0; i < 20; i++) {
      painter.paint(NullDrawSink(), camera, kViewport);
    }
    expect(painter.depthBufferCapacities, warm);
  });

  test('the corpus draws the same picture twice in a row', () {
    // Nothing in the walk may depend on scratch left over from the last frame.
    final doc = generateDocument(5000, definitionCount: 20);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    final first = RecordingDrawSink();
    painter.paint(first, camera, kViewport);
    final second = RecordingDrawSink();
    painter.paint(second, camera, kViewport);

    expect(second.ops, first.ops);
    expect(first.ops, isNotEmpty);
  });
}
