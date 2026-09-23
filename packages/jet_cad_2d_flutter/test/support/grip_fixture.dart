import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection_fixture.dart';

/// The spec's standard 03 fixture (Testing).
///
/// - Everything sits at x ≈ 7000–7550, y ≈ 3000–3330, so the rebase origin
///   is non-zero.
/// - A closed room.
/// - Arcs with a non-zero start, one of them with a negative sweep.
/// - A group whose own transform is a rotation.
/// - Two instances of one definition.
/// - The root stays the identity.
final class GripScene {
  GripScene._(this.document);

  final DraftDocument document;
  late final Handle line, polyline, room, circle, arcPos, arcNeg, point;
  late final Handle group, groupLeaf, def, defLeaf, instA, instB;
}

GripScene gripScene(
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    PageComponent? page}) {
  final doc = DraftDocument.empty(measurer: measurer);
  final s = GripScene._(doc);
  final root = doc.rootHandle;
  s.line = addEntity(doc, root, EntityKind.line, [7010, 3020, 7130, 3060], []);
  s.polyline = addEntity(doc, root, EntityKind.polyline,
      [7010, 3100, 7040, 3130, 7070, 3100, 7100, 3130, 7130, 3100], []);
  s.room = addEntity(doc, root, EntityKind.polyline,
      [7200, 3000, 7400, 3000, 7400, 3150, 7200, 3150, 7200, 3000], []);
  s.circle = addEntity(doc, root, EntityKind.circle, [7300, 3250], [25]);
  s.arcPos = addEntity(doc, root, EntityKind.arc, [7050, 3200], [40, 0.3, 1.9]);
  s.arcNeg =
      addEntity(doc, root, EntityKind.arc, [7150, 3250], [30, 2.2, -1.4]);
  s.point = addEntity(doc, root, EntityKind.point, [7250, 3300], []);
  s.group = addGroup(doc, root,
      Transform2.translation(7400, 3300).multiply(Transform2.rotation(0.6)));
  s.groupLeaf = addEntity(doc, s.group, EntityKind.line, [0, 0, 40, 0], []);
  s.def = addDefinition(doc, 'Table');
  s.defLeaf = addEntity(doc, s.def, EntityKind.line, [0, 0, 30, 10], []);
  s.instA = addInstance(doc, s.def,
      Transform2.translation(7450, 3050).multiply(Transform2.rotation(0.3)));
  s.instB = addInstance(doc, s.def,
      Transform2.translation(7500, 3200).multiply(Transform2.rotation(-0.5)));
  if (page != null) {
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(root, page));
  }
  // `undoDepth` counts the drag under test only.
  doc.commands.clearHistory();
  expect(doc.tree[root]!.transform.isIdentity, isTrue,
      reason: 'spec, Testing: the root stays the identity');
  return s;
}

/// Zoomed (scale ≠ 1), rotated (not 0°, not 90°), y flipped, and panned so
/// [centre] sits in the middle of [viewport].
CameraController gripCamera(
    {Vector2? centre,
    Size viewport = const Size(800, 600),
    double scale = 1.1,
    double rotation = 0.35}) {
  final c = centre ?? Vector2(7270, 3161);
  final linear =
      Transform2.rotation(rotation).multiply(Transform2.scale(scale, -scale));
  final mid = linear.transformPoint(c);
  return CameraController(ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              viewport.width / 2 - mid.x, viewport.height / 2 - mid.y)
          .multiply(linear)));
}

/// World (x, y) on screen under [camera].
Offset screenOf(CameraController camera, double x, double y) {
  final s = camera.value.worldToScreen(Vector2(x, y));
  return Offset(s.x, s.y);
}

/// The stored payload of [h], as a `read` copy.
GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The codec's output: equal strings are a byte-identical document
/// (invariant 2).
String snapshot(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);
