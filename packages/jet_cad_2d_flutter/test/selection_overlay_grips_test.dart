import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Paint, Path, PointMode, Rect, Size, StrokeCap;

import 'package:flutter/widgets.dart' show Listenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart'
    show rebaseOriginFor;
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';
import 'support/spy_canvas.dart';

const Size kView = Size(800, 600);

SelectionKey k(Handle h) => SelectionKey.root(h);

SelectionOverlayPainter overlayOf(GripRig rig) => SelectionOverlayPainter(
      selection: rig.selection,
      tools: rig.tools,
      camera: rig.camera,
      outlines: rig.outlines,
      repaint: Listenable.merge(
          [rig.selection, rig.tools, rig.camera, rig.outlines, rig.grips]),
    );

/// `(x, y)` mapped through a recorded column-major 4x4.
Offset through(Float64List m, double x, double y) =>
    Offset(m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13]);

Offset rotationGripCentre(GripRig rig) =>
    rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix).centre;

// `Paint.color` reads back through float32, so a colour is compared by
// `toARGB32()`, never `==` (the idiom `selection_overlay_test.dart` uses).
void main() {
  test(
      'the move/rotate preview is drawn through worldToScreen ∘ T ∘ '
      'translate(origin) (M-03u)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final grip = rotationGripCentre(rig);
    pressAndMove(rig, grip, grip + const Offset(-45, 38));
    final t = rig.tool.selectionPreviewTransform!;
    expect(t.b.abs(), greaterThan(1e-3),
        reason: 'a rotation: a translation commutes with the rebase and '
            'could not tell the two orders apart');
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final origin = rebaseOriginFor(rig.camera.value.visibleWorld(kView));
    expect(origin.x, isNot(0.0), reason: 'the rebase origin is non-zero');
    final transforms = spy.named('transform').toList();
    expect(transforms, hasLength(2),
        reason: 'the outline pass, then the preview pass');
    final preview = Float64List.fromList(transforms[1].args[0] as Float64List);
    for (final (x, y) in const [(7010.0, 3020.0), (7130.0, 3060.0)]) {
      final expected =
          rig.camera.value.worldToScreen(t.transformPoint(Vector2(x, y)));
      final got = through(preview, x - origin.x, y - origin.y);
      expect(got.dx, closeTo(expected.x, 1e-6));
      expect(got.dy, closeTo(expected.y, 1e-6));
    }
    expect(
        spy
            .named('drawPath')
            .where((c) => c.color?.toARGB32() == kPreviewColor.toARGB32()),
        hasLength(1));
  });

  test(
      'grips are one drawRawPoints per colour at 10 grips and at 300, and '
      'the hot grip one more (invariant 6, M-03v, M-03aq)', () {
    (List<RecordedCall>, GripRig) frame(int vertices, {int hot = -1}) {
      final doc = DraftDocument.empty();
      final poly = addEntity(doc, doc.rootHandle, EntityKind.polyline, [
        for (var i = 0; i < vertices; i++) ...[
          7000.0 + i * 0.5,
          i.isEven ? 3000.0 : 3002.0
        ],
      ], []);
      final circle =
          addEntity(doc, doc.rootHandle, EntityKind.circle, [7060, 3030], [8]);
      final rig = gripRig(doc, camera: gripCamera(centre: Vector2(7050, 3010)));
      rig.selection.replace([k(poly), k(circle)]);
      rig.grips.hot = hot;
      final spy = SpyCanvas();
      overlayOf(rig).paint(spy, kView);
      return (spy.calls, rig);
    }

    List<String> names(List<RecordedCall> calls) =>
        [for (final c in calls) c.name];
    final (small, _) = frame(5); // 5 vertices + 5 circle grips = 10
    final (large, _) = frame(295); // 295 + 5 = 300
    expect(names(large), names(small),
        reason: 'the draw calls do not depend on the grip count');
    expect(names(large), isNot(contains('drawRect')));
    final raw = [
      for (final c in large)
        if (c.name == 'drawRawPoints') c,
    ];
    expect(raw, hasLength(2));
    expect(raw[0].args[0], PointMode.points);
    expect((raw[0].args[1] as Float32List).length, 2 * 299,
        reason: 'the stretch and radius grips');
    expect(raw[0].color?.toARGB32(), kGripColor.toARGB32());
    expect(raw[0].strokeWidth, kGripPixels);
    expect((raw[0].args[2] as Paint).strokeCap, StrokeCap.square);
    expect((raw[1].args[1] as Float32List).length, 2, reason: 'one centre');
    expect(raw[1].color?.toARGB32(), kGripMoveColor.toARGB32());

    final (hot, rig) = frame(5, hot: 2);
    final hotCalls = [
      for (final c in hot)
        if (c.name == 'drawRawPoints') c,
    ];
    expect(hotCalls, hasLength(3));
    expect(hotCalls[2].color?.toARGB32(), kGripHotColor.toARGB32());
    final pts = hotCalls[2].args[1] as Float32List;
    final third = screenOf(rig.camera, 7001, 3000); // the polyline's vertex 2
    expect(pts[0], closeTo(third.dx, 1e-3));
    expect(pts[1], closeTo(third.dy, 1e-3));
  });

  test(
      'the stretch buffer is reallocated only when the count changes, and '
      "never draws a stale grip (Ruling 03-10; M-03bf, M-03bf')", () {
    final doc = DraftDocument.empty();
    List<double> zigzag(int n) => [
          for (var i = 0; i < n; i++) ...[
            7000.0 + i * 0.5,
            i.isEven ? 3000.0 : 3002.0,
          ],
        ];
    final big =
        addEntity(doc, doc.rootHandle, EntityKind.polyline, zigzag(300), []);
    final small =
        addEntity(doc, doc.rootHandle, EntityKind.polyline, zigzag(10), []);
    final rig = gripRig(doc, camera: gripCamera(centre: Vector2(7050, 3010)));
    rig.selection.replace([k(big)]);
    // ONE painter instance across every frame: the buffer field lives on
    // the painter, not on GripCache.
    final painter = overlayOf(rig);

    Float32List stretchOf(SpyCanvas spy) {
      final raw = [
        for (final c in spy.calls)
          if (c.name == 'drawRawPoints') c,
      ];
      return raw[0].args[1] as Float32List;
    }

    final spy1 = SpyCanvas();
    painter.paint(spy1, kView);
    final first = stretchOf(spy1);
    expect(first.length, 2 * 300);

    rig.selection.replace([k(small)]);
    final spy2 = SpyCanvas();
    painter.paint(spy2, kView);
    final second = stretchOf(spy2);
    expect(second.length, 2 * 10,
        reason: 'the buffer must shrink to the new count, not keep drawing '
            "300 grips' worth of stale points (M-03bf')");

    final spy3 = SpyCanvas();
    painter.paint(spy3, kView);
    final third = stretchOf(spy3);
    expect(identical(second, third), isTrue,
        reason: 'the count did not change between these two frames: the '
            'same Float32List instance is reused, not reallocated (M-03bf)');
  });

  test(
      'no leaf grips are drawn under a geometry denial; the rotation grip '
      'still is (M-03ad)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.circle)]);
    s.document.commands.permissions = DraftPermissions.runtime;
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    expect(spy.named('drawRawPoints'), isEmpty);
    expect(spy.named('drawCircle'), hasLength(1), reason: 'the rotation grip');
  });

  test("a selected point's preview cross sits at T(p) (M-03ae)", () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.point), k(s.line)]);
    final grip = rotationGripCentre(rig);
    pressAndMove(rig, grip, grip + const Offset(-60, 30));
    final t = rig.tool.selectionPreviewTransform!;
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    // The cross's arms are 6 · kSelectionStrokePixels = 12 px long; the
    // guide line in the same colour is not.
    final arms = [
      for (final c in spy.named('drawLine'))
        if (c.color?.toARGB32() == kPreviewColor.toARGB32() &&
            (((c.args[1] as Offset) - (c.args[0] as Offset)).distance - 12)
                    .abs() <
                1e-6)
          c,
    ];
    expect(arms, hasLength(2));
    final moved =
        rig.camera.value.worldToScreen(t.transformPoint(Vector2(7250, 3300)));
    for (final arm in arms) {
      final mid = ((arm.args[0] as Offset) + (arm.args[1] as Offset)) / 2;
      expect(mid.dx, closeTo(moved.x, 1e-6));
      expect(mid.dy, closeTo(moved.y, 1e-6));
    }
  });

  test(
      'the reshape preview is a rebased path under the world matrix '
      '(M-03aj)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    final to = vertex + const Offset(25, -18);
    pressAndMove(rig, vertex, to);
    expect(rig.tool.dragKind, DragKind.reshape);
    final target = rig.camera.value.screenToWorld(Vector2(to.dx, to.dy));
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final origin = rebaseOriginFor(rig.camera.value.visibleWorld(kView));
    final names = [for (final c in spy.calls) c.name];
    final at = spy.calls.indexWhere((c) =>
        c.name == 'drawPath' &&
        c.color?.toARGB32() == kPreviewColor.toARGB32());
    expect(at, greaterThan(names.indexOf('transform')));
    expect(at, lessThan(names.indexOf('restore')),
        reason: 'drawn under the rebased world matrix');
    final bounds = (spy.calls[at].args[0] as Path).getBounds();
    expect(bounds.left, closeTo(7010 - origin.x, 1e-3));
    expect(bounds.right, closeTo(target.x - origin.x, 1e-3));
    expect(bounds.top, closeTo(math.min(3020, target.y) - origin.y, 1e-3));
    expect(bounds.bottom, closeTo(math.max(3020, target.y) - origin.y, 1e-3));
    // `Paint.strokeWidth` is stored as float32: the expected width is
    // narrowed the same way, and then compared exactly.
    expect(
        spy.calls[at].strokeWidth,
        Float32List.fromList(
            [kPreviewStrokePixels / rig.camera.value.scale])[0]);
  });

  test(
      'a stretch draws its guide and the snap marker at the resolved '
      'target (spec D7, D9, M-03ar)', () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    final endpoint = screenOf(rig.camera, 7130, 3100);
    final drop = endpoint + const Offset(3, -2);
    pressAndMove(rig, vertex, drop);
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final markers = [
      for (final c in spy.named('drawRect'))
        if (c.color?.toARGB32() == kSnapMarkerColor.toARGB32()) c,
    ];
    expect(markers, hasLength(1), reason: 'an endpoint won: a square');
    final r = markers.single.args[0] as Rect;
    expect(r.center.dx, closeTo(endpoint.dx, 1e-6));
    expect(r.center.dy, closeTo(endpoint.dy, 1e-6));
    expect(r.width, kSnapMarkerPixels);
    final guide = spy
        .named('drawLine')
        .where((c) => c.color?.toARGB32() == kPreviewColor.toARGB32());
    expect(guide, hasLength(1));
    expect((guide.single.args[0] as Offset).dx, closeTo(vertex.dx, 1e-6));
    expect((guide.single.args[1] as Offset).dx, closeTo(endpoint.dx, 1e-6));
  });
}
