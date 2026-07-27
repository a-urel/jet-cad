import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// The model is Float64 end to end.
///
/// Only the renderer's residual matrix is ever float32, and it gets there by
/// rebasing — which is a Plan 3 concern. What this plan owes that design is a
/// model that has not already lost the precision, so these assertions are
/// exact rather than approximate.
void main() {
  const siteX = 4.5e6;
  const siteY = -3.2e6;

  test('a composed instance transform is exact at site-plan magnitudes', () {
    final doc = DraftDocument.empty();
    final group = doc.handleSeed.next();
    final instance = doc.handleSeed.next();
    final definition = doc.handleSeed.next();

    doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.tree.addNode(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(siteX, siteY),
      children: [instance],
    ));
    doc.tree.addNode(InstanceNode(
      handle: instance,
      parent: group,
      transform: Transform2.translation(0.125, 0.25),
      definition: definition,
      layer: ReservedHandles.layerZero,
    ));

    final point = doc.tree
        .accumulatedTransform(instance)
        .transformPoint(Vector2(0.0625, 0.0625));
    expect(point.x, siteX + 0.1875);
    expect(point.y, siteY + 0.3125);
  });

  test('extents at site-plan magnitudes keep sub-millimetre detail', () {
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
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
        coords:
            Float64List.fromList([siteX, siteY, siteX + 0.001, siteY + 0.001]),
        scalars: Float64List(0),
      ),
    ));
    expect(doc.extents.size.x, closeTo(0.001, 1e-9));
  });

  test('a large-coordinate document survives a byte-identical round-trip', () {
    final doc = DraftDocument.empty();
    doc.tree.addNode(GroupNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      transform: Transform2.translation(siteX, siteY),
      children: const [],
    ));
    final once = DraftDocumentCodec.encodeToString(doc);
    final twice = DraftDocumentCodec.encodeToString(
        DraftDocumentCodec.decodeString(once));
    expect(twice, once);
  });
}
