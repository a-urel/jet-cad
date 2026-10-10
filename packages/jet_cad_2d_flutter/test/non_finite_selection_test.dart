// O-11 (host embedding API spec, Open items): a selection whose points are
// not finite on the world or on the screen. The embedding fixture's table
// `9` is an instance scaled (1e306, 1e-306): its outline reaches x = inf,
// and an axis-aligned camera's `b = 0` turns that into `0 · inf = NaN` on
// the screen, which `Canvas.drawLine` asserts on. The overlay and the grip
// cache skip what is not finite: a box takes no non-finite bounds, the
// cache keeps no non-finite grip, and the painter draws no rotation grip and
// no point cross whose screen position is not finite. Every paint here goes
// to a real `Canvas`, whose debug assertions are the failure under test.
//
// Named mutants: M-O11a (the box takes non-finite bounds), M-O11b (the
// cache keeps a non-finite grip), M-O11c (the rotation grip is drawn at a
// non-finite position), M-O11d (a point cross is drawn at a non-finite
// position).
import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, PictureRecorder, Size;

import 'package:flutter/widgets.dart' show Listenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/canvas_palette.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
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
      paper: PaperPalette.light,
      repaint: Listenable.merge(
          [rig.selection, rig.tools, rig.camera, rig.outlines, rig.grips]),
    );

/// One frame of [rig]'s overlay on a real canvas: its debug assertions run.
void paintReal(GripRig rig) {
  final recorder = PictureRecorder();
  overlayOf(rig).paint(Canvas(recorder), kView);
  recorder.endRecording().dispose();
}

/// One frame of [rig]'s overlay, recorded.
SpyCanvas paintSpy(GripRig rig) {
  final spy = SpyCanvas();
  overlayOf(rig).paint(spy, kView);
  return spy;
}

/// The embedding fixture's table `9`, in this package's terms: a closed
/// quadrilateral (300..1100, -200..400) placed by x · 1e306, y · 1e-306 at
/// (43000, -35000). Its x reaches 1100 · 1e306 = inf; its y stays finite.
({DraftDocument doc, Handle table, Handle line}) tableNine() {
  final doc = DraftDocument.empty();
  final def = addDefinition(doc, 'Table');
  addEntity(doc, def, EntityKind.polyline,
      [300, -200, 1100, -200, 900, 400, 300, 250, 300, -200], []);
  final table = addInstance(
      doc, def, const Transform2(1e306, 0, 0, 1e-306, 43000, -35000));
  final line = addEntity(
      doc, doc.rootHandle, EntityKind.line, [42000, -36000, 44000, -34500], []);
  return (doc: doc, table: table, line: line);
}

/// Grips a provider gives a group: one finite, two not (07 D11's seam).
final class NonFiniteObjects implements ObjectGripProvider {
  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) => const [
        Grip(GripRole.stretch, 0, 7010, 3020),
        Grip(GripRole.stretch, 1, double.infinity, 3020),
        Grip(GripRole.move, 0, double.nan, double.nan),
      ];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      null;

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      const [];

  @override
  bool movable(DraftDocument d, Handle group) => true;
}

