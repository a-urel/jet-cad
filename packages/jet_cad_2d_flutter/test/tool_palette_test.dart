// Dark theme spec D5 "Tools", Task 3 (M-DT-8, F-5): both tool paint methods
// take the overlay's `PaperPalette`, and every tool colours its band, guide,
// reshape preview and snap marker from it, in the method that draws them.
//
// Fixtures (spec, Testing): the document carries a Blueprint page, and the
// overlay's set is `PaperPalette.forPaper(page.background)`, as the planner
// computes it. The camera is 03's `gripCamera` (zoomed, rotated, y flipped,
// panned far from the origin, so the rebase origin is non-zero). Each frame
// goes through `SelectionOverlayPainter`, so a painter that hands the tool
// anything but its own set shows too. White paper is only the control, on
// the same tool instance right after the Blueprint frame, so a colour
// assigned once and never again shows as well.
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart' show Listenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/canvas_palette.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';

import 'support/draw_fixture.dart';
import 'support/grip_fixture.dart';
import 'support/spy_canvas.dart';

const int kBlueprint = 0xFF1F3A5F;
const int kWhite = 0xFFFFFFFF;
const Size kView = Size(800, 600);

/// A 1:20 page anchored at (7000, 3000) on [background]; no grid snap, so
/// a drag lands where the test puts it.
PageComponent pageOn(int background) => PageComponent(
    scaleDenominator: 20,
    originX: 7000,
    originY: 3000,
    background: background,
    snapToGrid: false);

/// The overlay's set for the page [doc] carries, as the planner picks it.
PaperPalette paperOf(DraftDocument doc) => PaperPalette.forPaper(
    doc.components.get<PageComponent>(doc.rootHandle)!.background);

void setPaper(DraftDocument doc, int background) {
  final page = doc.components.get<PageComponent>(doc.rootHandle)!;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, page.copyWith(background: background)));
}

/// One overlay frame onto [canvas], with [paper] handed to the painter.
void overlayFrame(
  Canvas canvas, {
  required SelectionController selection,
  required ToolController tools,
  required CameraController camera,
  required OutlineCache outlines,
  required PaperPalette paper,
}) =>
    SelectionOverlayPainter(
      selection: selection,
      tools: tools,
      camera: camera,
      outlines: outlines,
      paper: paper,
      repaint: Listenable.merge([selection, tools, camera]),
    ).paint(canvas, kView);

int? argbOf(RecordedCall c) => c.color?.toARGB32();

/// Every colour of [paper]'s fields, as ARGB.
Set<int> setOf(PaperPalette p) => {
      for (final c in [
        p.minorGrid,
        p.majorGrid,
        p.pageBreak,
        p.selection,
        p.hover,
        p.windowBand,
        p.crossingBand,
        p.grip,
        p.gripMove,
        p.gripHot,
        p.preview,
        p.snap,
      ])
        c.toARGB32(),
    };

/// No call of [spy] carries a colour of the other set than [paper]'s.
void expectOnlySet(SpyCanvas spy, PaperPalette paper, String why) {
  final other = setOf(identical(paper, PaperPalette.dark)
      ? PaperPalette.light
      : PaperPalette.dark);
  final wrong = [
    for (final c in spy.calls)
      if (argbOf(c) != null && other.contains(argbOf(c)))
        '${c.name} 0x${argbOf(c)!.toRadixString(16)}',
  ];
  expect(wrong, isEmpty, reason: '$why: a colour of the other set');
}

/// [paint] onto a Blueprint-filled picture of [kView], read back as RGBA.
Future<({Uint8List bytes, int width})> rasterise(
    void Function(Canvas) paint) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
      Offset.zero & kView, Paint()..color = const Color(kBlueprint));
  paint(canvas);
  final picture = recorder.endRecording();
  final image =
      await picture.toImage(kView.width.toInt(), kView.height.toInt());
  final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
  image.dispose();
  picture.dispose();
  return (bytes: data.buffer.asUint8List(), width: kView.width.toInt());
}

typedef Rgb = (int, int, int);

Rgb pixelAt(({Uint8List bytes, int width}) shot, int x, int y) {
  final i = (y * shot.width + x) * 4;
  return (shot.bytes[i], shot.bytes[i + 1], shot.bytes[i + 2]);
}

