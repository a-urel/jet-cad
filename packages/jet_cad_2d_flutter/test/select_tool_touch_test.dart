// Spec 14t T4, R-3, R-4: finger-sized targets in the select tool -- the
// two-stage pick (precise first, the reach on a miss), the touch slop, and
// grips against the rotation grip by distance. Driven event by event, as
// `InteractionLayer` would after the hold-back. Cameras are off the origin
// at scale 2 or 1.1, y up.
import 'dart:ui' show Offset, PointerDeviceKind;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart'
    show kTouchGripHitPixels;
import 'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart'
    show kPickRadiusPixels, kTouchPickRadiusPixels;
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/grip_fixture.dart' hide screenOf;
import 'support/selection_fixture.dart';

/// A sample as the layer builds it: a finger reaches 24 px, a mouse 6.
ToolPointerEvent ev(CameraController camera, Offset screen,
    {required bool touch, int buttons = kPrimaryButton}) {
  final scale = camera.value.scale;
  return ToolPointerEvent(
    screen: screen,
    world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
    pointer: 1,
    buttons: buttons,
    shift: false,
    control: false,
    meta: false,
    alt: false,
    pickRadiusWorld: kPickRadiusPixels / scale,
    kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
    reachRadiusWorld: touch ? kTouchPickRadiusPixels / scale : null,
  );
}

/// World y = 500 lands on screen y = 300; x 900..1100 on 200..600, so a tap
/// at x 400 is 100 px from any endpoint (a vertex outranks an edge).
CameraController lineCamera() => cameraAt(2.0, const Offset(-1600, 1300));

final class Scene {
  Scene() : document = DraftDocument.empty() {
    index = SpatialIndex(document);
    selection = SelectionController(document);
    camera = lineCamera();
    ctx = ToolContext(
        document: document, index: index, camera: camera, selection: selection);
  }

  final DraftDocument document;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final CameraController camera;
  late final ToolContext ctx;
  final SelectTool tool = SelectTool();

  Handle line(double y) => addEntity(
      document, document.rootHandle, EntityKind.line, [900, y, 1100, y], []);

  void tap(Offset at, {required bool touch}) {
    tool.onPointerDown(ev(camera, at, touch: touch), ctx);
    tool.onPointerUp(ev(camera, at, touch: touch, buttons: 0), ctx);
  }

  void dispose() {
    selection.dispose();
    index.dispose();
    camera.dispose();
  }
}

Scene scene() {
  final s = Scene();
  addTearDown(s.dispose);
  return s;
}

