### Task 8: The overlay — grips, the rotation grip, the preview, the reshape path, snap markers

**Files:**
- Create: `lib/src/snap_marker.dart`
- Modify: `lib/src/selection_overlay.dart` (replaced whole; text below)
- Modify: `lib/src/select_tool.dart` (paint members; the Task 7 file plus
  the edits below)
- Modify: `lib/jet_cad_2d_flutter.dart`: add `export
  'src/snap_marker.dart';` before `src/snap_settings.dart`.
- Test: `test/snap_marker_test.dart` (K1),
  `test/selection_overlay_grips_test.dart` (P1, P2, P4, P5, P6, P8)

**Interfaces:**
- Consumes:
  - `GripCache` (`grips`, `stretchCount`, `moveCount`, `hot`, `box`,
    `rotatable`, `leafGripsLive`) and `rotationGripOf` (Task 4);
  - `Tool.paintWorldOverlay` and `selectionPreviewTransform` (Task 5);
  - `SelectTool`'s `_drag`, `_dragPoint` and `_lastScreen` (Task 7);
  - `GripDrag.base`, `target`, `previewPayload` and `leafKind` (Task 6).
- Produces:
  - `void drawSnapMarker(Canvas canvas, Offset at, SnapKind? kind, {required bool grid, required Paint paint})`
  - `SelectionOverlayPainter` paints, in order:
    1. the rebased world pass: outlines, then `tool.paintWorldOverlay`;
    2. the preview pass through `worldToScreen ∘ T ∘ translate(origin)`;
    3. the screen pass: point crosses, preview crosses at `T(p)`, grips
       (`drawRawPoints`), the hot grip, the rotation grip, then
       `tool.paintOverlay`.
  - `SelectTool.paintOverlay` draws the guide line and the marker during a
    move, rotate or reshape. `SelectTool.paintWorldOverlay` draws the
    reshape preview path.

- [ ] **Step 1: Write the failing tests.**

```dart
// test/snap_marker_test.dart
import 'dart:ui' show Offset, Paint, Path, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;
import 'package:jet_cad_2d_flutter/src/snap_marker.dart';

import 'support/spy_canvas.dart';

void main() {
  test('each snap kind draws its own marker; the raw point draws nothing '
      '(spec D9, M-03ag)', () {
    const at = Offset(300, 200);
    final paint = Paint();
    List<RecordedCall> draw(SnapKind? kind, {bool grid = false}) {
      final spy = SpyCanvas();
      drawSnapMarker(spy, at, kind, grid: grid, paint: paint);
      return spy.calls;
    }

    List<String> names(List<RecordedCall> calls) =>
        [for (final c in calls) c.name];

    final endpoint = draw(SnapKind.endpoint);
    expect(names(endpoint), ['drawRect']);
    expect(endpoint.single.args[0],
        Rect.fromCenter(center: at, width: 10, height: 10));

    final midpoint = draw(SnapKind.midpoint);
    expect(names(midpoint), ['drawPath']);
    final triangle = midpoint.single.args[0] as Path;
    expect(triangle.contains(at + const Offset(0, 4)), isTrue,
        reason: 'the base is at the bottom');
    expect(triangle.contains(at + const Offset(-4, -4)), isFalse,
        reason: 'apex up: the top corners are outside');

    final center = draw(SnapKind.center);
    expect(names(center), ['drawCircle']);
    expect(center.single.args[1], 5.0);

    final quadrant = draw(SnapKind.quadrant);
    expect(names(quadrant), ['drawPath']);
    final diamond = quadrant.single.args[0] as Path;
    expect(diamond.contains(at), isTrue);
    expect(diamond.contains(at + const Offset(4, 4)), isFalse);

    expect(names(draw(SnapKind.insertion)), ['drawRect', 'drawLine', 'drawLine']);

    final x = draw(SnapKind.intersection);
    expect(names(x), ['drawLine', 'drawLine']);
    expect(x[0].args[0], at + const Offset(-5, -5));
    expect(x[0].args[1], at + const Offset(5, 5));

    final grid = draw(null, grid: true);
    expect(names(grid), ['drawLine', 'drawLine']);
    expect(((grid[0].args[1] as Offset) - (grid[0].args[0] as Offset)).distance,
        6.0);

    expect(draw(null), isEmpty, reason: 'nothing when the raw point won');
    for (final kind in [
      SnapKind.perpendicular,
      SnapKind.tangent,
      SnapKind.nearest,
    ]) {
      expect(draw(kind), isEmpty, reason: '${kind.name} is not in kDragSnapMask');
    }
  });
}
```

