import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart'
    show
        Center,
        CustomPaint,
        Directionality,
        Listenable,
        Offset,
        Positioned,
        RepaintBoundary,
        Size,
        SizedBox,
        Stack,
        TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draft_canvas.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
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

/// The interaction layer's size under test; the box is centred in the
/// 800 x 600 test surface, so its top-left sits at (200, 150). Tests read the
/// origin back from [WidgetTester.getTopLeft] rather than assuming it.
const Size kInteractionSize = Size(400, 300);

/// Everything an [InteractionLayer] widget test drives, wired in the order
/// the ledger fixes: [SelectionController] is constructed **before**
/// [OutlineCache], so the controller prunes a dead key on a `DocChange`
/// before the cache walks the document looking for it.
final class InteractionRig {
  InteractionRig(this.document, this.camera)
      : index = SpatialIndex(document),
        selection = SelectionController(document) {
    outlines = OutlineCache(document, selection);
    tool = SelectTool();
    context = ToolContext(
        document: document, index: index, camera: camera, selection: selection);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final CameraController camera;
  final SpatialIndex index;
  final SelectionController selection;
  late final OutlineCache outlines;
  late final SelectTool tool;
  late final ToolContext context;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    outlines.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

/// Pumps an [InteractionLayer] over the real view it drives — the drawing in
/// one `RepaintBoundary`, the selection overlay in another — inside a centred
/// 400 x 300 box, and returns the rig behind it.
///
/// The layer is what every pointer and key event under test lands on, so this
/// asserts the box actually laid out at [kInteractionSize]: a zero-sized
/// layer would receive nothing and let most assertions below pass for the
/// wrong reason.
///
/// Teardown order matters and is fixed here. The rig is registered first and
/// an empty pump second, so the empty pump runs **first** (tear-downs are
/// LIFO): the layer's `State.dispose` then reaches a live
/// [SelectionController] and a live [ToolController], not disposed ones.
Future<InteractionRig> pumpInteraction(
  WidgetTester tester, {
  required DraftDocument document,
  required CameraController camera,
}) async {
  final rig = InteractionRig(document, camera);
  addTearDown(rig.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: kInteractionSize.width,
        height: kInteractionSize.height,
        child: InteractionLayer(
          tools: rig.tools,
          child: Stack(children: [
            RepaintBoundary(
              child: DraftCanvas(
                document: rig.document,
                index: rig.index,
                camera: rig.camera,
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SelectionOverlayPainter(
                    selection: rig.selection,
                    tools: rig.tools,
                    camera: rig.camera,
                    outlines: rig.outlines,
                    repaint: Listenable.merge(
                        [rig.selection, rig.tools, rig.camera]),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
  ));
  // `autofocus` lands on the frame after the tree is first built.
  await tester.pump();

  expect(tester.getSize(find.byType(InteractionLayer)), kInteractionSize,
      reason: 'a zero-sized layer would receive no pointer events at all and '
          'let every routing assertion pass for the wrong reason');
  return rig;
}
