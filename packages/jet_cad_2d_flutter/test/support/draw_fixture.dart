import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draw/placement_tool.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/page_notifier.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/snap_settings.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'grip_fixture.dart' show gripCamera, pointerAt;
import 'selection_fixture.dart' show addEntity;

/// The anchor line's start: off every lattice, so a snapped point that went
/// through any arithmetic shows in the low bits (M-05k).
const double kAnchorX = 7137.3, kAnchorY = 3161.7;

final class DrawScene {
  DrawScene._(this.document, this.anchor);
  final DraftDocument document;
  final Handle anchor;
}

/// Spec 05, Testing: a 1:20 page anchored at (7000, 3000), grid snap off
/// unless asked, and one line from ([kAnchorX], [kAnchorY]) to
/// (7300.9, 3190.1). The root stays the identity.
DrawScene drawScene({bool snapToGrid = false}) {
  final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: snapToGrid)));
  final anchor = addEntity(doc, doc.rootHandle, EntityKind.line,
      [kAnchorX, kAnchorY, 7300.9, 3190.1], []);
  doc.commands.clearHistory();
  expect(doc.tree[doc.rootHandle]!.transform.isIdentity, isTrue);
  return DrawScene._(doc, anchor);
}

/// Everything a drawing tool test drives, wired as the shell wires it.
final class DrawRig {
  DrawRig(this.document, this.tool,
      {required this.camera, bool objectSnap = true})
      : index = SpatialIndex(document),
        selection = SelectionController(document) {
    outlines = OutlineCache(document, selection);
    page = PageNotifier(document);
    snap = SnapSettings(objectSnap: objectSnap);
    context = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final PlacementTool tool;
  final CameraController camera;
  final SpatialIndex index;
  final SelectionController selection;
  late final OutlineCache outlines;
  late final PageNotifier page;
  late final SnapSettings snap;
  late final ToolContext context;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    outlines.dispose();
    page.dispose();
    snap.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

/// The standard camera (spec 05, Testing): 03's `gripCamera`, centred on
/// the scene. Every tool test runs it for both [flipY] values.
DrawRig drawRig(DraftDocument doc, PlacementTool tool,
    {bool flipY = true, bool objectSnap = true}) {
  final rig = DrawRig(doc, tool,
      camera: gripCamera(centre: Vector2(7200, 3150), flipY: flipY),
      objectSnap: objectSnap);
  addTearDown(rig.dispose);
  return rig;
}

/// The world point the layer would hand the tool for screen [s].
Vector2 worldAt(DrawRig rig, Offset s) =>
    rig.camera.value.screenToWorld(Vector2(s.dx, s.dy));

void hoverAt(DrawRig rig, Offset s, {bool shift = false}) =>
    rig.tool.onPointerMove(
        pointerAt(rig.camera, s, buttons: 0, shift: shift), rig.context);

/// A press with no hover before it (AR4, M-05z).
void downAt(DrawRig rig, Offset s, {bool shift = false}) =>
    rig.tool.onPointerDown(pointerAt(rig.camera, s, shift: shift), rig.context);

/// Hover, press, release: what a mouse click delivers.
void clickAt(DrawRig rig, Offset s, {bool shift = false}) {
  hoverAt(rig, s, shift: shift);
  downAt(rig, s, shift: shift);
  rig.tool.onPointerUp(
      pointerAt(rig.camera, s, buttons: 0, shift: shift), rig.context);
}

KeyEventResult keyDown(
        DrawRig rig, LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    rig.tool.onKey(
        KeyDownEvent(
            physicalKey: physical, logicalKey: key, timeStamp: Duration.zero),
        rig.context);