```dart
// test/selection_overlay_grips_test.dart
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
    rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;

void main() {
  test('the move/rotate preview is drawn through worldToScreen ∘ T ∘ '
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
    expect(spy.named('drawPath').where((c) => c.color == kPreviewColor),
        hasLength(1));
  });

  test('grips are one drawRawPoints per colour at 10 grips and at 300, and '
      'the hot grip one more (invariant 6, M-03v, M-03aq)', () {
    (List<RecordedCall>, GripRig) frame(int vertices, {int hot = -1}) {
      final doc = DraftDocument.empty();
      final poly = addEntity(doc, doc.rootHandle, EntityKind.polyline, [
        for (var i = 0; i < vertices; i++)
          ...[7000.0 + i * 0.5, i.isEven ? 3000.0 : 3002.0],
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
    expect(raw[0].color, kGripColor);
    expect(raw[0].strokeWidth, kGripPixels);
    expect((raw[0].args[2] as Paint).strokeCap, StrokeCap.square);
    expect((raw[1].args[1] as Float32List).length, 2, reason: 'one centre');
    expect(raw[1].color, kGripMoveColor);

    final (hot, rig) = frame(5, hot: 2);
    final hotCalls = [
      for (final c in hot)
        if (c.name == 'drawRawPoints') c,
    ];
    expect(hotCalls, hasLength(3));
    expect(hotCalls[2].color, kGripHotColor);
    final pts = hotCalls[2].args[1] as Float32List;
    final third = screenOf(rig.camera, 7001, 3000); // the polyline's vertex 2
    expect(pts[0], closeTo(third.dx, 1e-3));
    expect(pts[1], closeTo(third.dy, 1e-3));
  });

  test('no leaf grips are drawn under a geometry denial; the rotation grip '
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
        if (c.color == kPreviewColor &&
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

  test('the reshape preview is a rebased path under the world matrix '
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
    final at = spy.calls.indexWhere(
        (c) => c.name == 'drawPath' && c.color == kPreviewColor);
    expect(at, greaterThan(names.indexOf('transform')));
    expect(at, lessThan(names.indexOf('restore')),
        reason: 'drawn under the rebased world matrix');
    final bounds = (spy.calls[at].args[0] as Path).getBounds();
    expect(bounds.left, closeTo(7010 - origin.x, 1e-3));
    expect(bounds.right, closeTo(target.x - origin.x, 1e-3));
    expect(bounds.top, closeTo(math.min(3020, target.y) - origin.y, 1e-3));
    expect(bounds.bottom, closeTo(math.max(3020, target.y) - origin.y, 1e-3));
    expect(spy.calls[at].strokeWidth,
        closeTo(kPreviewStrokePixels / rig.camera.value.scale, 1e-12));
  });

  test('a stretch draws its guide and the snap marker at the resolved '
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
        if (c.color == kSnapMarkerColor) c,
    ];
    expect(markers, hasLength(1), reason: 'an endpoint won: a square');
    final r = markers.single.args[0] as Rect;
    expect(r.center.dx, closeTo(endpoint.dx, 1e-6));
    expect(r.center.dy, closeTo(endpoint.dy, 1e-6));
    expect(r.width, kSnapMarkerPixels);
    final guide = spy.named('drawLine').where((c) => c.color == kPreviewColor);
    expect(guide, hasLength(1));
    expect((guide.single.args[0] as Offset).dx, closeTo(vertex.dx, 1e-6));
    expect((guide.single.args[1] as Offset).dx, closeTo(endpoint.dx, 1e-6));
  });
}
```

