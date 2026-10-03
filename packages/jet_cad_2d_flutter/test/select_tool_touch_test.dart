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
    // A circle alone, selected: its top quadrant grip is the box's top
    // centre, and the rotation grip 24 px above it. An unrotated camera, so
    // "above" is screen up.
    late GripRig rig;
    late Handle circle;
    late Offset top, right;

    setUp(() {
      final doc = DraftDocument.empty();
      circle =
          addEntity(doc, doc.rootHandle, EntityKind.circle, [7300, 3250], [25]);
      rig = GripRig(doc, camera: gripCamera(rotation: 0));
      rig.selection.replace([SelectionKey.root(circle)]);
      final m = rig.camera.value;
      Offset s(double x, double y) {
        final p = m.worldToScreen(Vector2(x, y));
        return Offset(p.x, p.y);
      }

      top = s(7300, 3275);
      right = s(7325, 3250);
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
        'TT4 a finger on the top quadrant grip reshapes; it does not rotate '
        '(M-14t-19)', () {
      final m = rig.camera.value.worldToScreenMatrix;
      expect(rig.grips.rotationGripDistance(top, m),
          lessThanOrEqualTo(kTouchGripHitPixels),
          reason: 'premise: the rotation grip is within a finger\'s reach');
      expect(pressAndDrag(top, touch: true), DragKind.reshape);
      expect(pressAndDrag(top + const Offset(0, -14), touch: true),
          DragKind.rotate,
          reason: '10 px from the rotation grip, 14 from the quadrant');
    });

    test(
        'TT5 a finger 20 px from a grip takes it; a mouse there does not '
        '(M-14t-13)', () {
      final at = right + const Offset(20, 0);
      expect(pressAndDrag(at, touch: true), DragKind.reshape);
      expect(pressAndDrag(at, touch: false), isNot(DragKind.reshape));
    });
  });
}
