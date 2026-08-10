import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const Size kViewport = Size(800, 600);

Handle addLine(
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

Handle define(DraftDocument doc, Handle def) {
  doc.tree.addDefinition(Definition(
      handle: def, name: 'sym', basePoint: Vector2.zero(), children: const []));
  return def;
}

Handle place(DraftDocument doc, Handle handle, Handle def) {
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: doc.rootHandle,
    transform: Transform2.translation(5, 5),
    definition: def,
    layer: ReservedHandles.layerZero,
  )));
  return handle;
}

({DraftPainter painter, RecordingDrawSink sink}) paintAll(DraftDocument doc,
    {bool withMap = true, Aabb2? view}) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
    document: doc,
    index: index,
    resolver: DocumentStyleResolver(doc),
    ownerMap: withMap ? LeafOwnerMap(doc) : null,
  );
  final sink = RecordingDrawSink();
  painter.paint(
      sink, ViewportTransform.fit(view ?? doc.extents, kViewport), kViewport);
  return (painter: painter, sink: sink);
}

List<Handle> handleOrderOf(List<DrawOp> ops) => ops
    .whereType<BeginResidualOp>()
    .map((op) => op.debugHandle)
    .where((h) => !h.isNone)
    .toList();

void main() {
  test('a definition below the cull floor is drawn straight from its bucket',
      () {
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700), 0, 0);
    addLine(doc, def, const Handle(701), 2, 0);
    place(doc, const Handle(600), def);

    final run = paintAll(doc);
    expect(run.painter.directBucketCount, 1);
    expect(handleOrderOf(run.sink.ops), [const Handle(700), const Handle(701)]);
  });

  test('without an owner map every container takes the rect query', () {
    // The shortcut is opt-in. A caller that forgets to feed a map changes with
    // it gets the slower path, never a stale one.
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700), 0, 0);
    place(doc, const Handle(600), def);

    expect(paintAll(doc, withMap: false).painter.directBucketCount, 0);
  });

  test('a definition holding a nested group keeps the rect query', () {
    // `slotsOf` answers for leaves a container owns *directly*. A group inside
    // a definition is flattened into the definition's index, but its leaves
    // are owned by the group node — so the bucket is short, and taking it
    // would silently drop them. The count guard is what catches that.
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700), 0, 0);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: const Handle(550),
      parent: def,
      transform: Transform2.translation(3, 0),
      children: const [],
    )));
    addLine(doc, const Handle(550), const Handle(701), 0, 0);
    place(doc, const Handle(600), def);

    final run = paintAll(doc);
    expect(run.painter.directBucketCount, 0);
    expect(handleOrderOf(run.sink.ops), [const Handle(700), const Handle(701)],
        reason: 'the group-owned leaf must still be drawn');
  });

  test('a definition edited since the index was built keeps the rect query',
      () {
    // A leaf added after the build lives in the dirty overlay, not the packed
    // tree, so the container's leaf count is behind the bucket. Falling back
    // is the safe answer.
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700), 0, 0);
    place(doc, const Handle(600), def);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final map = LeafOwnerMap(doc);
    addLine(doc, def, const Handle(701), 2, 0);
    map.rebuild();

    final painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        ownerMap: map);
    final sink = RecordingDrawSink();
    painter.paint(
        sink, ViewportTransform.fit(doc.extents, kViewport), kViewport);

    expect(painter.directBucketCount, 0);
    expect(handleOrderOf(sink.ops), [const Handle(700), const Handle(701)]);
  });

  test('a definition above the cull floor keeps the rect query', () {
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    for (var i = 0; i <= kCullFloor; i++) {
      addLine(doc, def, Handle(700 + i), i.toDouble(), 0);
    }
    place(doc, const Handle(600), def);

    expect(paintAll(doc).painter.directBucketCount, 0);
  });

  test('both paths draw the same picture', () {
    // The shortcut is an optimisation of one walk. With the whole document in
    // view the two must agree op for op, including the residuals.
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700), 0, 0);
    addLine(doc, def, const Handle(701), 2, 0);
    addLine(doc, doc.rootHandle, const Handle(800), 20, 20);
    place(doc, const Handle(600), def);

    final withMap = paintAll(doc);
    final without = paintAll(doc, withMap: false);

    expect(withMap.painter.directBucketCount, 1);
    expect(without.painter.directBucketCount, 0);
    expect(withMap.sink.ops, without.sink.ops);
  });
}