- [ ] **Step 2: Run them to fail.** `CI=true flutter test
  test/snap_marker_test.dart test/selection_overlay_grips_test.dart` →
  compile error in `snap_marker.dart`, and the overlay tests fail: no
  `drawRawPoints`, and only one `transform`.

- [ ] **Step 3: Implement.** Create `lib/src/snap_marker.dart`:

```dart
import 'dart:ui' show Canvas, Offset, Paint, Path, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;

import 'selection_style.dart';

/// Spec D9's marker at [at], in screen space: a fixed, small number of draw
/// calls. [kind] non-null means an object snap won; otherwise [grid] draws
/// the grid's `+`, and nothing is drawn when the raw point won.
void drawSnapMarker(Canvas canvas, Offset at, SnapKind? kind,
    {required bool grid, required Paint paint}) {
  const h = kSnapMarkerPixels / 2;
  if (kind == null) {
    if (!grid) return;
    const g = kGridMarkerPixels / 2;
    canvas.drawLine(at.translate(-g, 0), at.translate(g, 0), paint);
    canvas.drawLine(at.translate(0, -g), at.translate(0, g), paint);
    return;
  }
  switch (kind) {
    case SnapKind.endpoint:
      canvas.drawRect(
          Rect.fromCenter(
              center: at, width: kSnapMarkerPixels, height: kSnapMarkerPixels),
          paint);
    case SnapKind.midpoint:
      // Apex up: screen y grows downward.
      canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - h)
            ..lineTo(at.dx + h, at.dy + h)
            ..lineTo(at.dx - h, at.dy + h)
            ..close(),
          paint);
    case SnapKind.center:
      canvas.drawCircle(at, h, paint);
    case SnapKind.quadrant:
      canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - h)
            ..lineTo(at.dx + h, at.dy)
            ..lineTo(at.dx, at.dy + h)
            ..lineTo(at.dx - h, at.dy)
            ..close(),
          paint);
    case SnapKind.insertion:
      canvas.drawRect(
          Rect.fromCenter(
              center: at, width: kSnapMarkerPixels, height: kSnapMarkerPixels),
          paint);
      canvas.drawLine(at.translate(-h, 0), at.translate(h, 0), paint);
      canvas.drawLine(at.translate(0, -h), at.translate(0, h), paint);
    case SnapKind.intersection:
      canvas.drawLine(at.translate(-h, -h), at.translate(h, h), paint);
      canvas.drawLine(at.translate(-h, h), at.translate(h, -h), paint);
    case SnapKind.perpendicular:
    case SnapKind.tangent:
    case SnapKind.nearest:
      // Not in kDragSnapMask: a drag never produces them.
      return;
  }
}
```

Replace `lib/src/selection_overlay.dart` whole. The class doc and every
line not named below are kept as they are; the new members are marked.