Matcher nearRgb(Rgb want, {int tolerance = 3}) => predicate<Rgb>(
    (c) =>
        (c.$1 - want.$1).abs() <= tolerance &&
        (c.$2 - want.$2).abs() <= tolerance &&
        (c.$3 - want.$3).abs() <= tolerance,
    'within $tolerance of $want');

Rgb rgbOf(int argb) => ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

/// [top] at [alpha] / 255 over the opaque [under], channel by channel.
Rgb over(int top, int alpha, int under) {
  final (tr, tg, tb) = rgbOf(top);
  final (ur, ug, ub) = rgbOf(under);
  int mix(int t, int u) => (u + (t - u) * alpha / 255).round();
  return (mix(tr, ur), mix(tg, ug), mix(tb, ub));
}

/// A grip rig over a Blueprint page.
GripRig blueprintGripRig({bool objectSnap = false}) {
  final s = gripScene(page: pageOn(kBlueprint));
  final rig = gripRig(s.document, objectSnap: objectSnap);
  rig.selection.replace([SelectionKey.root(s.line)]);
  return rig;
}

/// A band drag from [from] to [to], over empty paper.
GripRig bandRig(Offset from, Offset to) {
  final s = gripScene(page: pageOn(kBlueprint));
  final rig = gripRig(s.document);
  pressAndMove(rig, from, to);
  expect(rig.tool.pressClass, PressClass.empty, reason: 'premise: on paper');
  expect(rig.tool.bandScreen, Rect.fromPoints(from, to), reason: 'premise');
  return rig;
}

void frameOf(GripRig rig, Canvas canvas, PaperPalette paper) =>
    overlayFrame(canvas,
        selection: rig.selection,
        tools: rig.tools,
        camera: rig.camera,
        outlines: rig.outlines,
        paper: paper);

/// The one line of [spy] that starts at [from]: a stretch's guide.
RecordedCall guideOf(SpyCanvas spy, Offset from) => spy
    .named('drawLine')
    .where((c) => ((c.args[0]! as Offset) - from).distance < 1e-6)
    .single;