void main() {
  test(
      'NF1 a key whose world bounds are not finite adds nothing to the box '
      '(M-O11a)', () {
    final t = tableNine();
    final rig =
        gripRig(t.doc, camera: gripCamera(centre: Vector2(43000, -35000)));
    final bounds = rig.outlines.worldBoundsOf;
    rig.selection.replace([k(t.table)]);
    final nine = bounds(k(t.table));
    expect(nine, isNotNull, reason: 'premise: table 9 has an outline');
    expect(nine!.maxX, double.infinity,
        reason: 'premise: 1100 · 1e306 overflows');
    expect(rig.grips.box, isNull, reason: 'nothing finite is selected');
    expect(rig.grips.pivot, isNull);
    expect(rig.grips.rotatable, isFalse);

    rig.selection.replace([k(t.table), k(t.line)]);
    final box = rig.grips.box!;
    expect([
      box.minX,
      box.minY,
      box.maxX,
      box.maxY
    ], [
      42000.0,
      -36000.0,
      44000.0,
      -34500.0
    ], reason: 'the line\'s box alone, not widened to infinity');
    expect(rig.grips.pivot, Vector2(43000, -35250));
    expect(rig.grips.rotatable, isTrue);
  });

  test(
      'NF2 table 9 selected and hovered paints without an assertion under an '
      'axis-aligned camera and a rotated one, with no rotation grip (O-11)',
      () {
    for (final rotation in const [0.0, 0.35]) {
      final t = tableNine();
      final rig = gripRig(t.doc,
          camera: gripCamera(
              centre: Vector2(43000, -35000), scale: 0.37, rotation: rotation));
      rig.selection.replace([k(t.table)]);
      rig.selection.setHover(k(t.line));
      paintReal(rig);
      expect(paintSpy(rig).named('drawCircle'), isEmpty,
          reason: 'rotation $rotation: no rotation grip');
    }
  });

  group(
      'NF3 the rotation grip is skipped when its screen position is not '
      'finite (M-O11c)', () {
    // Two short vertical lines at x = ±1.5e308: the box is finite, but at
    // scale 2 its corners project to -inf and +inf, and their middle is NaN.
    ({DraftDocument doc, Handle a, Handle b}) farApart() {
      final doc = DraftDocument.empty();
      final a = addEntity(doc, doc.rootHandle, EntityKind.line,
          [-1.5e308, 0, -1.5e308, 10], []);
      final b = addEntity(
          doc, doc.rootHandle, EntityKind.line, [1.5e308, 0, 1.5e308, 10], []);
      return (doc: doc, a: a, b: b);
    }

    test('premise: at scale 1e-150 the same selection draws its grip', () {
      final f = farApart();
      final rig = gripRig(f.doc,
          camera: gripCamera(centre: Vector2(0, 5), scale: 1e-150));
      rig.selection.replace([k(f.a), k(f.b)]);
      expect(rig.grips.rotatable, isTrue);
      paintReal(rig);
      expect(paintSpy(rig).named('drawCircle'), hasLength(1));
    });

    test('at scale 2 it is not drawn, and nothing asserts', () {
      final f = farApart();
      final rig =
          gripRig(f.doc, camera: gripCamera(centre: Vector2(0, 5), scale: 2));
      rig.selection.replace([k(f.a), k(f.b)]);
      expect(rig.grips.rotatable, isTrue, reason: 'premise: a finite box');
      final g =
          rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix);
      expect(g.centre.dx.isNaN, isTrue, reason: 'premise: -inf + inf');
      paintReal(rig);
      expect(paintSpy(rig).named('drawCircle'), isEmpty);
    });
  });

  test(
      'NF4 the cache keeps no grip whose world position is not finite, and a '
      'press away from the finite one hits nothing (M-O11b)', () {
    final s = gripScene();
    final rig = gripRig(s.document, objects: NonFiniteObjects());
    rig.selection.replace([k(s.group)]);
    expect([for (final g in rig.grips.grips) (g.grip.x, g.grip.y)],
        [(7010.0, 3020.0)]);
    expect(rig.grips.stretchCount, 1);
    expect(rig.grips.moveCount, 0);
    final m = rig.camera.value.worldToScreenMatrix;
    final at = screenOf(rig.camera, 7010, 3020);
    expect(rig.grips.hitTest(at, m), 0);
    expect(rig.grips.hitTest(at + const Offset(200, 150), m), -1,
        reason: 'a NaN distance is never "within reach"');
    paintReal(rig);
  });

  test(
      'NF4b a leaf\'s grip that overflows is not kept either: a circle at '
      'x = 1.5e308 of radius 1e308 has its quadrant 0 at x = inf (M-O11b)', () {
    final doc = DraftDocument.empty();
    final circle = addEntity(
        doc, doc.rootHandle, EntityKind.circle, [1.5e308, 0], [1e308]);
    // Axis-aligned: `b = 0`, so that grip's screen y is 0 · inf = NaN.
    final rig = gripRig(doc,
        camera: gripCamera(centre: Vector2(1.5e308, 0), rotation: 0));
    rig.selection.replace([k(circle)]);
    expect([
      for (final g in rig.grips.grips) (g.grip.role, g.grip.index)
    ], [
      (GripRole.move, 0),
      (GripRole.radius, 1),
      (GripRole.radius, 2),
      (GripRole.radius, 3)
    ], reason: 'quadrant 0 left out, the others keep their indices');
    expect(
        rig.grips.hitTest(
            const Offset(-500, -500), rig.camera.value.worldToScreenMatrix),
        -1);
    paintReal(rig);
  });

  test(
      'NF5 a point whose screen position is not finite draws no cross '
      '(M-O11d)', () {
    // At scale 4 and 45 degrees, x = 2.83 · 1.5e308 - 2.83 · 1.5e308 is
    // inf - inf: NaN, though the point is finite in the world.
    final doc = DraftDocument.empty();
    final p = addEntity(
        doc, doc.rootHandle, EntityKind.point, [1.5e308, 1.5e308], []);
    final near = addEntity(doc, doc.rootHandle, EntityKind.point, [10, 20], []);
    final rig = gripRig(doc,
        camera: gripCamera(
            centre: Vector2(10, 20),
            scale: 4,
            rotation: math.pi / 4,
            flipY: false));
    rig.selection.replace([k(p), k(near)]);
    rig.selection.setHover(k(p));
    paintReal(rig);
    final crosses = paintSpy(rig).named('drawLine').where((c) {
      final a = c.args[0] as Offset;
      return !a.dx.isFinite || !a.dy.isFinite;
    });
    expect(crosses, isEmpty);
    expect(paintSpy(rig).named('drawLine'), isNotEmpty,
        reason: 'premise: the finite point\'s cross is drawn');
  });
}