```dart
import 'dart:typed_data';
import 'dart:ui'
    show Canvas, Offset, Paint, PaintingStyle, PointMode, Size, StrokeCap;

import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart' show GripRole, Transform2;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'grip_cache.dart';
import 'outline_cache.dart';
import 'selection.dart';
import 'selection_style.dart';
import 'tool.dart';

/// Draws the selected and hovered outlines, then lets the active tool draw
/// its own overlay — and never touches the drawing underneath.
///
/// Named `…Painter` rather than the spec's `SelectionOverlay`: Flutter's own
/// `SelectionOverlay` (text selection) is exported from
/// `package:flutter/widgets.dart`, so an app that imports Material and this
/// package's barrel would have to `hide` one of them at every consumer.
///
/// The overlay is a **second** `CustomPaint` inside its own
/// `RepaintBoundary`, over `Listenable.merge([selection, tools, camera])`.
/// That is the whole point of the split (spec criterion 6): a hover at
/// pointer rate repaints this painter and leaves the drawing's layer alone,
/// so the cost of moving the mouse over a large document is one overlay
/// frame, not one full re-render.
///
/// Three things keep the frame path allocation-free. The outlines come from
/// [OutlineCache] already built — the document walk happens at
/// selection-change rate, not per frame. The two [Paint]s and the matrix are
/// fields, re-stroked and refilled in place. And the origin the cache rebases
/// by is carried by the matrix rather than by the paths, so no absolute world
/// coordinate reaches `dart:ui`: at the generated corpus's x = 4.5e6 a
/// float32 `ui.Path` would sit visibly beside the entity it outlines.
///
/// Since 03 it also draws, reading the grips from `tools.context.grips`
/// (Ruling 03-4):
/// - the move/rotate preview through a second reused matrix;
/// - the grips, with `drawRawPoints` from reused buffers, in O(1) draw calls
///   (invariant 6);
/// - the rotation grip.
class SelectionOverlayPainter extends CustomPainter {
  SelectionOverlayPainter({
    required this.selection,
    required this.tools,
    required this.camera,
    required this.outlines,
    super.repaint,
    this.onPaintForTest,
  });

  final SelectionController selection;
  final ToolController tools;
  final CameraController camera;
  final OutlineCache outlines;

  /// Counts frames in a widget test — the seam criterion 6 is measured on.
  final void Function()? onPaintForTest;

  /// `worldToScreen ∘ translate(origin)`, column-major, refilled per frame.
  /// `[10]` and `[15]` are the untouched z and w diagonal entries.
  final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  /// New in 03: `worldToScreen ∘ T ∘ translate(origin)` for the move/rotate
  /// preview (spec D7), refilled per frame. The paths hold `world − origin`,
  /// so T sits between the camera and the rebase (M-03u).
  final Float64List _preview = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  final Paint _selected = Paint()
    ..color = kSelectionColor
    ..style = PaintingStyle.stroke;

  final Paint _hover = Paint()
    ..color = kHoverColor
    ..style = PaintingStyle.stroke;

  // New in 03.
  final Paint _previewPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;

  final Paint _gripPaint = Paint()
    ..color = kGripColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _gripMovePaint = Paint()
    ..color = kGripMoveColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _gripHotPaint = Paint()
    ..color = kGripHotColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _stem = Paint()
    ..color = kGripColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  /// Screen positions, exact-size, reallocated only when the count changes
  /// (Ruling 03-10).
  Float32List _stretchPoints = Float32List(0);
  Float32List _movePoints = Float32List(0);
  final Float32List _hotPoint = Float32List(2);

  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    // A zero-size paint is a real state, not a theoretical one — see
    // `ViewportTransform.fit`'s note on the layout passes that produce it.
    // It must return *before* the rebase, because `visibleWorld(Size.zero)`
    // collapses to a point, `rebaseOriginFor` answers the origin for a zero
    // span, and `pathFor(key, zero)` would then rebuild every cached path in
    // **absolute** world space and hand x = 4.5e6 to float32 `ui.Path` —
    // undoing the rebase the cache exists for, and re-doing the rebuild on
    // the next real frame.
    if (size.isEmpty) return;
    final cam = camera.value;
    final origin = rebaseOriginFor(cam.visibleWorld(size));
    final m = cam.worldToScreenMatrix;
    _matrix[0] = m.a;
    _matrix[1] = m.b;
    _matrix[4] = m.c;
    _matrix[5] = m.d;
    _matrix[12] = m.a * origin.x + m.c * origin.y + m.e;
    _matrix[13] = m.b * origin.x + m.d * origin.y + m.f;
    // The stroke rides the world→screen matrix, so the world width is the
    // screen width divided by the scale; that is what holds the outline at
    // two pixels through a zoom.
    final scale = cam.scale;
    _selected.strokeWidth = kSelectionStrokePixels / scale;
    _hover.strokeWidth = kHoverStrokePixels / scale;
    final tool = tools.active;

    final hover = selection.hover;
    // A hovered key that is also selected is drawn once, by the selected
    // pass: stroking it twice would read as a third, brighter state.
    final hoverOnly =
        hover != null && !selection.contains(hover) ? hover : null;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_matrix);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _selected);
    }
    if (hoverOnly != null) {
      final path = outlines.pathFor(hoverOnly, origin);
      if (path != null) canvas.drawPath(path, _hover);
    }
    // New in 03: the reshape preview, in rebased world, under this same
    // matrix (spec D7, Ruling 03-3).
    tool.paintWorldOverlay(canvas, origin, scale);
    canvas.restore();

    // New in 03: the move/rotate preview (spec D7).
    final preview = tool.selectionPreviewTransform;
    if (preview != null) {
      _paintPreview(canvas, size, m, preview, origin, scale);
    }

    // Back in screen space, under its **own** clip: `restore` above popped
    // the first one, and neither the point crosses nor the tool's overlay is
    // bounded by the viewport on its own — a selected point just off screen
    // puts its cross over whatever sibling widget sits beside the canvas.
    //
    // A `point` entity has no extent, so its path is a lone `moveTo` and
    // strokes nothing; its marker is a cross whose size is in pixels and
    // therefore cannot live in the world-space cache. The two paints are
    // re-stroked rather than replaced — `Canvas` serialises a paint at call
    // time, so the world-space strokes above are already recorded at their
    // own widths.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _selected.strokeWidth = kSelectionStrokePixels;
    _hover.strokeWidth = kHoverStrokePixels;
    for (final key in selection.keys) {
      _drawPointCross(canvas, key, m, _selected, 3 * kSelectionStrokePixels);
    }
    if (hoverOnly != null) {
      _drawPointCross(canvas, hoverOnly, m, _hover, 3 * kHoverStrokePixels);
    }
    if (preview != null) {
      // A point has no path; its preview is its cross at T(p) (spec D7).
      _previewPaint.strokeWidth = kPreviewStrokePixels;
      for (final key in selection.keys) {
        _drawPointCross(canvas, key, m, _previewPaint,
            3 * kSelectionStrokePixels, preview);
      }
    }
    final grips = tools.context.grips;
    if (grips != null) _paintGrips(canvas, grips, m);
    tool.paintOverlay(canvas, cam, size);
    canvas.restore();
  }

  void _paintPreview(Canvas canvas, Size size, Transform2 m, Transform2 t,
      Vector2 origin, double scale) {
    // T ∘ translate(origin): the rebase first, then the drag. Composed in
    // doubles, with no Transform2 allocated per frame.
    final pe = t.a * origin.x + t.c * origin.y + t.e;
    final pf = t.b * origin.x + t.d * origin.y + t.f;
    _preview[0] = m.a * t.a + m.c * t.b;
    _preview[1] = m.b * t.a + m.d * t.b;
    _preview[4] = m.a * t.c + m.c * t.d;
    _preview[5] = m.b * t.c + m.d * t.d;
    _preview[12] = m.a * pe + m.c * pf + m.e;
    _preview[13] = m.b * pe + m.d * pf + m.f;
    // T is rigid, so the camera's scale is still the whole scale.
    _previewPaint.strokeWidth = kPreviewStrokePixels / scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_preview);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _previewPaint);
    }
    canvas.restore();
  }

  /// Spec D6: one `drawRawPoints` per colour, whatever the grip count;
  /// projected in doubles, and only screen coordinates are narrowed
  /// (Ruling 03-10).
  void _paintGrips(Canvas canvas, GripCache grips, Transform2 m) {
    if (grips.leafGripsLive) {
      final list = grips.grips;
      if (_stretchPoints.length != 2 * grips.stretchCount) {
        _stretchPoints = Float32List(2 * grips.stretchCount);
      }
      if (_movePoints.length != 2 * grips.moveCount) {
        _movePoints = Float32List(2 * grips.moveCount);
      }
      var s = 0, mv = 0;
      for (var i = 0; i < list.length; i++) {
        final g = list[i].grip;
        final x = m.a * g.x + m.c * g.y + m.e;
        final y = m.b * g.x + m.d * g.y + m.f;
        if (g.role == GripRole.move) {
          _movePoints[mv++] = x;
          _movePoints[mv++] = y;
        } else {
          _stretchPoints[s++] = x;
          _stretchPoints[s++] = y;
        }
      }
      if (s > 0) {
        canvas.drawRawPoints(PointMode.points, _stretchPoints, _gripPaint);
      }
      if (mv > 0) {
        canvas.drawRawPoints(PointMode.points, _movePoints, _gripMovePaint);
      }
      final hot = grips.hot;
      if (hot >= 0 && hot < list.length) {
        final g = list[hot].grip;
        _hotPoint[0] = m.a * g.x + m.c * g.y + m.e;
        _hotPoint[1] = m.b * g.x + m.d * g.y + m.f;
        canvas.drawRawPoints(PointMode.points, _hotPoint, _gripHotPaint);
      }
    }
    final box = grips.box;
    if (grips.rotatable && box != null) {
      final g = rotationGripOf(box, m);
      canvas.drawLine(g.anchor,
          g.centre.translate(0, kRotationGripPixels / 2), _stem);
      canvas.drawCircle(g.centre, kRotationGripPixels / 2, _gripPaint);
    }
  }

  /// A cross of half-length [half] **screen pixels** centred on [key]'s world
  /// position — or, with [moved], on `moved(position)` — or nothing at all
  /// when [key] is not a lone point.
  ///
  /// [worldToScreen] is the camera's own matrix, not [_matrix]: the position
  /// [OutlineCache.worldPointOf] hands back is absolute world, and this pass
  /// runs after the rebased transform has been popped. It never reaches
  /// `dart:ui` — only the screen coordinates derived from it do.
  void _drawPointCross(Canvas canvas, SelectionKey key,
      Transform2 worldToScreen, Paint paint, double half,
      [Transform2? moved]) {
    final p = outlines.worldPointOf(key);
    if (p == null) return;
    var px = p.x, py = p.y;
    if (moved != null) {
      final tx = moved.a * px + moved.c * py + moved.e;
      final ty = moved.b * px + moved.d * py + moved.f;
      px = tx;
      py = ty;
    }
    final x = worldToScreen.a * px + worldToScreen.c * py + worldToScreen.e;
    final y = worldToScreen.b * px + worldToScreen.d * py + worldToScreen.f;
    canvas.drawLine(Offset(x - half, y), Offset(x + half, y), paint);
    canvas.drawLine(Offset(x, y - half), Offset(x, y + half), paint);
  }

  /// Always false: every reason to repaint is in the `repaint` listenable the
  /// caller merged. Answering true would repaint on every ancestor rebuild,
  /// which is exactly the cost the boundary split exists to avoid.
  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) => false;
}
```

