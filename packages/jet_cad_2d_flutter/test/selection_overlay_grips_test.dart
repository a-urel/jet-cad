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
    // The flipped camera's `b == c` hides an `m.b`/`m.c` transposition in
    // either composition, so the unflipped one runs too.
    for (final flipY in const [true, false]) {
      final s = gripScene();
      final rig = gripRig(s.document, camera: gripCamera(flipY: flipY));
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
      final outline =
          Float64List.fromList(transforms[0].args[0] as Float64List);
      final preview =
          Float64List.fromList(transforms[1].args[0] as Float64List);
      for (final (x, y) in const [(7010.0, 3020.0), (7130.0, 3060.0)]) {
        final still = rig.camera.value.worldToScreen(Vector2(x, y));
        final kept = through(outline, x - origin.x, y - origin.y);
        expect(kept.dx, closeTo(still.x, 1e-6), reason: 'flipY $flipY');
        expect(kept.dy, closeTo(still.y, 1e-6), reason: 'flipY $flipY');
        final expected =
            rig.camera.value.worldToScreen(t.transformPoint(Vector2(x, y)));
        final got = through(preview, x - origin.x, y - origin.y);
        expect(got.dx, closeTo(expected.x, 1e-6), reason: 'flipY $flipY');
        expect(got.dy, closeTo(expected.y, 1e-6), reason: 'flipY $flipY');
      }
      expect(
          spy
              .named('drawPath')
              .where((c) => c.color?.toARGB32() == kPreviewColor.toARGB32()),
          hasLength(1));
    }
  });

  test(
      'grips are one drawRawPoints per colour at 10 grips and at 300, and '
      'the hot grip one more, each at its grip (invariant 6, M-03v, M-03aq, '
      'M-03bh)', () {
    (List<RecordedCall>, GripRig) frame(int vertices,
        {int hot = -1, bool flipY = true}) {
      final doc = DraftDocument.empty();
      final poly = addEntity(doc, doc.rootHandle, EntityKind.polyline, [
        for (var i = 0; i < vertices; i++) ...[
          7000.0 + i * 0.5,
          i.isEven ? 3000.0 : 3002.0
        ],
      ], []);
      final circle =
          addEntity(doc, doc.rootHandle, EntityKind.circle, [7060, 3030], [8]);
      final rig = gripRig(doc,
          camera: gripCamera(centre: Vector2(7050, 3010), flipY: flipY));
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

    for (final flipY in const [true, false]) {
      final (hot, rig) = frame(5, hot: 2, flipY: flipY);
      final hotCalls = [
        for (final c in hot)
          if (c.name == 'drawRawPoints') c,
      ];
      expect(hotCalls, hasLength(3));
      expect(hotCalls[2].color?.toARGB32(), kGripHotColor.toARGB32());
      final pts = hotCalls[2].args[1] as Float32List;
      final third = screenOf(rig.camera, 7001, 3000); // polyline vertex 2
      expect(pts[0], closeTo(third.dx, 1e-3), reason: 'flipY $flipY');
      expect(pts[1], closeTo(third.dy, 1e-3), reason: 'flipY $flipY');
    }

    // Every drawn pair is its grip's screen point — the point
    // `GripCache.hitTest` hits, projected by a separate expression (M-03bh).
    // The stretch and radius grips in list order, then the centres. The
    // flipped camera's `b == c` hides an `m.b`/`m.c` transposition, so the
    // unflipped one is checked too. Float32, so 1e-3 px.
    for (final flipY in const [true, false]) {
      final (calls, at) = frame(5, flipY: flipY);
      final raw = [
        for (final c in calls)
          if (c.name == 'drawRawPoints') c,
      ];
      final drawn = [
        ...raw[0].args[1] as Float32List,
        ...raw[1].args[1] as Float32List,
      ];
      final list = at.grips.grips;
      final want = [
        for (final r in list)
          if (r.grip.role != GripRole.move) r.grip,
        for (final r in list)
          if (r.grip.role == GripRole.move) r.grip,
      ];
      expect(want, hasLength(10));
      expect(drawn, hasLength(2 * want.length));
      for (var i = 0; i < want.length; i++) {
        final p = screenOf(at.camera, want[i].x, want[i].y);
        expect(drawn[2 * i], closeTo(p.dx, 1e-3),
            reason: 'flipY $flipY, grip $i, x');
        expect(drawn[2 * i + 1], closeTo(p.dy, 1e-3),
            reason: 'flipY $flipY, grip $i, y');
      }
    }
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
      'still is, at its centre (M-03ad, M-03bi)', () {
    // The oracle projects the box's corners through `screenOf`, not through
    // `rotationGripOf`: a self-referential oracle would move with a defect
    // in it. The unflipped camera exposes an `m.b`/`m.c` transposition that
    // the flipped one's `b == c` hides.
    for (final flipY in const [true, false]) {
      final s = gripScene();
      final rig = gripRig(s.document, camera: gripCamera(flipY: flipY));
      rig.selection.replace([k(s.line), k(s.circle)]);
      s.document.commands.permissions = DraftPermissions.runtime;
      final spy = SpyCanvas();
      overlayOf(rig).paint(spy, kView);
      expect(spy.named('drawRawPoints'), isEmpty);
      expect(spy.named('drawCircle'), hasLength(1),
          reason: 'the rotation grip');
      // The disc is drawn where `hitsRotationGrip` hits it (spec D6): an
      // 8 px disc, 24 px above the screen box's top-centre (M-03bi).
      final box = rig.grips.box!;
      final corners = [
        for (final (x, y) in [
          (box.minX, box.minY),
          (box.maxX, box.minY),
          (box.minX, box.maxY),
          (box.maxX, box.maxY),
        ])
          screenOf(rig.camera, x, y),
      ];
      final minX = corners.map((c) => c.dx).reduce(math.min);
      final maxX = corners.map((c) => c.dx).reduce(math.max);
      final minY = corners.map((c) => c.dy).reduce(math.min);
      final disc = spy.named('drawCircle').single;
      expect((disc.args[0] as Offset).dx, closeTo((minX + maxX) / 2, 1e-9),
          reason: 'flipY $flipY');
      expect((disc.args[0] as Offset).dy,
          closeTo(minY - kRotationGripOffset, 1e-9),
          reason: 'flipY $flipY');
      expect(disc.args[1], 4.0, reason: 'an 8 px diameter');
    }
  });

  test("a selected point's preview cross sits at T(p) (M-03ae)", () {
    // The unflipped camera exposes an `m.b`/`m.c` transposition in the
    // cross's projection that the flipped one's `b == c` hides.
    for (final flipY in const [true, false]) {
      final s = gripScene();
      final rig = gripRig(s.document, camera: gripCamera(flipY: flipY));
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
      expect(arms, hasLength(2), reason: 'flipY $flipY');
      final moved =
          rig.camera.value.worldToScreen(t.transformPoint(Vector2(7250, 3300)));
      for (final arm in arms) {
        final mid = ((arm.args[0] as Offset) + (arm.args[1] as Offset)) / 2;
        expect(mid.dx, closeTo(moved.x, 1e-6), reason: 'flipY $flipY');
        expect(mid.dy, closeTo(moved.y, 1e-6), reason: 'flipY $flipY');
      }
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
      "an arc reshape preview's radius grip is rebased by origin too "
      '(M-03bg)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.arcPos)]);
    final radiusGrip =
        leafGrips(EntityKind.arc, payloadOf(rig.document, s.arcPos))[3];
    final press = screenOf(rig.camera, radiusGrip.x, radiusGrip.y);
    final to = press + const Offset(22, -6);
    pressAndMove(rig, press, to);
    expect(rig.tool.dragKind, DragKind.reshape);
    // No snap and no ortho are active (a plain move, shift not held), so
    // the resolved target is the raw world point under `to`.
    final target = rig.camera.value.screenToWorld(Vector2(to.dx, to.dy));
    final centre = Vector2(7050, 3200); // arcPos's stored centre (Ruling)
    final newRadius = (target - centre).length;
    const start = 0.3; // arcPos's stored start angle, unchanged by radius

    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final origin = rebaseOriginFor(rig.camera.value.visibleWorld(kView));
    final drawn = spy
        .named('drawPath')
        .where((c) => c.color?.toARGB32() == kPreviewColor.toARGB32())
        .toList();
    expect(drawn, hasLength(1));
    final path = drawn.single.args[0] as Path;
    // `Path.addArc`'s first point is exactly the arc's start point: an
    // exact check of the origin subtraction, not an approximate one —
    // `Path.getBounds()` answers the conic *control-point* bounds, which
    // for a partial sweep lie outside the curve (see `outline_cache.dart`'s
    // own note on this), so it cannot pin the centre to the tight tolerance
    // an origin-drop bug — off by the origin's whole magnitude — needs.
    final startPoint =
        path.computeMetrics().single.getTangentForOffset(0)!.position;
    final expected = Offset(
      centre.x - origin.x + newRadius * math.cos(start),
      centre.y - origin.y + newRadius * math.sin(start),
    );
    expect(startPoint.dx, closeTo(expected.dx, 1e-3));
    expect(startPoint.dy, closeTo(expected.dy, 1e-3));
  });

  test(
      "a circle reshape preview's centre is rebased by origin too "
      '(M-03bj)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.circle)]);
    final radiusGrip =
        leafGrips(EntityKind.circle, payloadOf(rig.document, s.circle))[1];
    expect(radiusGrip.role, GripRole.radius);
    final press = screenOf(rig.camera, radiusGrip.x, radiusGrip.y);
    final to = press + const Offset(22, -6);
    pressAndMove(rig, press, to);
    expect(rig.tool.dragKind, DragKind.reshape);
    // No snap and no ortho are active, so the target is the raw world
    // point under `to`.
    final target = rig.camera.value.screenToWorld(Vector2(to.dx, to.dy));
    final centre = Vector2(7300, 3250); // the circle's stored centre
    final newRadius = (target - centre).length;
    expect((newRadius - 25).abs(), greaterThan(1),
        reason: 'the radius really changed');

    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final origin = rebaseOriginFor(rig.camera.value.visibleWorld(kView));
    expect(origin.x, isNot(0.0));
    final drawn = spy
        .named('drawPath')
        .where((c) => c.color?.toARGB32() == kPreviewColor.toARGB32())
        .toList();
    expect(drawn, hasLength(1));
    // A full oval's bounds are tight: its conic control points lie on the
    // bounding square.
    final bounds = (drawn.single.args[0] as Path).getBounds();
    expect(bounds.center.dx, closeTo(centre.x - origin.x, 1e-3));
    expect(bounds.center.dy, closeTo(centre.y - origin.y, 1e-3));
    expect(bounds.width, closeTo(2 * newRadius, 1e-3));
    expect(bounds.height, closeTo(2 * newRadius, 1e-3));
  });

  test(
      'a stretch draws its guide and the snap marker at the resolved '
      'target (spec D7, D9, M-03ar)', () {
    // The unflipped camera exposes an `m.b`/`m.c` transposition in the
    // guide's projection that the flipped one's `b == c` hides.
    for (final flipY in const [true, false]) {
      final s = gripScene();
      final rig = gripRig(s.document,
          camera: gripCamera(flipY: flipY), objectSnap: true);
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
      expect(r.center.dx, closeTo(endpoint.dx, 1e-6), reason: 'flipY $flipY');
      expect(r.center.dy, closeTo(endpoint.dy, 1e-6), reason: 'flipY $flipY');
      expect(r.width, kSnapMarkerPixels);
      final guide = spy
          .named('drawLine')
          .where((c) => c.color?.toARGB32() == kPreviewColor.toARGB32());
      expect(guide, hasLength(1));
      expect((guide.single.args[0] as Offset).dx, closeTo(vertex.dx, 1e-6),
          reason: 'flipY $flipY');
      expect((guide.single.args[1] as Offset).dx, closeTo(endpoint.dx, 1e-6),
          reason: 'flipY $flipY');
    }
  });

  test(
      'during a rotate the grip and its stem turn with the preview '
      '(M-RFi, M-RFj, M-RFm)', () {
    // The oracle is `orientedGripOracle`, world points through `screenOf`;
    // the unflipped camera exposes an `m.b`/`m.c` transposition.
    for (final flipY in const [true, false]) {
      final (doc, h) = triangleDoc();
      final rig = gripRig(doc, camera: gripCamera(flipY: flipY));
      rig.selection.replace([k(h)]);
      final grip = rotationGripNow(rig);
      pressAndMove(rig, grip, grip + const Offset(-45, 38));
      final t = rig.tool.selectionPreviewTransform!;
      expect(t.b.abs(), greaterThan(1e-3), reason: 'a rotation');
      final spy = SpyCanvas();
      overlayOf(rig).paint(spy, kView);
      final want = orientedGripOracle(rig.camera, rig.grips.box!, t);
      final disc = spy.named('drawCircle').single.args[0] as Offset;
      expect(disc.dx, closeTo(want.centre.dx, 1e-9), reason: 'flipY $flipY');
      expect(disc.dy, closeTo(want.centre.dy, 1e-9), reason: 'flipY $flipY');
      final stems = [
        for (final c in spy.named('drawLine'))
          if (((c.args[0] as Offset) - want.anchor).distance < 1e-6) c,
      ];
      expect(stems, hasLength(1), reason: 'flipY $flipY');
      final end = stems.single.args[1] as Offset;
      expect(end.dx, closeTo(want.stem.dx, 1e-9), reason: 'flipY $flipY');
      expect(end.dy, closeTo(want.stem.dy, 1e-9), reason: 'flipY $flipY');
    }
  });

  test(
      'a move of a rotated selection draws the grip through T · frame, '
      'not frame · T (M-RFo, M-RFp)', () async {
    // A rotated frame and a translating preview: the one pair whose two
    // composition orders differ. A rotate about the frame's own pivot
    // commutes with it.
    for (final flipY in const [true, false]) {
      final (doc, h) = triangleDoc();
      final rig = gripRig(doc, camera: gripCamera(flipY: flipY));
      rig.selection.replace([k(h)]);
      rotateBy(rig, 0.7);
      await Future<void>.delayed(Duration.zero);
      final c = payloadOf(doc, h).coords;
      final on = screenOf(
          rig.camera, c[0] + 0.3 * (c[2] - c[0]), c[1] + 0.3 * (c[3] - c[1]));
      pressAndMove(rig, on, on + const Offset(37, -21));
      final t = rig.tool.selectionPreviewTransform!;
      expect(t.a, 1, reason: 'a move');
      final spy = SpyCanvas();
      overlayOf(rig).paint(spy, kView);
      final want = orientedGripOracle(
          rig.camera, rig.grips.box!, t.multiply(rig.grips.frame));
      final disc = spy.named('drawCircle').single.args[0] as Offset;
      expect(disc.dx, closeTo(want.centre.dx, 1e-9), reason: 'flipY $flipY');
      expect(disc.dy, closeTo(want.centre.dy, 1e-9), reason: 'flipY $flipY');
    }
  });
}
