import 'dart:ui' show Rect, Size;

import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;
import '../support/spy_canvas.dart';

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The newest entity's handle: the tools allocate ascending.
Handle newest(DraftDocument doc) =>
    doc.entities.handleAt(doc.entities.liveSlots.reduce((a, b) =>
        doc.entities.handleAt(a).value > doc.entities.handleAt(b).value
            ? a
            : b));

void main() {
  for (final flipY in const [true, false]) {
    group('flipY $flipY', () {
      test('B1 a point is the layer\'s world point, not the screen (M-05a)',
          () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        final a = screenOf(rig.camera, 7010.5, 3020.25);
        final b = screenOf(rig.camera, 7090.75, 3070.5);
        clickAt(rig, a);
        clickAt(rig, b);
        final p = payloadOf(s.document, newest(s.document));
        final wa = worldAt(rig, a), wb = worldAt(rig, b);
        expect(p.coords.toList(), [wa.x, wa.y, wb.x, wb.y],
            reason: 'exact: the stored values are the resolved points');
      });

      test(
          'B2 a line started near an endpoint begins exactly on it '
          '(exit criterion 3)', () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        clickAt(rig,
            screenOf(rig.camera, kAnchorX, kAnchorY) + const Offset(3, -2));
        clickAt(rig, screenOf(rig.camera, 7050, 3050));
        final p = payloadOf(s.document, newest(s.document));
        expect(p.coords[0], kAnchorX);
        expect(p.coords[1], kAnchorY);
      });

      test(
          'B3 the hover marker is drawn at the snapped point, and nothing '
          'when the raw point wins', () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        final at = screenOf(rig.camera, kAnchorX, kAnchorY);
        hoverAt(rig, at + const Offset(2, 2));
        final spy = SpyCanvas();
        rig.tool.paintOverlay(spy, rig.camera.value, const Size(800, 600));
        final squares = spy.named('drawRect').toList();
        expect(squares, hasLength(1), reason: 'an endpoint: a square');
        final r = squares.single.args[0] as Rect;
        expect(r.center.dx, closeTo(at.dx, 1e-6));
        expect(r.center.dy, closeTo(at.dy, 1e-6));
        hoverAt(rig, screenOf(rig.camera, 7050, 3050));
        final none = SpyCanvas();
        rig.tool.paintOverlay(none, rig.camera.value, const Size(800, 600));
        expect(none.calls, isEmpty, reason: 'grid off, nothing hit');
      });
    });
  }

  test(
      'B4 Escape mid-shape is byte-identical; an idle Escape is ignored '
      '(M-05m)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    expect(rig.tool.isPending, isTrue);
    expect(keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
        KeyEventResult.handled);
    expect(rig.tool.isPending, isFalse);
    expect(snapshot(s.document), before);
    expect(keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
        KeyEventResult.ignored,
        reason: 'idle: it bubbles to the shell, which returns to Select');
  });

  test('B5 undo keys are swallowed mid-shape and pass through when idle', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    expect(keyDown(rig, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
        KeyEventResult.ignored);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    expect(keyDown(rig, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
        KeyEventResult.handled);
    expect(
        rig.tool.onKey(
            const KeyUpEvent(
                physicalKey: PhysicalKeyboardKey.keyZ,
                logicalKey: LogicalKeyboardKey.keyZ,
                timeStamp: Duration.zero),
            rig.context),
        KeyEventResult.ignored);
  });

  test(
      'B6 a pan mid-shape re-resolves the hover, and the next click lands '
      'at the new camera\'s point (Review Focus 3)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    final screen = screenOf(rig.camera, 7060, 3040);
    hoverAt(rig, screen);
    final before = Vector2.copy(rig.tool.hoverPoint);
    var notified = 0;
    rig.tool.addListener(() => notified++);
    rig.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(37, -21)
            .multiply(rig.camera.value.worldToScreenMatrix));
    expect(notified, greaterThan(0), reason: 'the camera listener fired');
    expect(rig.tool.hoverPoint, isNot(before));
    final w = worldAt(rig, screen);
    expect(rig.tool.hoverPoint.x, w.x,
        reason: 'the re-resolved hover is exactly the new camera\'s world '
            'point, not merely different from the stale one (a screen-as-'
            'world mutant in _reresolve would still satisfy isNot(before))');
    expect(rig.tool.hoverPoint.y, w.y);
    downAt(rig, screen);
    final p = payloadOf(s.document, newest(s.document));
    expect(p.coords[2], w.x);
    expect(p.coords[3], w.y);
  });

  test(
      'B7 shift pins the ortho axis from the last point, and a shift press '
      're-resolves at once', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010.5, 3020.25));
    final first = Vector2.copy(rig.tool.points.last);
    final hoverScreen = screenOf(rig.camera, 7090, 3031);
    hoverAt(rig, hoverScreen);
    expect(rig.tool.hoverPoint.y, isNot(first.y));
    rig.tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            logicalKey: LogicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero),
        rig.context);
    expect(rig.tool.hoverPoint.y, first.y,
        reason: '|dx| > |dy|: y pinned to the base, exactly');
    final w = worldAt(rig, hoverScreen);
    expect(rig.tool.hoverPoint.x, w.x,
        reason: 'only y is pinned; x stays the raw resolved value, exact '
            '(a screen-as-world mutant in _reresolve would move x too)');
  });

  test('B8 a denied commit drops the shape and allocates no handle', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    s.document.commands.permissions = DraftPermissions.runtime;
    final seed = s.document.handleSeed.current;
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7090, 3050));
    expect(snapshot(s.document), before);
    expect(s.document.handleSeed.current, seed);
    expect(rig.tool.isPending, isFalse);
  });

  test(
      'B9 a tool switch mid-shape is byte-identical and detaches the '
      'camera; a pointer exit keeps the shape', () {
    final s = drawScene();
    final line = LineTool();
    final rig = drawRig(s.document, line);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    rig.tool.onPointerExit(rig.context);
    expect(line.isPending, isTrue, reason: 'click by click, not a drag');
    expect(line.hoverVisible, isFalse);
    final before = snapshot(s.document);
    rig.tools.activate(SelectTool());
    expect(line.isPending, isFalse);
    expect(snapshot(s.document), before);
    var notified = 0;
    line.addListener(() => notified++);
    rig.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(5, 5)
            .multiply(rig.camera.value.worldToScreenMatrix));
    expect(notified, 0, reason: 'the camera listener is detached');
  });
}
