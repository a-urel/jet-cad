import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const Size kViewport = Size(800, 600);

Handle addEntity(
  DraftDocument doc,
  Handle owner,
  Handle handle,
  EntityKind kind,
  List<double> coords,
  List<double> scalars, {
  DraftColor color = const ByLayerColor(),
}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: 25,
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

/// The corpus every differential test runs on.
///
/// **No identity transform anywhere.** Plan 2's post-mortem records a
/// composition-order defect that four separate fixtures failed to catch because
/// their transforms were the identity, which commutes and hides ordering. Every
/// instance here carries a distinct non-uniform scale, a rotation and a
/// translation; one is mirrored; one is nested two levels deep; one leaf is
/// owned by a group node so the folded leaf transform is exercised.
DraftDocument differentialFixture({double originX = 0}) {
  final doc = DraftDocument.empty();
  final ox = originX;
  final oy = originX == 0 ? 0.0 : 1200000.0;

  // --- definitions -------------------------------------------------------
  const inner = Handle(500), outer = Handle(501);
  doc.tree.addDefinition(Definition(
      handle: inner,
      name: 'inner',
      basePoint: Vector2.zero(),
      children: const []));
  doc.tree.addDefinition(Definition(
      handle: outer,
      name: 'outer',
      basePoint: Vector2.zero(),
      children: const []));

  addEntity(
      doc, inner, const Handle(700), EntityKind.line, [0, 0, 4, 1], const []);
  addEntity(
      doc, inner, const Handle(701), EntityKind.circle, [2, 2], const [1.5]);
  addEntity(doc, outer, const Handle(702), EntityKind.polyline,
      [0, 0, 3, 0, 3, 3, 0, 3], const [],
      color: const ByBlockColor());
  addEntity(doc, outer, const Handle(703), EntityKind.arc, [6, 1],
      const [2, 0.4, 1.9]);

  // The nested instance: two levels deep once `outer` is placed.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(520),
    parent: outer,
    transform: Transform2.translation(7.5, 2.25)
        .multiply(Transform2.rotation(0.53))
        .multiply(Transform2.scale(1.4, 2.1)),
    definition: inner,
    layer: ReservedHandles.layerZero,
    color: const ByBlockColor(),
  )));

  // --- root content ------------------------------------------------------
  addEntity(doc, doc.rootHandle, const Handle(800), EntityKind.line,
      [ox + 1, oy + 1, ox + 9, oy + 6], const []);

  // A group, so a root leaf carries a folded transform.
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: const Handle(810),
    parent: doc.rootHandle,
    transform: Transform2.translation(ox + 12, oy + 3)
        .multiply(Transform2.rotation(-0.37))
        .multiply(Transform2.scale(1.9, 1.15)),
    children: const [],
  )));
  addEntity(doc, const Handle(810), const Handle(811), EntityKind.line,
      [0, 0, 5, 2], const []);

  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(820),
    parent: doc.rootHandle,
    transform: Transform2.translation(ox + 20, oy + 8)
        .multiply(Transform2.rotation(0.21))
        .multiply(Transform2.scale(1.6, 1.1)),
    definition: outer,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(3),
  )));

  // Mirrored, and still conformal: anisotropyRatio 1. Its own polyline leaf
  // takes the screen-space path regardless (every line-like leaf does now);
  // the arc sharing this instance is what still exercises the residual path.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(830),
    parent: doc.rootHandle,
    transform: Transform2.translation(ox + 40, oy + 4)
        .multiply(Transform2.rotation(1.1))
        .multiply(Transform2.scale(-1.3, 1.3)),
    definition: outer,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(5),
  )));

  addEntity(doc, doc.rootHandle, const Handle(840), EntityKind.point,
      [ox + 30, oy + 15], const []);

  return doc;
}

/// A guard so the rule cannot rot.
void assertNoIdentityTransforms(DraftDocument doc) {
  for (final handle in const [
    Handle(520),
    Handle(810),
    Handle(820),
    Handle(830),
  ]) {
    final node = doc.tree[handle];
    expect(node, isNotNull, reason: 'fixture node $handle went missing');
    expect(node!.transform.isIdentity, isFalse,
        reason: 'fixture rule: an identity transform hides ordering defects');
  }
}

/// The one spelling every differential test uses, so a signature change lands
/// in one place.
List<DrawOp> paintToRecording(DraftDocument doc, [ViewportTransform? camera]) {
  final index = SpatialIndex(doc);
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc))
      .paint(sink, view, kViewport);
  index.dispose();
  return sink.ops;
}

List<DrawOp> referenceToRecording(DraftDocument doc,
    [ViewportTransform? camera]) {
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  referenceWalk(doc, sink, view, kViewport, DocumentStyleResolver(doc));
  return sink.ops;
}

/// A camera tight around the nested instance, so most of the document culls
/// away and the comparison is about what survives.
ViewportTransform cameraOverNestedInstance(DraftDocument doc) {
  final node = doc.tree[const Handle(820)] as InstanceNode;
  final centre = node.transform.transformPoint(Vector2(8, 3));
  return ViewportTransform.fit(
      Aabb2(Vector2(centre.x - 6, centre.y - 5),
          Vector2(centre.x + 6, centre.y + 5)),
      kViewport);
}