// The band's corners sit on half pixels, so its 1 px stroke covers whole
// pixel columns and rows: x = 20 and 200 are the stroke, (100, 70) the
// fill alone.
const Offset kBandTopLeft = Offset(20.5, 20.5);
const Offset kBandBottomRight = Offset(200.5, 120.5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('premise: the Blueprint page takes the dark set, White the light', () {
    final s = gripScene(page: pageOn(kBlueprint));
    expect(identical(paperOf(s.document), PaperPalette.dark), isTrue);
    setPaper(s.document, kWhite);
    expect(identical(paperOf(s.document), PaperPalette.light), isTrue);
  });

  group('M-DT-8: SelectTool', () {
    test(
        'the window band (paintOverlay): stroke 0x7FB2FF, fill at the band '
        'alpha, on Blueprint; the light set on White', () {
      final rig = bandRig(kBandTopLeft, kBandBottomRight);
      expect(rig.tool.bandMode, BandMode.window, reason: 'premise');
      final paper = paperOf(rig.document);
      for (final (p, stroke) in [
        (paper, 0xFF7FB2FF),
        (PaperPalette.light, 0xFF1E6FE8),
      ]) {
        final spy = SpyCanvas();
        frameOf(rig, spy, p);
        final rects = spy.named('drawRect').toList();
        expect(rects, hasLength(2), reason: 'the fill, then the stroke');
        expect(argbOf(rects[0]), (stroke & 0xFFFFFF) | (kBandFillAlpha << 24),
            reason: 'the fill');
        expect(rects[1].paintingStyle, PaintingStyle.stroke);
        expect(argbOf(rects[1]), stroke, reason: 'the stroke');
        expectOnlySet(spy, p, 'window band');
      }
    });

    test('the window band in pixels on Blueprint: the stroke is 0x7FB2FF',
        () async {
      final rig = bandRig(kBandTopLeft, kBandBottomRight);
      final shot =
          await rasterise((c) => frameOf(rig, c, paperOf(rig.document)));
      expect(pixelAt(shot, 20, 70), nearRgb(rgbOf(0xFF7FB2FF)),
          reason: 'the left edge');
      expect(pixelAt(shot, 200, 70), nearRgb(rgbOf(0xFF7FB2FF)),
          reason: 'the right edge');
      expect(pixelAt(shot, 100, 70),
          nearRgb(over(0xFF7FB2FF, kBandFillAlpha, kBlueprint)),
          reason: 'the fill over the paper');
      expect(pixelAt(shot, 300, 70), nearRgb(rgbOf(kBlueprint)),
          reason: 'control: the bare paper outside the band');
    });

    test(
        'the crossing band (paintOverlay): dashes 0x5FD68F, fill at the band '
        'alpha, on Blueprint; the light set on White', () {
      final rig = bandRig(kBandBottomRight, kBandTopLeft);
      expect(rig.tool.bandMode, BandMode.crossing, reason: 'premise');
      final paper = paperOf(rig.document);
      for (final (p, stroke) in [
        (paper, 0xFF5FD68F),
        (PaperPalette.light, 0xFF2E9E5B),
      ]) {
        final spy = SpyCanvas();
        frameOf(rig, spy, p);
        final fill = spy.named('drawRect').single;
        expect(argbOf(fill), (stroke & 0xFFFFFF) | (kBandFillAlpha << 24),
            reason: 'the fill');
        final dashes = spy.named('drawPath').single;
        expect(dashes.paintingStyle, PaintingStyle.stroke);
        expect(argbOf(dashes), stroke, reason: 'the dashes');
        expectOnlySet(spy, p, 'crossing band');
      }
    });

    test(
        'a stretch: the guide (paintOverlay) is 0xFFC857 and the snap marker '
        '0x5FD68F on Blueprint; the light set on White', () {
      final rig = blueprintGripRig(objectSnap: true);
      final vertex = screenOf(rig.camera, 7130, 3060);
      final endpoint = screenOf(rig.camera, 7130, 3100);
      pressAndMove(rig, vertex, endpoint + const Offset(3, -2));
      expect(rig.tool.dragKind, DragKind.reshape, reason: 'premise');
      final paper = paperOf(rig.document);
      for (final (p, preview, snap) in [
        (paper, 0xFFFFC857, 0xFF5FD68F),
        (PaperPalette.light, 0xFFE8A11E, 0xFF2E9E5B),
      ]) {
        final spy = SpyCanvas();
        frameOf(rig, spy, p);
        // The guide runs from the grabbed vertex; the rotation grip's stem
        // is a line too.
        final guide = guideOf(spy, vertex);
        expect(argbOf(guide), preview, reason: 'the guide');
        final marker = spy.named('drawRect').single;
        expect((marker.args[0]! as Rect).center.dx, closeTo(endpoint.dx, 1e-6),
            reason: 'premise: the endpoint square');
        expect(argbOf(marker), snap, reason: 'the snap marker');
        expectOnlySet(spy, p, 'stretch');
      }
    });

    test(
        'a move: the guide (paintOverlay) is 0xFFC857 on Blueprint; the '
        'light set on White', () {
      // A move draws no reshape preview, so `paintWorldOverlay` returns
      // early: the guide's colour must be set where the guide is drawn.
      final rig = blueprintGripRig();
      final mid = screenOf(rig.camera, 7070, 3040); // the line's move grip
      pressAndMove(rig, mid, mid + const Offset(30, -20));
      expect(rig.tool.dragKind, DragKind.move, reason: 'premise');
      final paper = paperOf(rig.document);
      for (final (p, preview) in [
        (paper, 0xFFFFC857),
        (PaperPalette.light, 0xFFE8A11E),
      ]) {
        final spy = SpyCanvas();
        frameOf(rig, spy, p);
        expect(argbOf(guideOf(spy, mid)), preview, reason: 'the guide');
        expectOnlySet(spy, p, 'move');
      }
    });

    test(
        'a stretch: the reshape preview (paintWorldOverlay) is 0xFFC857 on '
        'Blueprint; the light set on White', () {
      final rig = blueprintGripRig();
      final vertex = screenOf(rig.camera, 7130, 3060);
      pressAndMove(rig, vertex, vertex + const Offset(25, -18));
      expect(rig.tool.dragKind, DragKind.reshape, reason: 'premise');
      final paper = paperOf(rig.document);
      for (final (p, preview) in [
        (paper, 0xFFFFC857),
        (PaperPalette.light, 0xFFE8A11E),
      ]) {
        final spy = SpyCanvas();
        frameOf(rig, spy, p);
        final names = [for (final c in spy.calls) c.name];
        final paths = spy.named('drawPath').toList();
        expect(paths, hasLength(2), reason: 'the selected outline, then it');
        expect(argbOf(paths[0]), p.selection.toARGB32(), reason: 'premise');
        final at = spy.calls.indexOf(paths[1]);
        expect(at, lessThan(names.indexOf('restore')),
            reason: 'premise: drawn under the world matrix');
        expect(argbOf(paths[1]), preview, reason: 'the reshape preview');
        expectOnlySet(spy, p, 'reshape');
      }
    });

    test(
        'its guide, marker and preview Paints are fields: the same objects '
        'on the next frame, recoloured', () {
      final rig = blueprintGripRig(objectSnap: true);
      final vertex = screenOf(rig.camera, 7130, 3060);
      final endpoint = screenOf(rig.camera, 7130, 3100);
      pressAndMove(rig, vertex, endpoint + const Offset(3, -2));
      Paint paintOf(SpyCanvas s, String name, int i) =>
          s.named(name).toList()[i].args.whereType<Paint>().single;
      final a = SpyCanvas(), b = SpyCanvas();
      frameOf(rig, a, PaperPalette.dark);
      frameOf(rig, b, PaperPalette.light);
      Paint guidePaint(SpyCanvas s) =>
          guideOf(s, vertex).args.whereType<Paint>().single;
      expect(identical(guidePaint(a), guidePaint(b)), isTrue,
          reason: 'the guide');
      expect(identical(paintOf(a, 'drawRect', 0), paintOf(b, 'drawRect', 0)),
          isTrue,
          reason: 'the marker');
      expect(identical(paintOf(a, 'drawPath', 1), paintOf(b, 'drawPath', 1)),
          isTrue,
          reason: 'the reshape preview');
    });
  });

  group('M-DT-8: the line tool (PlacementTool)', () {
    /// A line started at (7010, 3020) and hovered near the anchor's start,
    /// on a Blueprint page: the band runs to the snapped endpoint, which
    /// shows its square.
    DrawRig lineRig() {
      final s = drawScene();
      setPaper(s.document, kBlueprint);
      final rig = drawRig(s.document, LineTool());
      clickAt(rig, screenOf(rig.camera, 7010, 3020));
      hoverAt(
          rig, screenOf(rig.camera, kAnchorX, kAnchorY) + const Offset(2, 2));
      expect(rig.tool.hoverKind, SnapKind.endpoint, reason: 'premise');
      return rig;
    }

    void lineFrame(DrawRig rig, Canvas canvas, PaperPalette paper) =>
        overlayFrame(canvas,
            selection: rig.selection,
            tools: rig.tools,
            camera: rig.camera,
            outlines: rig.outlines,
            paper: paper);

    test(
        'the rubber band (paintWorldOverlay) is 0xFFC857 and the snap marker '
        '(paintOverlay) 0x5FD68F on Blueprint; the light set on White', () {
      final rig = lineRig();
      final paper = paperOf(rig.document);
      for (final (p, band, snap) in [
        (paper, 0xFFFFC857, 0xFF5FD68F),
        (PaperPalette.light, 0xFFE8A11E, 0xFF2E9E5B),
      ]) {
        final spy = SpyCanvas();
        lineFrame(rig, spy, p);
        final names = [for (final c in spy.calls) c.name];
        final path = spy.named('drawPath').single;
        expect(spy.calls.indexOf(path), lessThan(names.indexOf('restore')),
            reason: 'premise: the band, under the world matrix');
        expect(argbOf(path), band, reason: 'the rubber band');
        expect(argbOf(spy.named('drawRect').single), snap,
            reason: 'the snap marker');
        expectOnlySet(spy, p, 'line tool');
      }
    });

    test(
        'its band and marker Paints are fields: the same objects on the next '
        'frame, recoloured', () {
      final rig = lineRig();
      final a = SpyCanvas(), b = SpyCanvas();
      lineFrame(rig, a, PaperPalette.dark);
      lineFrame(rig, b, PaperPalette.light);
      Paint paintOf(SpyCanvas s, String name) =>
          s.named(name).single.args.whereType<Paint>().single;
      expect(identical(paintOf(a, 'drawPath'), paintOf(b, 'drawPath')), isTrue,
          reason: 'the band');
      expect(identical(paintOf(a, 'drawRect'), paintOf(b, 'drawRect')), isTrue,
          reason: 'the marker');
      expect(identical(paintOf(a, 'drawPath'), rig.tool.bandPaint), isTrue);
    });
  });
}
