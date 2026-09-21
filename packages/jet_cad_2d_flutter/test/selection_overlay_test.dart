import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart' hide SelectionOverlay;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart' show kDefaultOriginX;
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draft_canvas.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
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

  SelectionOverlay overlay({void Function()? onPaintForTest}) =>
      SelectionOverlay(
        selection: selection,
        tools: tools,
        camera: camera,
        outlines: outlines,
        repaint: Listenable.merge([selection, tools, camera]),
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
        (w) => w is CustomPaint && w.painter is SelectionOverlay);
    expect(tester.getSize(overlayPaint), kViewport,
        reason: 'the overlay must be laid out at the viewport size, not at '
            'zero — a zero-sized painter would pass every paint assertion '
            'below without drawing anything');

    final canvasBefore = canvasPaints;
    final overlayBefore = overlayPaints;
    expect(overlayBefore, greaterThan(0));

    r.selection.replace([SelectionKey.root(line)]);
    await tester.pump();

    expect(overlayPaints, overlayBefore + 1,
        reason: 'the selection is in the overlay\'s repaint merge');
    expect(canvasPaints, canvasBefore,
        reason: 'the drawing does not know the selection exists');
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
    // entity once the painter's matrix carries the origin back.
    final doc = DraftDocument.empty();
    final line = addEntity(doc, doc.rootHandle, EntityKind.line,
        [kDefaultOriginX + 10, 20, kDefaultOriginX + 110, 20], []);
    final r = rig(doc);
    r.selection.replace([SelectionKey.root(line)]);

    final spy = SpyCanvas();
    r.overlay().paint(spy, kViewport);

    final m = spy.named('transform').single.args[0] as Float64List;
    final path = spy.named('drawPath').single.args[0] as Path;
    // A straight horizontal segment: `getBounds` is exact for it.
    final bounds = path.getBounds();
    Offset through(double x, double y) =>
        Offset(m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13]);

    final left = through(bounds.left, bounds.top);
    final right = through(bounds.right, bounds.top);
    final start =
        r.camera.value.worldToScreen(Vector2(kDefaultOriginX + 10, 20));
    final end =
        r.camera.value.worldToScreen(Vector2(kDefaultOriginX + 110, 20));

    expect(left.dx, closeTo(start.x, 0.01));
    expect(left.dy, closeTo(start.y, 0.01));
    expect(right.dx, closeTo(end.x, 0.01));
    expect(right.dy, closeTo(end.y, 0.01));
    // The rebase is load-bearing: the path itself is nowhere near 4.5e6.
    expect(bounds.left.abs(), lessThan(kDefaultOriginX / 2));
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

  test('shouldRepaint is false', () {
    // The `repaint` listenable is the only trigger. Answering true here
    // repaints the overlay on every ancestor rebuild — the cost the second
    // `RepaintBoundary` exists to avoid, and nothing else in this file
    // would notice.
    final doc = DraftDocument.empty();
    final r = rig(doc);
    expect(r.overlay().shouldRepaint(r.overlay()), isFalse);
  });
}