In `lib/src/select_tool.dart`:
- add `import 'snap_marker.dart';`;
- add three paint fields after `_cursor`;
- replace the first two lines of `paintOverlay`'s body (`final rect =
  bandScreen; if (rect == null) return;`) with the drag branch below;
- add `paintWorldOverlay`, `_paintGuide` and `_reshapePath` after
  `_drawDashedRect`.

```dart
  // After `MouseCursor _cursor = MouseCursor.defer;`:
  final Paint _guidePaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _markerPaint = Paint()
    ..color = kSnapMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;
  final Paint _previewPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;
```

```dart
  // The head of paintOverlay's body:
    final drag = _drag;
    if (drag != null && _phase == ToolPhase.dragging) {
      _paintGuide(canvas, camera.worldToScreenMatrix, drag);
      return;
    }
    final rect = bandScreen;
    if (rect == null) return;
```

```dart
  /// Spec D7: a 1 px line from the base (a rotate's pivot) to the target,
  /// and D9's marker at the target. A rotate snaps to nothing, so it has no
  /// marker.
  void _paintGuide(Canvas canvas, Transform2 m, GripDrag drag) {
    final from = drag.base, to = drag.target;
    final a = Offset(
        m.a * from.x + m.c * from.y + m.e, m.b * from.x + m.d * from.y + m.f);
    final b =
        Offset(m.a * to.x + m.c * to.y + m.e, m.b * to.x + m.d * to.y + m.f);
    canvas.drawLine(a, b, _guidePaint);
    if (drag.kind == DragKind.rotate) return;
    drawSnapMarker(canvas, b, _dragPoint.objectKind,
        grid: _dragPoint.grid, paint: _markerPaint);
  }

  /// Spec D7: the reshape preview, drawn by the overlay under its rebased
  /// world matrix (Ruling 03-3). One path per frame, independent of the
  /// document and the selection size.
  @override
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {
    final drag = _drag;
    if (drag == null || drag.kind != DragKind.reshape) return;
    final payload = drag.previewPayload;
    final kind = drag.leafKind;
    // A degenerate reshape: the canvas still shows the object unchanged.
    if (payload == null || kind == null) return;
    _previewPaint.strokeWidth = kPreviewStrokePixels / scale;
    canvas.drawPath(_reshapePath(kind, payload, origin), _previewPaint);
  }

  /// [p] in rebased world, `world − origin`: no absolute world coordinate
  /// reaches float32. Arc angles go in unchanged, because the camera's
  /// y-flip and rotation are the matrix's business.
  static Path _reshapePath(EntityKind kind, GeometryPayload p, Vector2 origin) {
    final path = Path();
    final c = p.coords;
    final ox = origin.x, oy = origin.y;
    switch (kind) {
      case EntityKind.line:
      case EntityKind.polyline:
        if (c.length < 2) return path;
        path.moveTo(c[0] - ox, c[1] - oy);
        for (var i = 2; i + 1 < c.length; i += 2) {
          path.lineTo(c[i] - ox, c[i + 1] - oy);
        }
      case EntityKind.circle:
        path.addOval(Rect.fromCircle(
            center: Offset(c[0] - ox, c[1] - oy), radius: p.scalars[0]));
      case EntityKind.arc:
        path.addArc(
            Rect.fromCircle(
                center: Offset(c[0] - ox, c[1] - oy), radius: p.scalars[0]),
            p.scalars[1],
            p.scalars[2]);
      case EntityKind.point:
      case EntityKind.text:
      case EntityKind.attrib:
      case EntityKind.fill:
        break;
    }
    return path;
  }
```

Add the export to `lib/jet_cad_2d_flutter.dart`, before
`src/snap_settings.dart`:

```dart
export 'src/snap_marker.dart';
```

- [ ] **Step 4: Run them to pass.** `CI=true flutter test
  test/snap_marker_test.dart test/selection_overlay_grips_test.dart
  test/selection_overlay_test.dart test/select_tool_drag_test.dart` → all
  tests pass. Every 02 overlay test must pass unedited: with the tool idle
  and the 02 rig's `grips == null`, the new passes draw nothing. Then run
  the `jet_cad_2d_flutter` gate line.
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/snap_marker.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/snap_marker_test.dart packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart
git commit -m "$(cat <<'EOF'
feat(render): overlay grips, rotation grip, preview, snap markers

Spec 03 D6, D7, D9: grips via drawRawPoints from exact-size reused buffers
(O(1) draw calls), the hot grip, the rotation grip hung screen-up, the
move/rotate preview through worldToScreen o T o translate(origin), point
crosses at T(p), the reshape path in rebased world, and the guide line with
its snap marker.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

