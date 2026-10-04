// A minimal Select tool rig for app tests, built on the render package's
// public exports only (the render package's own `GripRig` lives in its test
// tree and is not exported). Wired in the shell's order: selection, outline
// cache, grip cache; object snap off, so a press lands on the raw pointer.
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart' show Offset;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A camera whose centre is [centre], [scale] pixels per world unit, y up,
/// on an 800 x 600 surface.
CameraController selectCamera(Vector2 centre, {double scale = 0.2}) {
  final linear = Transform2.scale(scale, -scale);
  final mid = linear.transformPoint(centre);
  return CameraController(ViewportTransform(
      worldToScreenMatrix:
          Transform2.translation(400 - mid.x, 300 - mid.y).multiply(linear)));
}

final class SelectRig {
  SelectRig(this.document, this.camera)
      : index = SpatialIndex(document),
        selection = SelectionController(document) {
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines);
    snap = SnapSettings(objectSnap: false);
    page = PageNotifier(document);
    tool = SelectTool();
    context = ToolContext(
        document: document,
        index: index,
        camera: camera,
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

  Offset screenOf(double x, double y) {
    final s = camera.value.worldToScreen(Vector2(x, y));
    return Offset(s.x, s.y);
  }

  Vector2 worldOf(Offset screen) =>
      camera.value.screenToWorld(Vector2(screen.dx, screen.dy));

  ToolPointerEvent pointerAt(Offset screen, {int buttons = kPrimaryButton}) =>
      ToolPointerEvent(
        screen: screen,
        world: worldOf(screen),
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
      );

  /// Press at [from], one move to [to] (past the slop), release at [to].
  void drag(Offset from, Offset to) {
    tool.onPointerDown(pointerAt(from), context);
    tool.onPointerMove(pointerAt(to), context);
    tool.onPointerUp(pointerAt(to, buttons: 0), context);
  }
}
