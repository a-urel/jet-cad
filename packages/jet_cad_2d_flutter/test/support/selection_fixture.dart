import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Translate, then rotate, then scale — non-commuting, so a test built on it
/// would not pass under a bug that drops or reorders one of the three
/// components the way an identity-transform fixture could not catch.
final Transform2 kPlacement = Transform2.translation(300, -200)
    .multiply(Transform2.rotation(math.pi / 6))
    .multiply(Transform2.scale(1.5, 1.5));

/// Copied from `pick_test.dart`, never imported from a test file.
Handle addEntity(DraftDocument doc, Handle owner, EntityKind kind,
    List<double> coords, List<double> scalars) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
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
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

Handle addDefinition(DraftDocument doc, String name) {
  final handle = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
    handle: handle,
    name: name,
    basePoint: Vector2.zero(),
    children: const [],
  ));
  return handle;
}

Handle addInstance(DraftDocument doc, Handle def, Transform2 transform,
    {Handle? parent}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(
    InstanceNode(
      handle: handle,
      parent: parent ?? doc.rootHandle,
      transform: transform,
      definition: def,
      layer: ReservedHandles.layerZero,
    ),
  ));
  return handle;
}

Handle addGroup(DraftDocument doc, Handle parent, Transform2 transform) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(
    GroupNode(
      handle: handle,
      parent: parent,
      transform: transform,
      children: const [],
    ),
  ));
  return handle;
}

CameraController cameraAt(double scale, Offset translation) {
  return CameraController(
    ViewportTransform(
      worldToScreenMatrix: Transform2(
        scale,
        0,
        0,
        -scale,
        translation.dx,
        translation.dy,
      ),
    ),
  );
}

/// Two instances of one definition: `a` at [kPlacement], `b` at a different
/// non-commuting placement, so a bug that keys selection off the definition
/// rather than the instance cannot pass M-02c′.
(Handle def, Handle a, Handle b, Handle leaf) twoInstancesOfOneDefinition(
    DraftDocument doc) {
  final def = addDefinition(doc, 'Def');
  final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
  final a = addInstance(doc, def, kPlacement);
  final b = addInstance(
    doc,
    def,
    Transform2.translation(900, 400)
        .multiply(Transform2.rotation(-math.pi / 4))
        .multiply(Transform2.scale(0.8, 0.8)),
  );
  return (def, a, b, leaf);
}
