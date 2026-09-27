import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart' show kDefaultOriginX;
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draft_canvas.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart'
    show kPickRadiusPixels;
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';
import 'support/spy_canvas.dart';

const Size kViewport = Size(400, 300);

/// Everything the painter needs, wired in the order the ledger fixes: the
/// controller is constructed **before** the cache, so the controller prunes
/// on a `DocChange` before the cache walks.
final class Rig {
  Rig(this.document)
      : index = SpatialIndex(document),
        selection = SelectionController(document) {
    outlines = OutlineCache(document, selection);
    camera =
        CameraController(ViewportTransform.fit(document.extents, kViewport));
    tool = SelectTool();
    context = ToolContext(
        document: document, index: index, camera: camera, selection: selection);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final SpatialIndex index;
  final SelectionController selection;
  late final OutlineCache outlines;
  late final CameraController camera;
  late final SelectTool tool;
  late final ToolContext context;
  late final ToolController tools;

  SelectionOverlayPainter overlay({void Function()? onPaintForTest}) =>
      SelectionOverlayPainter(
        selection: selection,
        tools: tools,
        camera: camera,
        outlines: outlines,
        repaint: Listenable.merge([selection, tools, camera, outlines]),
        onPaintForTest: onPaintForTest,
      );

  void dispose() {
    tools.dispose();
    outlines.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

Rig rig(DraftDocument doc) {
  final r = Rig(doc);
  addTearDown(r.dispose);
  return r;
}

/// A pointer sample, as in `select_tool_test.dart`.
ToolPointerEvent ev(CameraController camera, Offset screen,
        {int buttons = kPrimaryButton, int pointer = 1}) =>
    ToolPointerEvent(
      screen: screen,
      world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
      pointer: pointer,
      buttons: buttons,
      shift: false,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
    );

Paint paintOf(RecordedCall call) => call.args.whereType<Paint>().single;

/// The `transform` matrix the painter pushed, **copied**: the spy records the
/// argument by reference and the painter refills that same `Float64List` on
/// its next frame, so a held reference would report the wrong frame.
Float64List matrixOf(SpyCanvas spy) =>
    Float64List.fromList(spy.named('transform').single.args[0] as Float64List);

/// `(x, y)` mapped through a recorded column-major 4x4.
Offset through(Float64List m, double x, double y) =>
    Offset(m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13]);

/// Spec 10 D24's fake: no grips, no reshape; [movable] is false for the
/// groups in [immovable] only, as a room's provider answers for a room.
final class _Movability implements ObjectGripProvider {
  _Movability([this.immovable = const {}]);

  final Set<Handle> immovable;

  @override
  bool movable(DraftDocument d, Handle group) => !immovable.contains(group);

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) => const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      null;

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      const [];
}

/// A root-level region whose boundary is invisible: its fill key is
/// outlined (spec 10 D24) but a move never captures a fill (03 D4).
Handle addHiddenBoundaryRegion(DraftDocument doc, List<double> coords) {
  final r = AddRegionCommand.allocate(
    seed: doc.handleSeed,
    owner: doc.rootHandle,
    boundaryKind: EntityKind.polyline,
    boundaryPayload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
    layer: ReservedHandles.layerZero,
    fillColor: const TrueColor(0x3366CC),
    boundaryColor: const ByLayerColor(),
  );
  doc.commands.execute(AddRegionCommand(
    fill: r.fill,
    boundary: r.boundary.copyWith(flags: EntityFlags.invisible),
    boundaryPayload: r.boundaryPayload,
  ));
  return r.fill.handle;
}

/// A fractional quadrilateral clear of every other OL5 fixture.
const List<double> kFillLoop = [
  7300.5, 2980.25, 7385.75, 2992.5, 7370.25, 3045.75, 7310.125, 3038.5, //
  7300.5, 2980.25,
];

void main() {
  testWidgets('a selection change repaints the overlay and not the canvas',
      (tester) async {
    // Criterion 6 / M-02e'. The overlay and the drawing are separate
    // `RepaintBoundary`s over separate `Listenable`s; a selection change must
    // not cost a re-render of the drawing.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final line = addEntity(doc, doc.rootHandle, EntityKind.line,
        [kDefaultOriginX + 10, 20, kDefaultOriginX + 110, 60], []);
    final r = rig(doc);

    var canvasPaints = 0;
    var overlayPaints = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 300,
          child: Stack(children: [
            RepaintBoundary(
                child: DraftCanvas(
              document: doc,
              index: r.index,
              camera: r.camera,
              onPaintForTest: () => canvasPaints++,
            )),
            Positioned.fill(
                child: RepaintBoundary(
                    child: CustomPaint(
              painter: r.overlay(onPaintForTest: () => overlayPaints++),
              size: Size.infinite,
            ))),
          ]),
        ),
      ),
    ));

    final overlayPaint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SelectionOverlayPainter);
    expect(tester.getSize(overlayPaint), kViewport,
        reason: 'the overlay must be laid out at the viewport size, not at '
            'zero — a zero-sized painter would pass every paint assertion '
            'below without drawing anything');

    final canvasBefore = canvasPaints;
    final overlayBefore = overlayPaints;
    expect(overlayBefore, greaterThan(0));
    expect(canvasBefore, greaterThan(0),
        reason: 'a canvas that never painted at all would satisfy the '
            '"unchanged" assertion below for the wrong reason');

    r.selection.replace([SelectionKey.root(line)]);
    await tester.pump();

    expect(overlayPaints, overlayBefore + 1,
        reason: 'the selection is in the overlay\'s repaint merge');
    expect(canvasPaints, canvasBefore,
        reason: 'the drawing does not know the selection exists');
  });

  testWidgets('a DocChange under a selected instance repaints the overlay',
      (tester) async {
    // A4. The cache rebuilds on every `DocChange`, but a rebuild that nothing
    // is listening to leaves the old outline on screen until the next
    // selection, hover or camera change. The cache is a `ChangeNotifier` in
    // the overlay's repaint merge; the canvas has its own document listener,
    // so both counts move — which is what separates this from M-02e', where
    // only the overlay does.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final def = addDefinition(doc, 'Def');
    final leaf = addEntity(doc, def, EntityKind.line, [3, 1, 9, 4], []);
    final instance = addInstance(doc, def, kPlacement);
    final r = rig(doc);

    var canvasPaints = 0;
    var overlayPaints = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 300,
          child: Stack(children: [
            RepaintBoundary(
                child: DraftCanvas(
              document: doc,
              index: r.index,
              camera: r.camera,
              onPaintForTest: () => canvasPaints++,
            )),
            Positioned.fill(
                child: RepaintBoundary(
                    child: CustomPaint(
              painter: r.overlay(onPaintForTest: () => overlayPaints++),
              size: Size.infinite,
            ))),
          ]),
        ),
      ),
    ));

    final key = SelectionKey.root(instance);
    r.selection.replace([key]);
    await tester.pump();
    final before = r.outlines.debugWorldSegmentsOf(key);
    expect(before, isNotNull);
    expect(before!.length, 4);
    final canvasBefore = canvasPaints;
    final overlayBefore = overlayPaints;
    expect(canvasBefore, greaterThan(0));
    expect(overlayBefore, greaterThan(0));

    doc.commands.execute(SetEntityGeometryCommand(
        leaf,
        GeometryPayload(
          coords: Float64List.fromList([3, 1, 9, 40]),
          scalars: Float64List(0),
        )));
    // `document.changes` delivers on a microtask; `idle` drains those inside
    // the test's fake-async zone (an awaited `Future.delayed` would deadlock
    // there), and the pump is the frame that repaints.
    await tester.idle();
    await tester.pump();

    expect(overlayPaints, overlayBefore + 1,
        reason: 'the cache notified, so the overlay repainted');
    expect(canvasPaints, canvasBefore + 1,
        reason: 'the canvas listens to the document itself — both move here, '
            'unlike a selection change');
    final after = r.outlines.debugWorldSegmentsOf(key);
    final moved = kPlacement.transformPoint(Vector2(9, 40));
    expect(after![3], closeTo(moved.y, 1e-9));
    expect((after[3] - before[3]).abs(), greaterThan(1.0),
        reason: 'the outline the repaint carried is the new one');
  });

  test('stroke width is 2 px at any zoom', () {
    // M-02m: the outline is stroked under the world→screen transform, so the
    // world width must be the screen width divided by the camera scale.
    final doc = DraftDocument.empty();
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 520], []);
    final r = rig(doc);
    r.camera.value = cameraAt(4.0, const Offset(-3900, 2100)).value;
    r.selection.replace([SelectionKey.root(line)]);

    final spy = SpyCanvas();
    r.overlay().paint(spy, kViewport);

    final drawn = spy.named('drawPath').toList();
    expect(drawn, hasLength(1));
    expect(
        drawn.single.strokeWidth, closeTo(kSelectionStrokePixels / 4.0, 1e-12));
    expect(drawn.single.color?.toARGB32(), kSelectionColor.toARGB32());
  });

  test('the two Paints are reused across frames', () {
    // M-02ab: a `Paint` allocated inside `paint` is an allocation at frame
    // rate, which the frame-path invariant forbids.
    final doc = DraftDocument.empty();
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 520], []);
    final other = addEntity(
        doc, doc.rootHandle, EntityKind.line, [900, 400, 940, 430], []);
    final r = rig(doc);
    r.camera.value = cameraAt(2.0, const Offset(-1800, 1400)).value;
    r.selection.replace([SelectionKey.root(line)]);
    r.selection.setHover(SelectionKey.root(other));
    final painter = r.overlay();

    final first = SpyCanvas();
    painter.paint(first, kViewport);
    final second = SpyCanvas();
    painter.paint(second, kViewport);

    final a = first.named('drawPath').toList();
    final b = second.named('drawPath').toList();
    expect(a, hasLength(2));
    expect(b, hasLength(2));
    expect(identical(paintOf(a[0]), paintOf(b[0])), isTrue,
        reason: 'the selected paint is a field, not a per-frame allocation');
    expect(identical(paintOf(a[1]), paintOf(b[1])), isTrue,
        reason: 'and so is the hover paint');
    expect(identical(paintOf(a[0]), paintOf(a[1])), isFalse,
        reason: 'the two are distinct paints, not one re-coloured');
  });

  test('hover on a selected key draws once', () {
    // M-02ac: hovering what is already selected must not double-stroke it.
    final doc = DraftDocument.empty();
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 520], []);
    final other = addEntity(
        doc, doc.rootHandle, EntityKind.line, [900, 400, 940, 430], []);
    final r = rig(doc);
    r.camera.value = cameraAt(2.0, const Offset(-1800, 1400)).value;
    final k = SelectionKey.root(line);
    r.selection.replace([k]);
    r.selection.setHover(k);
    final painter = r.overlay();

    final same = SpyCanvas();
    painter.paint(same, kViewport);
    expect(same.named('drawPath'), hasLength(1));
    expect(same.named('drawPath').single.color?.toARGB32(),
        kSelectionColor.toARGB32());

    r.selection.setHover(SelectionKey.root(other));
    final differing = SpyCanvas();
    painter.paint(differing, kViewport);
    final calls = differing.named('drawPath').toList();
    expect(calls, hasLength(2));
    expect(calls[0].color?.toARGB32(), kSelectionColor.toARGB32());
    expect(calls[1].color?.toARGB32(), kHoverColor.toARGB32());
    expect(calls[1].strokeWidth, closeTo(kHoverStrokePixels / 2.0, 1e-12));
  });

  test('the outline coincides with the drawn line at 4.5e6', () {
    // Criterion 14 / M-02v. The path is rebased, so it only lands on the
    // entity once the painter's matrix carries the origin back. The
    // fractional offset keeps the 0.01 px tolerance honest — a whole number
    // at 4.5e6 could land on a float32 value exactly.
    final doc = DraftDocument.empty();
    final x0 = kDefaultOriginX + 10.37;
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [x0, 20, x0 + 100, 20], []);
    final r = rig(doc);
    r.selection.replace([SelectionKey.root(line)]);

    final spy = SpyCanvas();
    r.overlay().paint(spy, kViewport);

    final m = matrixOf(spy);
    final path = spy.named('drawPath').single.args[0] as Path;
    // A straight horizontal segment: `getBounds` is exact for it.
    final bounds = path.getBounds();
    final left = through(m, bounds.left, bounds.top);
    final right = through(m, bounds.right, bounds.top);
    final start = r.camera.value.worldToScreen(Vector2(x0, 20));
    final end = r.camera.value.worldToScreen(Vector2(x0 + 100, 20));

    expect(left.dx, closeTo(start.x, 0.01));
    expect(left.dy, closeTo(start.y, 0.01));
    expect(right.dx, closeTo(end.x, 0.01));
    expect(right.dy, closeTo(end.y, 0.01));
    // The rebase is load-bearing: the path itself is nowhere near 4.5e6.
    expect(bounds.left.abs(), lessThan(1e4));
  });

  test('the outline coincides under a rotated, non-uniform camera', () {
    // Every other camera in this file is axis-aligned, so `m.b` and `m.c` are
    // both zero and the matrix's off-diagonal entries could be transposed,
    // swapped or dropped without a single test noticing. This one rotates and
    // scales the two axes differently, which makes `b != c`.
    final doc = DraftDocument.empty();
    final x0 = kDefaultOriginX + 10.37;
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [x0, 20, x0 + 100, 20], []);
    final r = rig(doc);

    const s = 1.5;
    final linear =
        Transform2.rotation(0.3).multiply(Transform2.scale(s, -2.4 * s));
    // Place the line's midpoint at the centre of the viewport, so the rebase
    // origin lands beside the geometry the way it does in a real frame.
    final mid = linear.transformPoint(Vector2(x0 + 50, 20));
    final w2s =
        Transform2.translation(200 - mid.x, 150 - mid.y).multiply(linear);
    expect((w2s.b - w2s.c).abs(), greaterThan(0.5),
        reason: 'the fixture is worthless unless the off-diagonal entries '
            'differ: a rotation composed with a *uniform* mirror-scale is '
            'symmetric (b == c), and a transposed matrix paints identically '
            'under it. At this asymmetry a transpose moves the outline by '
            'tens of pixels.');
    r.camera.value = ViewportTransform(worldToScreenMatrix: w2s);
    r.selection.replace([SelectionKey.root(line)]);

    final spy = SpyCanvas();
    r.overlay().paint(spy, kViewport);

    final m = matrixOf(spy);
    expect(m[1], isNot(closeTo(0, 1e-9)));
    expect(m[4], isNot(closeTo(0, 1e-9)));

    // The rotation lives in `m`, not in the path: in rebased space the
    // segment is still axis-aligned, so its bounds' two ends are exactly its
    // two endpoints and the comparison stays a point-to-point one.
    final path = spy.named('drawPath').single.args[0] as Path;
    final bounds = path.getBounds();
    expect(bounds.height, closeTo(0, 1e-6),
        reason: 'the rebased segment is horizontal; the camera is what tilts');
    final left = through(m, bounds.left, bounds.top);
    final right = through(m, bounds.right, bounds.top);
    final start = r.camera.value.worldToScreen(Vector2(x0, 20));
    final end = r.camera.value.worldToScreen(Vector2(x0 + 100, 20));

    expect(left.dx, closeTo(start.x, 0.01));
    expect(left.dy, closeTo(start.y, 0.01));
    expect(right.dx, closeTo(end.x, 0.01));
    expect(right.dy, closeTo(end.y, 0.01));
  });

  test("the tool's band is painted after the outlines, in screen space", () {
    final doc = DraftDocument.empty();
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 520], []);
    final r = rig(doc);
    r.camera.value = cameraAt(2.0, const Offset(-1800, 1400)).value;
    r.selection.replace([SelectionKey.root(line)]);

    // Empty space, then past the band slop: the tool enters `dragging`.
    r.tool.onPointerDown(ev(r.camera, const Offset(20, 20)), r.context);
    r.tool.onPointerMove(ev(r.camera, const Offset(180, 140)), r.context);
    expect(r.tool.phase, ToolPhase.dragging);

    final spy = SpyCanvas();
    r.overlay().paint(spy, kViewport);

    final names = [for (final c in spy.calls) c.name];
    expect(names, contains('drawRect'));
    expect(names.indexOf('drawRect'), greaterThan(names.indexOf('restore')),
        reason: 'the band is screen space; it must not ride the world matrix');
    expect(names.indexOf('drawPath'), lessThan(names.indexOf('restore')));
  });

  test('a selected point draws a screen-space cross on its position', () {
    // A point has no extent, so its `ui.Path` draws nothing; the overlay
    // reads `worldPointOf` and sizes a cross in pixels. The group placement
    // keeps the fixture off both the identity and the origin.
    final doc = DraftDocument.empty();
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    final dot = addEntity(doc, group, EntityKind.point, [13, -7], []);
    expect(dot, isNotNull);
    final r = rig(doc);
    r.camera.value = cameraAt(3.0, const Offset(-600, 900)).value;
    final k = SelectionKey.root(group);
    r.selection.replace([k]);

    final spy = SpyCanvas();
    r.overlay().paint(spy, kViewport);

    final lines = spy.named('drawLine').toList();
    expect(lines, hasLength(2),
        reason: 'one horizontal arm and one vertical arm');
    final world = r.outlines.worldPointOf(k)!;
    final centre = r.camera.value.worldToScreen(world);
    for (final call in lines) {
      final a = call.args[0] as Offset;
      final b = call.args[1] as Offset;
      expect((a.dx + b.dx) / 2, closeTo(centre.x, 0.01));
      expect((a.dy + b.dy) / 2, closeTo(centre.y, 0.01));
    }
    // Screen-space arms: the half-length is in pixels, not world units.
    final horizontal = lines.firstWhere((c) =>
        ((c.args[0] as Offset).dy - (c.args[1] as Offset).dy).abs() < 1e-9);
    final span =
        ((horizontal.args[0] as Offset).dx - (horizontal.args[1] as Offset).dx)
            .abs();
    expect(span, closeTo(6 * kSelectionStrokePixels, 1e-9));
    expect(lines.first.strokeWidth, closeTo(kSelectionStrokePixels, 1e-12));
  });

  test('the screen-space pass is clipped to the viewport', () {
    // The world pass's `restore()` pops its clip. Without a second one, a
    // selected point just off screen paints its cross — and the active tool
    // paints its overlay — over whatever sibling widget sits beside the
    // canvas, outside the bounds the overlay was given.
    final doc = DraftDocument.empty();
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    addEntity(doc, group, EntityKind.point, [13, -7], []);
    final r = rig(doc);
    r.camera.value = cameraAt(3.0, const Offset(-600, 900)).value;
    final k = SelectionKey.root(group);
    r.selection.replace([k]);

    const small = Size(40, 30);
    final centre = r.camera.value.worldToScreen(r.outlines.worldPointOf(k)!);
    expect(
        centre.x < 0 ||
            centre.y < 0 ||
            centre.x > small.width ||
            centre.y > small.height,
        isTrue,
        reason: 'the fixture only proves anything if the cross lands outside '
            'the painter’s own bounds');

    final spy = SpyCanvas();
    r.overlay().paint(spy, small);

    final names = [for (final c in spy.calls) c.name];
    final firstLine = names.indexOf('drawLine');
    expect(firstLine, greaterThanOrEqualTo(0), reason: 'the cross is drawn');
    final clipBefore = names.sublist(0, firstLine).lastIndexOf('clipRect');
    expect(clipBefore, greaterThanOrEqualTo(0));
    expect(names.sublist(clipBefore, firstLine), isNot(contains('restore')),
        reason: 'the clip must still be in effect when the cross is drawn');
    expect(spy.calls[clipBefore].args[0], Offset.zero & small);
  });

  test('a zero-size paint draws nothing and leaves the cache rebased', () {
    // `ViewportTransform.fit` documents the zero-size layout passes that
    // produce this. `visibleWorld(Size.zero)` collapses to a point, so
    // `rebaseOriginFor` answers the origin — and a `pathFor(key, zero)` would
    // rebuild every cached path in **absolute** world space, putting x = 4.5e6
    // into float32 `ui.Path` and forcing another full rebuild next frame.
    final doc = DraftDocument.empty();
    final line = addEntity(doc, doc.rootHandle, EntityKind.line,
        [kDefaultOriginX + 10.37, 20, kDefaultOriginX + 110.37, 20], []);
    final r = rig(doc);
    r.selection.replace([SelectionKey.root(line)]);
    expect(r.outlines.debugRebuilds, 0,
        reason: 'nothing has asked the cache for a path yet');

    final spy = SpyCanvas();
    r.overlay().paint(spy, Size.zero);

    expect(spy.named('drawPath'), isEmpty);
    expect(spy.named('transform'), isEmpty);
    expect(r.outlines.debugRebuilds, 0,
        reason: 'and the cache was never asked to rebase by the origin');

    // Not a painter that has simply stopped drawing.
    final real = SpyCanvas();
    r.overlay().paint(real, kViewport);
    expect(real.named('drawPath'), hasLength(1));
    expect(r.outlines.debugRebuilds, 1);
  });

  test('shouldRepaint is false', () {
    // The `repaint` listenable is the only trigger. Answering true here
    // repaints the overlay on every ancestor rebuild — the cost the second
    // `RepaintBoundary` exists to avoid, and nothing else in this file
    // would notice.
    final doc = DraftDocument.empty();
    final r = rig(doc);
    expect(r.overlay().shouldRepaint(r.overlay()), isFalse);
  });

  test('OL5 the move preview strokes only the keys the move moves', () {
    // Spec 10 D24, R-31. Three root-level groups, each turned and off the
    // origin: A and B own a line, P owns a lone point (its preview is a
    // cross, not a path). A drag on A's body moves the selection; a key the
    // provider calls immovable stays behind, so its outline must not ride
    // the drag's `T`.
    const view = Size(800, 600);
    ({
      Handle a,
      Handle b,
      Handle p,
      Handle f,
      List<RecordedCall> previewPaths,
      List<RecordedCall> previewLines,
      Map<Handle, Path?> paths,
      Offset crossAt,
    }) dragOnA(ObjectGripProvider? objects, {required bool withCache}) {
      final doc = DraftDocument.empty();
      Handle group(double x, double y, double turn) => addGroup(
          doc,
          doc.rootHandle,
          Transform2.translation(x, y).multiply(Transform2.rotation(turn)));
      final a = group(7010.5, 3020.25, 0.35);
      addEntity(doc, a, EntityKind.line, [0, 0, 120.5, 0], []);
      final b = group(7250.75, 3160.5, -0.6);
      addEntity(doc, b, EntityKind.line, [0, 0, 90.25, 0], []);
      final p = group(7120.25, 3260.75, 1.1);
      addEntity(doc, p, EntityKind.point, [4.5, -2.25], []);
      // F: a root-level fill whose boundary is hidden, selected directly.
      final f = addHiddenBoundaryRegion(doc, kFillLoop);
      doc.commands.clearHistory();

      final index = SpatialIndex(doc);
      final selection = SelectionController(doc);
      final outlines = OutlineCache(doc, selection);
      final grips = withCache
          ? GripCache(doc, selection, outlines, objects: objects)
          : null;
      final camera = CameraController(ViewportTransform(
          worldToScreenMatrix: Transform2.translation(400.37, 300.61)
              .multiply(Transform2.rotation(0.2))
              .multiply(Transform2.scale(1.3, -1.3))
              .multiply(Transform2.translation(-7150, -3150))));
      final tool = SelectTool();
      final context = ToolContext(
          document: doc,
          index: index,
          camera: camera,
          selection: selection,
          grips: grips);
      final tools = ToolController(initial: tool, context: context);
      addTearDown(() {
        tools.dispose();
        grips?.dispose();
        outlines.dispose();
        camera.dispose();
        selection.dispose();
        index.dispose();
      });

      final keys = [SelectionKey.root(a), SelectionKey.root(b)];
      selection.replace([...keys, SelectionKey.root(p), SelectionKey.root(f)]);
      final body =
          doc.tree.accumulatedTransform(a).transformPoint(Vector2(60.25, 0));
      final press = camera.value.worldToScreen(body);
      final from = Offset(press.x, press.y);
      tool.onPointerDown(ev(camera, from), context);
      tool.onPointerMove(ev(camera, from + const Offset(60, -35)), context);
      expect(tool.dragKind, DragKind.move, reason: 'a move drag on A');
      expect(tool.selectionPreviewTransform, isNotNull);

      final spy = SpyCanvas();
      SelectionOverlayPainter(
        selection: selection,
        tools: tools,
        camera: camera,
        outlines: outlines,
      ).paint(spy, view);
      final origin = rebaseOriginFor(camera.value.visibleWorld(view));
      bool preview(RecordedCall c) =>
          c.color?.toARGB32() == kPreviewColor.toARGB32();
      // The select tool's own guide line shares the colour at 1 px; a
      // point's preview cross is stroked at the preview width.
      bool cross(RecordedCall c) =>
          preview(c) && c.strokeWidth == kPreviewStrokePixels;
      final dot = tool.selectionPreviewTransform!.transformPoint(
          doc.tree.accumulatedTransform(p).transformPoint(Vector2(4.5, -2.25)));
      final dotOnScreen = camera.value.worldToScreen(dot);
      return (
        a: a,
        b: b,
        p: p,
        f: f,
        previewPaths: spy.named('drawPath').where(preview).toList(),
        previewLines: spy.named('drawLine').where(cross).toList(),
        crossAt: Offset(dotOnScreen.x, dotOnScreen.y),
        paths: {
          for (final h in [a, b, p, f])
            h: outlines.pathFor(SelectionKey.root(h), origin),
        },
      );
    }

    List<Path?> drawnPaths(List<RecordedCall> calls) =>
        [for (final c in calls) c.args[0] as Path?];

    // B and P immovable: A's path alone, and no cross for P.
    final some = dragOnA(_Movability({}), withCache: true);
    final mixed = dragOnA(_Movability({some.b, some.p}), withCache: true);
    expect(mixed.paths.values, everyElement(isNotNull));
    expect(mixed.paths[mixed.f]!.getBounds().width, greaterThan(10),
        reason: "the premise: F's fill key is outlined");
    expect(drawnPaths(mixed.previewPaths), hasLength(1));
    expect(
        identical(drawnPaths(mixed.previewPaths).single, mixed.paths[mixed.a]),
        isTrue,
        reason: "the preview strokes A's path and nothing else");
    expect(mixed.previewLines, isEmpty, reason: "P's cross stays behind");

    // The controls: a provider calling every group movable previews all
    // three groups, and never the fill F, which the move does not capture;
    // with no grip cache every key is drawn, F too, as before 10.
    for (final (name, run, moved) in [
      ('a provider calling all movable', some, 3),
      ('no grip cache', dragOnA(null, withCache: false), 4),
    ]) {
      final drawn = drawnPaths(run.previewPaths);
      expect(drawn, hasLength(moved), reason: name);
      for (final h in [run.a, run.b, run.p, if (moved == 4) run.f]) {
        expect(drawn.where((d) => identical(d, run.paths[h])), hasLength(1),
            reason: '$name: ${h.toHex()}');
      }
      expect(run.previewLines, hasLength(2), reason: "$name: P's cross");
      for (final line in run.previewLines) {
        final mid = ((line.args[0] as Offset) + (line.args[1] as Offset)) / 2;
        expect((mid - run.crossAt).distance, lessThan(1e-6),
            reason: "$name: the cross sits on P's point under T");
      }
    }

    // The answer is the last rebuild's: a key the provider stops calling
    // movable leaves the set at the next rebuild, and a key that left the
    // selection is not movable.
    final doc = DraftDocument.empty();
    final a = addGroup(doc, doc.rootHandle, Transform2.translation(7010, 3020));
    addEntity(doc, a, EntityKind.line, [0, 0, 120.5, 0], []);
    final b = addGroup(doc, doc.rootHandle, Transform2.translation(7250, 3160));
    addEntity(doc, b, EntityKind.line, [0, 0, 90.25, 0], []);
    final immovable = <Handle>{};
    final selection = SelectionController(doc);
    final outlines = OutlineCache(doc, selection);
    final grips =
        GripCache(doc, selection, outlines, objects: _Movability(immovable));
    addTearDown(() {
      grips.dispose();
      outlines.dispose();
      selection.dispose();
    });
    final ka = SelectionKey.root(a), kb = SelectionKey.root(b);
    // A fill key alone is outlined but not movable, so there is nothing to
    // rotate; beside a movable group the rotation grip is back.
    final kf = SelectionKey.root(addHiddenBoundaryRegion(doc, kFillLoop));
    selection.replace([kf]);
    expect(grips.box, isNotNull, reason: 'the premise: the fill is outlined');
    expect(grips.isMovable(kf), isFalse);
    expect(grips.rotatable, isFalse, reason: 'a fill alone');
    selection.replace([ka, kf]);
    expect(grips.isMovable(ka), isTrue);
    expect(grips.isMovable(kf), isFalse);
    expect(grips.rotatable, isTrue, reason: 'a movable group beside it');
    selection.replace([ka, kb]);
    expect(grips.isMovable(kb), isTrue);
    immovable.add(b);
    selection.replace([ka]);
    expect(grips.isMovable(kb), isFalse, reason: 'no longer selected');
    selection.replace([ka, kb]);
    expect(grips.isMovable(ka), isTrue);
    expect(grips.isMovable(kb), isFalse, reason: 'immovable since');
  });
}
