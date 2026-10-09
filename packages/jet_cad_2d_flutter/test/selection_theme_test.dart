// Host embedding API spec T-1's selection row, S-8 (Slice 3 plan Task 2):
// a host's selection colour and width reach the selection overlay through
// `PaperPalette.withSelection` and `SelectionOverlayPainter
// .selectionStrokePixels`. Every default is today's: the derivation of the
// hover reproduces both sets' own hover exactly, and the default width is
// `kSelectionStrokePixels` (P-6; `selection_overlay_test.dart` and
// `painter_palette_test.dart` pin today's look unedited).
//
// The fixtures are off the identity: a rotated, non-uniform camera, a
// point under a turned, scaled group, a colour none of the sets carries
// (`0xFFD81B60`) and a width that is not today's (4 px).
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart' show kDefaultOriginX;
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/canvas_palette.dart';
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

/// A selection colour none of the sets carries, and its translucent form.
const Color magenta = Color(0xFFD81B60);
const Color translucentMagenta = Color(0x80D81B60);

/// A width that is not today's.
const double themedWidth = 4.0;

/// The painter's collaborators, as `selection_overlay_test.dart`'s rig.
final class Rig {
  Rig(this.document) : selection = SelectionController(document) {
    index = SpatialIndex(document);
    outlines = OutlineCache(document, selection);
    camera =
        CameraController(ViewportTransform.fit(document.extents, kViewport));
    tool = SelectTool();
    context = ToolContext(
        document: document, index: index, camera: camera, selection: selection);
    tools = ToolController(initial: tool, context: context);
    addTearDown(() {
      tools.dispose();
      outlines.dispose();
      camera.dispose();
      selection.dispose();
      index.dispose();
    });
  }

  final DraftDocument document;
  final SelectionController selection;
  late final SpatialIndex index;
  late final OutlineCache outlines;
  late final CameraController camera;
  late final SelectTool tool;
  late final ToolContext context;
  late final ToolController tools;

  SelectionOverlayPainter overlay(
          {PaperPalette paper = PaperPalette.light, double? width}) =>
      width == null
          ? SelectionOverlayPainter(
              selection: selection,
              tools: tools,
              camera: camera,
              outlines: outlines,
              paper: paper)
          : SelectionOverlayPainter(
              selection: selection,
              tools: tools,
              camera: camera,
              outlines: outlines,
              paper: paper,
              selectionStrokePixels: width);
}

Paint paintOf(RecordedCall call) => call.args.whereType<Paint>().single;

/// The ten colours `withSelection` keeps, by name.
Map<String, Color> keptOf(PaperPalette p) => {
      'minorGrid': p.minorGrid,
      'majorGrid': p.majorGrid,
      'pageBreak': p.pageBreak,
      'windowBand': p.windowBand,
      'crossingBand': p.crossingBand,
      'grip': p.grip,
      'gripMove': p.gripMove,
      'gripHot': p.gripHot,
      'preview': p.preview,
      'snap': p.snap,
    };

/// The rotated, non-uniform camera of `selection_overlay_test.dart`'s
/// "the outline coincides under a rotated, non-uniform camera", centred on
/// the world point [centre].
ViewportTransform rotatedCamera(Vector2 centre) {
  const s = 1.5;
  final linear =
      Transform2.rotation(0.3).multiply(Transform2.scale(s, -2.4 * s));
  final mid = linear.transformPoint(centre);
  return ViewportTransform(
      worldToScreenMatrix:
          Transform2.translation(200 - mid.x, 150 - mid.y).multiply(linear));
}

/// The horizontal arm of a point cross: its length.
double horizontalSpan(List<RecordedCall> lines) {
  final h = lines.firstWhere((c) =>
      ((c.args[0] as Offset).dy - (c.args[1] as Offset).dy).abs() < 1e-9);
  return ((h.args[0] as Offset).dx - (h.args[1] as Offset).dx).abs();
}

