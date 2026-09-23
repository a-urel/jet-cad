import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
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
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/page_notifier.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:jet_cad_2d_flutter/src/snap_settings.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection_fixture.dart';

// ---- Task 4: the scene, the camera, the readers -------------------------

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
///
/// A y-flipped rotation is a reflection, whose linear part is symmetric:
/// the matrix's `b` and `c` are bit-identical. A test about a projection
/// expression passes `flipY: false` too, or an `m.b`/`m.c` transposition
/// is invisible to it.
CameraController gripCamera(
    {Vector2? centre,
    Size viewport = const Size(800, 600),
    double scale = 1.1,
    double rotation = 0.35,
    bool flipY = true}) {
  final c = centre ?? Vector2(7270, 3161);
  final linear = Transform2.rotation(rotation)
      .multiply(Transform2.scale(scale, flipY ? -scale : scale));
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

// ---- Task 7: the rig, the pointer, the layer ----------------------------

/// Everything a `SelectTool` grip test drives, wired in the shell's order:
/// the selection controller, then the outline cache, then the grip cache
/// (spec D6, Ruling 03-19). Object snap is off unless asked for, so a test
/// that is not about snapping lands on the raw pointer.
final class GripRig {
  GripRig(this.document, {CameraController? camera, bool objectSnap = false})
      : index = SpatialIndex(document),
        selection = SelectionController(document),
        camera = camera ?? gripCamera() {
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines);
    snap = SnapSettings(objectSnap: objectSnap);
    page = PageNotifier(document);
    tool = SelectTool();
    context = ToolContext(
        document: document,
        index: index,
        camera: this.camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final SpatialIndex index;
  final SelectionController selection;
  final CameraController camera;
  late final OutlineCache outlines;
  late final GripCache grips;
  late final SnapSettings snap;
  late final PageNotifier page;
  late final SelectTool tool;
  late final ToolContext context;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    grips.dispose();
    outlines.dispose();
    page.dispose();
    snap.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

GripRig gripRig(DraftDocument document,
    {CameraController? camera, bool objectSnap = false}) {
  final rig = GripRig(document, camera: camera, objectSnap: objectSnap);
  addTearDown(rig.dispose);
  return rig;
}

/// A pointer sample at [screen], resolved through [camera] exactly as
/// `InteractionLayer` does it.
ToolPointerEvent pointerAt(CameraController camera, Offset screen,
        {int buttons = kPrimaryButton, bool shift = false, int pointer = 1}) =>
    ToolPointerEvent(
      screen: screen,
      world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
      pointer: pointer,
      buttons: buttons,
      shift: shift,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
    );

/// Press at [from], then one move to [to]: past the slop in one event.
void pressAndMove(GripRig rig, Offset from, Offset to, {bool shift = false}) {
  rig.tool
      .onPointerDown(pointerAt(rig.camera, from, shift: shift), rig.context);
  rig.tool.onPointerMove(pointerAt(rig.camera, to, shift: shift), rig.context);
}

void release(GripRig rig, Offset at, {bool shift = false}) =>
    rig.tool.onPointerUp(
        pointerAt(rig.camera, at, shift: shift, buttons: 0), rig.context);

void click(GripRig rig, Offset at, {bool shift = false}) {
  rig.tool.onPointerDown(pointerAt(rig.camera, at, shift: shift), rig.context);
  release(rig, at, shift: shift);
}

/// The layer's box under test, centred in the 800 × 600 surface so a drag
/// can leave it and stay on the surface (W2).
const Size kGripLayerSize = Size(600, 450);

/// Pumps an `InteractionLayer` over the canvas and the overlay, both driven
/// by [rig].
///
/// Teardown order: build [rig] (which registers its dispose) **before**
/// calling this. The empty pump registered here then runs first, while the
/// rig is still live.
Future<void> pumpGripLayer(WidgetTester tester, GripRig rig) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: kGripLayerSize.width,
        height: kGripLayerSize.height,
        child: InteractionLayer(
          tools: rig.tools,
          child: Stack(children: [
            RepaintBoundary(
              child: DraftCanvas(
                  document: rig.document, index: rig.index, camera: rig.camera),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SelectionOverlayPainter(
                    selection: rig.selection,
                    tools: rig.tools,
                    camera: rig.camera,
                    outlines: rig.outlines,
                    repaint: Listenable.merge([
                      rig.selection,
                      rig.tools,
                      rig.camera,
                      rig.outlines,
                      rig.grips,
                    ]),
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
  await tester.pump();
  expect(tester.getSize(find.byType(InteractionLayer)), kGripLayerSize,
      reason: 'a zero-sized layer would receive no pointer events');
}

/// [local] in the layer's box, in the surface's global coordinates.
Offset globalAt(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(InteractionLayer)) + local;

// ---- After the look: the oriented selection box -------------------------

/// Where the rotation grip of [box] under the rigid [frame] sits once a
/// rotation is carried (spec D6, amended after the look), by an oracle
/// that never calls `rotationGripOf`: world points through [screenOf].
///
/// The grip hangs from the middle of the frame's top edge — local `maxY`
/// under a y-flipped camera, `minY` otherwise — and its direction is the
/// frame's up vector as the camera draws it.
({Offset anchor, Offset centre, Offset stem}) orientedGripOracle(
    CameraController camera, Aabb2 box, Transform2 frame) {
  final flipped = camera.value.worldToScreenMatrix.determinant < 0;
  final local =
      Vector2((box.minX + box.maxX) / 2, flipped ? box.maxY : box.minY);
  final a = frame.transformPoint(local);
  final tip = frame.transformPoint(local + Vector2(0, flipped ? 1 : -1));
  final sa = screenOf(camera, a.x, a.y);
  final st = screenOf(camera, tip.x, tip.y);
  final dir = (st - sa) / (st - sa).distance;
  final centre = sa + dir * kRotationGripOffset;
  return (
    anchor: sa,
    centre: centre,
    stem: centre - dir * (kRotationGripPixels / 2),
  );
}

/// A right triangle with no symmetry, alone in its document: its world
/// box's centre moves under a rotation, so a pivot taken from a re-wrapped
/// world box drifts where the carried frame's does not.
(DraftDocument, Handle) triangleDoc() {
  final doc = DraftDocument.empty();
  final h = addEntity(doc, doc.rootHandle, EntityKind.polyline,
      [7010, 3020, 7130, 3020, 7030, 3090, 7010, 3020], []);
  doc.commands.clearHistory();
  return (doc, h);
}

/// The rotation grip's centre as the cache places it now.
Offset rotationGripNow(GripRig rig) => rotationGripOf(
        rig.grips.box!, rig.camera.value.worldToScreenMatrix, rig.grips.frame)
    .centre;

/// One rotate drag of [theta] radians from the rotation grip, about the
/// cache's pivot: the pointer lands at the grip's world point turned by
/// [theta].
void rotateBy(GripRig rig, double theta) {
  final grip = rotationGripNow(rig);
  final p = rig.grips.pivot!;
  final w = rig.camera.value.screenToWorld(Vector2(grip.dx, grip.dy)) - p;
  final aim = p +
      Vector2(math.cos(theta) * w.x - math.sin(theta) * w.y,
          math.sin(theta) * w.x + math.cos(theta) * w.y);
  final to = screenOf(rig.camera, aim.x, aim.y);
  pressAndMove(rig, grip, to);
  expect(rig.tool.pressClass, PressClass.rotationGrip);
  release(rig, to);
}