void main() {
  test(
      'TT1 a finger 20 px from a line picks it; a mouse there does not '
      '(M-14t-11)', () {
    final s = scene();
    final line = s.line(500);
    s.tap(const Offset(400, 320), touch: false);
    expect(s.selection.isEmpty, isTrue);
    s.tap(const Offset(400, 320), touch: true);
    expect(s.selection.keys, {SelectionKey.root(line)});
  });

  test(
      'TT2 a finger on an earlier line picks it over a later line 15 px '
      'away (R-3, M-14t-18)', () {
    final s = scene();
    final under = s.line(500);
    final later = s.line(492.5); // screen y 315
    expect(later.value, greaterThan(under.value));
    s.tap(const Offset(400, 300), touch: true);
    expect(s.selection.keys, {SelectionKey.root(under)});
    s.tap(const Offset(400, 316), touch: true);
    expect(s.selection.keys, {SelectionKey.root(later)});
  });

  test(
      'TT3 a finger that jitters 10 px is still a click; a mouse moved 10 px '
      'drags (M-14t-12)', () {
    final s = scene();
    final line = s.line(500);
    final depth = s.document.commands.undoDepth;
    final t = s.tool;
    t.onPointerDown(ev(s.camera, const Offset(400, 300), touch: true), s.ctx);
    t.onPointerMove(ev(s.camera, const Offset(408, 306), touch: true), s.ctx);
    expect(t.phase, ToolPhase.pressed);
    t.onPointerUp(
        ev(s.camera, const Offset(408, 306), touch: true, buttons: 0), s.ctx);
    expect(s.selection.keys, {SelectionKey.root(line)});
    expect(s.document.commands.undoDepth, depth, reason: 'no move');

    s.selection.clear();
    t.onPointerDown(ev(s.camera, const Offset(400, 300), touch: false), s.ctx);
    t.onPointerMove(ev(s.camera, const Offset(408, 306), touch: false), s.ctx);
    expect(t.phase, ToolPhase.dragging);
    t.cancel(s.ctx);
  });

  group('grips by distance on touch (R-4)', () {
    // A circle alone, selected, under the fixture's rotated camera (0.35
    // rad, scale 1.1, y up, off the origin). The rotation grip is found from
    // the cache's own distance query (three samples locate a point from its
    // distances); the grips are the cache's, through the camera.
    late GripRig rig;
    late Offset rotation, centre;
    late List<Offset> grips;

    setUp(() {
      final doc = DraftDocument.empty();
      addEntity(doc, doc.rootHandle, EntityKind.circle, [7300, 3250], [10]);
      rig = GripRig(doc);
      rig.selection.replace([
        SelectionKey.root(doc.entities.handleAt(doc.entities.liveSlots.first))
      ]);
      final cam = rig.camera.value;
      Offset s(double x, double y) {
        final p = cam.worldToScreen(Vector2(x, y));
        return Offset(p.x, p.y);
      }

      centre = s(7300, 3250);
      grips = [for (final g in rig.grips.grips) s(g.grip.x, g.grip.y)];
      final m = cam.worldToScreenMatrix;
      double d2(Offset p) {
        final d = rig.grips.rotationGripDistance(p, m);
        return d * d;
      }

      const p0 = Offset(100, 100);
      final d0 = d2(p0);
      rotation = Offset(p0.dx - (d2(p0 + const Offset(1, 0)) - d0 - 1) / 2,
          p0.dy - (d2(p0 + const Offset(0, 1)) - d0 - 1) / 2);
    });
    tearDown(() => rig.dispose());

    DragKind? pressAndDrag(Offset at, {required bool touch}) {
      rig.tool.onPointerDown(ev(rig.camera, at, touch: touch), rig.context);
      rig.tool.onPointerMove(
          ev(rig.camera, at + const Offset(40, 25), touch: touch), rig.context);
      final kind = rig.tool.dragKind;
      rig.tool.cancel(rig.context);
      return kind;
    }

    test(
        'TT4 a finger nearer a grip than the rotation grip reshapes; nearer '
        'the rotation grip it rotates (M-14t-19, review F-4)', () {
      final m = rig.camera.value.worldToScreenMatrix;
      expect(rig.grips.rotationGripDistance(rotation, m), closeTo(0, 1e-6),
          reason: 'premise: the rotation grip located');
      // The grip nearest the rotation grip, a quadrant.
      final g = grips.reduce(
          (a, b) => (a - rotation).distance <= (b - rotation).distance ? a : b);
      final gap = (rotation - g).distance;
      expect(gap, lessThan(kTouchGripHitPixels + 8),
          reason: 'premise: the two compete for a finger');
      final towards = (rotation - g) / gap;
      final nearGrip = g + towards * 8;
      expect((nearGrip - rotation).distance,
          lessThanOrEqualTo(kTouchGripHitPixels),
          reason: 'premise: the rotation grip is within reach too');
      expect(pressAndDrag(nearGrip, touch: true), DragKind.reshape);
      final nearRotation = rotation - towards * 6;
      expect(pressAndDrag(nearRotation, touch: true), DragKind.rotate);
    });

    test(
        'TT5 a finger 20 px from a grip takes it; a mouse there does not '
        '(M-14t-13)', () {
      // The grip farthest from the rotation grip, pressed 20 px outward.
      final g = grips.reduce(
          (a, b) => (a - rotation).distance >= (b - rotation).distance ? a : b);
      final out = (g - centre) / (g - centre).distance;
      final at = g + out * 20;
      expect((at - rotation).distance, greaterThan(kTouchGripHitPixels),
          reason: 'premise: away from the rotation grip');
      expect(pressAndDrag(at, touch: true), DragKind.reshape);
      expect(pressAndDrag(at, touch: false), isNot(DragKind.reshape));
    });
  });
}