void main() {
  group('PaperPalette.withSelection', () {
    test('the derivation is today\'s hover, exactly, for both sets', () {
      for (final set in [PaperPalette.light, PaperPalette.dark]) {
        final same = set.withSelection(set.selection);
        expect(same, set);
        expect(same.hover, set.hover);
        expect(same.hover.toARGB32(), set.hover.toARGB32());
        expect(identical(same, set), isFalse,
            reason: 'a copy; the planner hands the const set itself when '
                'the theme has no colour for it');
      }
    });

    test('T2-a: the hover is the given selection at 60% alpha', () {
      for (final set in [PaperPalette.light, PaperPalette.dark]) {
        final themed = set.withSelection(magenta);
        expect(themed.selection, magenta);
        expect(themed.hover.toARGB32(), 0x99D81B60);
        expect(themed.hover, isNot(set.hover));
        expect(themed, isNot(set));
      }
    });

    test('a translucent selection gives a hover at its alpha times 0.6', () {
      final themed = PaperPalette.light.withSelection(translucentMagenta);
      expect(themed.selection, translucentMagenta);
      expect(themed.hover.a, closeTo(0x80 / 0xFF * 0x99 / 0xFF, 1e-12));
      expect(themed.hover.a, closeTo(0x80 / 255 * 0.6, 1e-12));
      expect(themed.hover.r, translucentMagenta.r);
      expect(themed.hover.g, translucentMagenta.g);
      expect(themed.hover.b, translucentMagenta.b);
    });

    test('the ten other colours are the set\'s', () {
      for (final set in [PaperPalette.light, PaperPalette.dark]) {
        expect(keptOf(set.withSelection(magenta)), keptOf(set));
      }
      // The two sets differ in each of the ten, so a copy that took them
      // from the wrong set (or a constant) would show here.
      final light = keptOf(PaperPalette.light);
      final dark = keptOf(PaperPalette.dark);
      for (final name in light.keys) {
        expect(light[name], isNot(dark[name]), reason: name);
      }
    });
  });

  group('SelectionOverlayPainter.selectionStrokePixels', () {
    test('the default is kSelectionStrokePixels', () {
      final r = Rig(DraftDocument.empty());
      expect(r.overlay().selectionStrokePixels, kSelectionStrokePixels);
    });

    test(
        'at 4 px under a rotated, non-uniform camera the outline strokes '
        '4 / scale and the hover stays 1.5 / scale (T2-c)', () {
      final doc = DraftDocument.empty();
      final x0 = kDefaultOriginX + 10.37;
      final line = addEntity(
          doc, doc.rootHandle, EntityKind.line, [x0, 20, x0 + 100, 20], []);
      final other = addEntity(doc, doc.rootHandle, EntityKind.line,
          [x0 + 20, -15, x0 + 70, -40], []);
      final r = Rig(doc);
      r.camera.value = rotatedCamera(Vector2(x0 + 50, 20));
      final scale = r.camera.value.scale;
      final m = r.camera.value.worldToScreenMatrix;
      expect((m.b - m.c).abs(), greaterThan(0.5),
          reason: 'the camera rotates and scales its axes differently');
      expect((scale - 1).abs(), greaterThan(0.5),
          reason: 'a scale of 1 would hide a width left in screen pixels');
      r.selection.replace([SelectionKey.root(line)]);
      r.selection.setHover(SelectionKey.root(other));

      final spy = SpyCanvas();
      r
          .overlay(
              paper: PaperPalette.light.withSelection(magenta),
              width: themedWidth)
          .paint(spy, kViewport);

      final paths = spy.named('drawPath').toList();
      expect(paths, hasLength(2));
      expect(paths[0].strokeWidth, closeTo(themedWidth / scale, 1e-6));
      expect(paths[0].color?.toARGB32(), 0xFFD81B60);
      expect(paths[1].strokeWidth, closeTo(kHoverStrokePixels / scale, 1e-6),
          reason: 'the hover keeps its width (S-8)');
      expect(paths[1].color?.toARGB32(), 0x99D81B60,
          reason: 'and takes the themed hue at 60%');
    });

    test(
        'at 4 px a selected point\'s cross is stroked 4 px with a 12 px '
        'half-length; a hovered point\'s stays 1.5 px and 4.5 px', () {
      final doc = DraftDocument.empty();
      final selectedGroup = addGroup(doc, doc.rootHandle, kPlacement);
      addEntity(doc, selectedGroup, EntityKind.point, [13, -7], []);
      final hoveredGroup = addGroup(doc, doc.rootHandle,
          Transform2.translation(40, 25).multiply(kPlacement));
      addEntity(doc, hoveredGroup, EntityKind.point, [-6, 11], []);
      final r = Rig(doc);
      r.camera.value = cameraAt(3.0, const Offset(-600, 900)).value;
      r.selection.replace([SelectionKey.root(selectedGroup)]);
      r.selection.setHover(SelectionKey.root(hoveredGroup));

      final spy = SpyCanvas();
      r.overlay(width: themedWidth).paint(spy, kViewport);

      final lines = spy.named('drawLine').toList();
      expect(lines, hasLength(4), reason: 'two arms per cross');
      final selected = [
        for (final c in lines)
          if (c.color?.toARGB32() == PaperPalette.light.selection.toARGB32()) c
      ];
      final hovered = [
        for (final c in lines)
          if (c.color?.toARGB32() == PaperPalette.light.hover.toARGB32()) c
      ];
      expect(selected, hasLength(2));
      expect(hovered, hasLength(2));
      expect(horizontalSpan(selected), closeTo(2 * 3 * themedWidth, 1e-9));
      expect(selected.first.strokeWidth, themedWidth);
      expect(
          horizontalSpan(hovered), closeTo(2 * 3 * kHoverStrokePixels, 1e-9));
      expect(hovered.first.strokeWidth, kHoverStrokePixels);
    });

    test('at 4 px the move preview\'s point cross has a 12 px half-length', () {
      // S-8: the preview cross's half-length reads the selection's width;
      // its stroke stays the preview's.
      final doc = DraftDocument.empty();
      final a = addGroup(
          doc,
          doc.rootHandle,
          Transform2.translation(7010.5, 3020.25)
              .multiply(Transform2.rotation(0.35)));
      addEntity(doc, a, EntityKind.line, [0, 0, 120.5, 0], []);
      final p = addGroup(
          doc,
          doc.rootHandle,
          Transform2.translation(7120.25, 3260.75)
              .multiply(Transform2.rotation(1.1)));
      addEntity(doc, p, EntityKind.point, [4.5, -2.25], []);
      final r = Rig(doc);
      r.camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2.translation(400.37, 300.61)
              .multiply(Transform2.rotation(0.2))
              .multiply(Transform2.scale(1.3, -1.3))
              .multiply(Transform2.translation(-7150, -3150)));
      r.selection.replace([SelectionKey.root(a), SelectionKey.root(p)]);
      final body =
          doc.tree.accumulatedTransform(a).transformPoint(Vector2(60.25, 0));
      final press = r.camera.value.worldToScreen(body);
      ToolPointerEvent at(Offset screen) => ToolPointerEvent(
            screen: screen,
            world: r.camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
            pointer: 1,
            buttons: kPrimaryButton,
            shift: false,
            control: false,
            meta: false,
            alt: false,
            pickRadiusWorld: kPickRadiusPixels / r.camera.value.scale,
          );
      final from = Offset(press.x, press.y);
      r.tool.onPointerDown(at(from), r.context);
      r.tool.onPointerMove(at(from + const Offset(60, -35)), r.context);
      expect(r.tool.dragKind, DragKind.move);
      expect(r.tool.selectionPreviewTransform, isNotNull);

      final spy = SpyCanvas();
      r.overlay(width: themedWidth).paint(spy, const Size(800, 600));
      final crosses = [
        for (final c in spy.named('drawLine'))
          if (c.color?.toARGB32() == PaperPalette.light.preview.toARGB32() &&
              c.strokeWidth == kPreviewStrokePixels)
            c
      ];
      expect(crosses, hasLength(2));
      expect(horizontalSpan(crosses), closeTo(2 * 3 * themedWidth, 1e-9));
    });

    test('shouldRepaint: true for a width alone, false for equal ones (T2-b)',
        () {
      final r = Rig(DraftDocument.empty());
      final themed = PaperPalette.light.withSelection(magenta);
      expect(
          r
              .overlay(paper: themed, width: themedWidth)
              .shouldRepaint(r.overlay(paper: themed)),
          isTrue,
          reason: 'the width alone changed');
      expect(r.overlay(width: themedWidth).shouldRepaint(r.overlay()), isTrue);
      expect(
          r.overlay(paper: themed, width: themedWidth).shouldRepaint(r.overlay(
              paper: PaperPalette.light.withSelection(magenta),
              width: themedWidth)),
          isFalse,
          reason: 'an equal, non-identical palette and an equal width');
      expect(
          r
              .overlay(paper: themed)
              .shouldRepaint(r.overlay(paper: PaperPalette.light)),
          isTrue,
          reason: 'the selection colour alone changed');
    });

    test(
        'the two Paints are reused across frames under a themed palette and '
        'width (S-1, the themed sibling of selection_overlay_test\'s)', () {
      final doc = DraftDocument.empty();
      final line = addEntity(
          doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 520], []);
      final other = addEntity(
          doc, doc.rootHandle, EntityKind.line, [900, 400, 940, 430], []);
      final r = Rig(doc);
      r.camera.value = cameraAt(2.0, const Offset(-1800, 1400)).value;
      r.selection.replace([SelectionKey.root(line)]);
      r.selection.setHover(SelectionKey.root(other));
      final painter = r.overlay(
          paper: PaperPalette.dark.withSelection(magenta), width: themedWidth);

      final first = SpyCanvas();
      painter.paint(first, kViewport);
      // A pan between the frames: the camera is in the repaint merge.
      r.camera.value = cameraAt(2.0, const Offset(-1750, 1420)).value;
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
      expect(identical(paintOf(a[0]), paintOf(a[1])), isFalse);
      for (final frame in [a, b]) {
        expect(frame[0].color?.toARGB32(), 0xFFD81B60);
        expect(frame[0].strokeWidth, closeTo(themedWidth / 2.0, 1e-12));
        expect(frame[1].color?.toARGB32(), 0x99D81B60);
        expect(frame[1].strokeWidth, closeTo(kHoverStrokePixels / 2.0, 1e-12));
      }
    });

    test('the width is asserted finite and above 0; 0.25 is accepted (R-2)',
        () {
      final r = Rig(DraftDocument.empty());
      for (final w in [0.0, -1.0, double.infinity, double.nan]) {
        expect(() => r.overlay(width: w), throwsAssertionError, reason: '$w');
      }
      expect(r.overlay(width: 0.25).selectionStrokePixels, 0.25);
    });
  });
}
