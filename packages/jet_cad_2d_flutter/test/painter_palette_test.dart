// Dark theme spec D5, Task 2: the four painters and `RulerFrame` take their
// colours from the palettes they are handed, never from a constant.
//
// Fixtures (spec, Testing): Blueprint paper and the dark chrome, the
// off-origin page at 1:50 under a zoomed, panned camera
// (`support/page_fixture.dart`). White paper appears only as the control of
// a rule about the paper, always beside Blueprint, and in the dark chrome
// too, so the paper's set and the theme's set are never the same choice.
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart'
    show
        Center,
        CustomPaint,
        Directionality,
        GlobalKey,
        Key,
        Listenable,
        SizedBox,
        Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/page_fixture.dart';
import 'support/spy_canvas.dart';

const int kBlueprint = 0xFF1F3A5F;
const int kWhite = 0xFFFFFFFF;

/// [painter] onto a fresh picture of [size], read back as RGBA bytes.
/// Every sample below is taken where an opaque fill lies underneath, so the
/// premultiplied bytes are the straight colour.
Future<({Uint8List bytes, int width})> rasterise(
    void Function(Canvas) paint, Size size) async {
  final recorder = PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  final w = size.width.ceil(), h = size.height.ceil();
  final image = await picture.toImage(w, h);
  final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
  image.dispose();
  picture.dispose();
  return (bytes: data.buffer.asUint8List(), width: w);
}

typedef Rgb = (int, int, int);

Rgb pixelAt(({Uint8List bytes, int width}) shot, int x, int y) {
  final i = (y * shot.width + x) * 4;
  return (shot.bytes[i], shot.bytes[i + 1], shot.bytes[i + 2]);
}

double lum(Rgb c) => 0.2126 * c.$1 + 0.7152 * c.$2 + 0.0722 * c.$3;

/// The brightest (or darkest) pixel of the 3 x 3 block around (x, y), by
/// luminance: a 1 px line at a fractional position spreads over two pixels.
Rgb extreme(({Uint8List bytes, int width}) shot, int x, int y,
    {required bool brightest}) {
  Rgb? best;
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final c = pixelAt(shot, x + dx, y + dy);
      if (best == null ||
          (brightest ? lum(c) > lum(best) : lum(c) < lum(best))) {
        best = c;
      }
    }
  }
  return best!;
}

Rgb rgbOf(int argb) => ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

/// Within [tolerance] per channel of [argb]'s RGB.
Matcher nearRgb(int argb, {int tolerance = 3}) {
  final (r, g, b) = rgbOf(argb);
  return predicate<Rgb>(
      (c) =>
          (c.$1 - r).abs() <= tolerance &&
          (c.$2 - g).abs() <= tolerance &&
          (c.$3 - b).abs() <= tolerance,
      'within $tolerance of 0x${argb.toRadixString(16)}');
}

int? argbOf(RecordedCall c) => c.color?.toARGB32();

/// Equal to [p] field by field, but a different object: `shouldRepaint`
/// must compare by value.
ChromePalette chromeCopy(ChromePalette p) => ChromePalette(
      rulerBackground: Color(p.rulerBackground.toARGB32()),
      rulerInk: Color(p.rulerInk.toARGB32()),
      rulerPointer: Color(p.rulerPointer.toARGB32()),
      sheetEdge: Color(p.sheetEdge.toARGB32()),
    );

PaperPalette paperCopy(PaperPalette p) => PaperPalette(
      minorGrid: Color(p.minorGrid.toARGB32()),
      majorGrid: Color(p.majorGrid.toARGB32()),
      pageBreak: Color(p.pageBreak.toARGB32()),
      selection: Color(p.selection.toARGB32()),
      hover: Color(p.hover.toARGB32()),
      windowBand: Color(p.windowBand.toARGB32()),
      crossingBand: Color(p.crossingBand.toARGB32()),
      grip: Color(p.grip.toARGB32()),
      gripMove: Color(p.gripMove.toARGB32()),
      gripHot: Color(p.gripHot.toARGB32()),
      preview: Color(p.preview.toARGB32()),
      snap: Color(p.snap.toARGB32()),
    );

PageChromePainter chromePainter(
  PageComponent page, {
  required ChromePalette chrome,
  required PaperPalette paper,
  CameraController? camera,
}) =>
    PageChromePainter(
      camera: camera ?? standardCamera(),
      page: ValueNotifier<PageComponent?>(page),
      chrome: chrome,
      paper: paper,
    );

/// Vertical (x0 == x1) and horizontal (y0 == y1) lines of a recorded
/// `drawRawPoints` list.
(List<double>, List<double>) linesOf(RecordedCall call) {
  final p = call.args[1]! as Float32List;
  final xs = <double>[], ys = <double>[];
  for (var i = 0; i + 3 < p.length; i += 4) {
    if (p[i] == p[i + 2]) xs.add(p[i]);
    if (p[i + 1] == p[i + 3]) ys.add(p[i + 1]);
  }
  return (xs, ys);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageChromePainter', () {
    test('premise: Blueprint takes the dark paper set, White the light one',
        () {
      expect(identical(PaperPalette.forPaper(kBlueprint), PaperPalette.dark),
          isTrue);
      expect(
          identical(PaperPalette.forPaper(kWhite), PaperPalette.light), isTrue);
    });

    test(
        'M-DT-4: a major-grid pixel is lighter than the bare paper on '
        'Blueprint, darker on White (both in the dark chrome)', () async {
      for (final (paperArgb, lighter) in const [
        (kBlueprint, true),
        (kWhite, false),
      ]) {
        final page = standardPage().copyWith(background: paperArgb);
        final painter = chromePainter(page,
            chrome: ChromePalette.dark,
            paper: PaperPalette.forPaper(paperArgb));
        final spy = SpyCanvas();
        painter.paint(spy, kChromeSize);
        final raw = spy.named('drawRawPoints').toList();
        expect(raw, hasLength(2), reason: 'premise: minors then majors');
        final (majorXs, majorYs) = linesOf(raw.last);
        final (_, minorYs) = linesOf(raw.first);

        // The sheet's screen box under the standard camera: its left edge at
        // x = 395.45 and its bottom at y = 580.76, the rest off screen.
        final cam = standardCamera().value;
        final sheet = sheetWorldRect(page);
        final left = cam.worldToScreen(Vector2(sheet.minX, 0)).x;
        final bottom = cam.worldToScreen(Vector2(0, sheet.minY)).y;
        final x = majorXs.firstWhere((x) => x > left + 6 && x < 790,
            orElse: () => throw StateError('no major inside $majorXs'));
        // Midway between two horizontal lines of either pass, so the 3 x 3
        // block holds the vertical major and nothing else.
        final ys = [...majorYs, ...minorYs]..sort();
        double? y;
        for (var i = 0; i + 1 < ys.length; i++) {
          if (ys[i + 1] - ys[i] > 6 && ys[i] > 4 && ys[i + 1] < bottom - 4) {
            y = (ys[i] + ys[i + 1]) / 2;
            break;
          }
        }
        expect(y, isNotNull, reason: 'a gap between horizontal lines');

        final shot =
            await rasterise((c) => painter.paint(c, kChromeSize), kChromeSize);
        final paper = rgbOf(paperArgb);
        final ix = x.floor(), iy = y!.floor();
        if (lighter) {
          final c = extreme(shot, ix, iy, brightest: true);
          expect(lum(c), greaterThan(lum(paper) + 8),
              reason: 'paper 0x${paperArgb.toRadixString(16)}: $c at '
                  '($ix, $iy) against the bare paper $paper');
        } else {
          final c = extreme(shot, ix, iy, brightest: false);
          expect(lum(c), lessThan(lum(paper) - 8),
              reason: 'paper 0x${paperArgb.toRadixString(16)}: $c at '
                  '($ix, $iy) against the bare paper $paper');
        }
      }
    });

    test('the grid Paints carry the paper set, minor and major', () {
      for (final paper in [PaperPalette.dark, PaperPalette.light]) {
        final painter = chromePainter(
            standardPage().copyWith(background: kBlueprint),
            chrome: ChromePalette.dark,
            paper: paper);
        final spy = SpyCanvas();
        painter.paint(spy, kChromeSize);
        final raw = spy.named('drawRawPoints').toList();
        expect(raw, hasLength(2));
        expect(argbOf(raw.first), paper.minorGrid.toARGB32(), reason: 'minor');
        expect(argbOf(raw.last), paper.majorGrid.toARGB32(), reason: 'major');
      }
    });

    test(
        'M-DT-5: on Blueprint a page-break pixel is the dark set\'s '
        '0x8AB4F8, blue dominant and lighter than the paper', () async {
      // A camera of its own (0.05 px/mm, panned) that puts the sheet's left
      // edge, where a break runs, at x = 300.5: the 1 px break then covers
      // column 300 exactly, and the break is drawn over the edge stroke.
      const s = 0.05;
      final camera = CameraController(ViewportTransform(
          worldToScreenMatrix:
              const Transform2(s, 0, 0, -s, 300.5 - s * 7350, 439)));
      final page = standardPage().copyWith(
          background: kBlueprint, pageBreaks: true, gridVisible: false);
      final painter = chromePainter(page,
          chrome: ChromePalette.dark,
          paper: PaperPalette.forPaper(kBlueprint),
          camera: camera);
      final spy = SpyCanvas();
      painter.paint(spy, kChromeSize);
      expect(painter.debugLastBreakCount, greaterThan(0), reason: 'premise');

      final shot =
          await rasterise((c) => painter.paint(c, kChromeSize), kChromeSize);
      // Row 13 is inside the second dash (y in [10, 16)), and inside the
      // sheet, whose top is off screen.
      final c = pixelAt(shot, 300, 13);
      expect(c, nearRgb(0xFF8AB4F8), reason: 'got $c');
      expect(c.$3, greaterThan(c.$1));
      expect(c.$3, greaterThan(c.$2));
      expect(lum(c), greaterThan(lum(rgbOf(kBlueprint))));
      // And the Paint itself, through the recording canvas.
      final breaks = spy.named('drawPath').toList();
      expect(breaks, hasLength(1));
      expect(argbOf(breaks.single), 0xFF8AB4F8);
    });

    test(
        'C-1: the page breaks follow the paper, not the chrome: White in the '
        'dark chrome, Blueprint in the light', () async {
      // Crossed: here the chrome's brightness and the paper's set disagree,
      // so a break coloured by the chrome (or the theme) shows.
      const s = 0.05;
      for (final (chrome, paperArgb, want) in const [
        (ChromePalette.dark, kWhite, 0xFF3366CC),
        (ChromePalette.light, kBlueprint, 0xFF8AB4F8),
      ]) {
        final camera = CameraController(ViewportTransform(
            worldToScreenMatrix:
                const Transform2(s, 0, 0, -s, 300.5 - s * 7350, 439)));
        final page = standardPage().copyWith(
            background: paperArgb, pageBreaks: true, gridVisible: false);
        final painter = chromePainter(page,
            chrome: chrome,
            paper: PaperPalette.forPaper(paperArgb),
            camera: camera);
        final spy = SpyCanvas();
        painter.paint(spy, kChromeSize);
        final breaks = spy.named('drawPath').toList();
        expect(breaks, hasLength(1), reason: 'premise: the breaks are drawn');
        expect(argbOf(breaks.single), want,
            reason: 'paper 0x${paperArgb.toRadixString(16)}');
        // The same pixel as M-DT-5's: column 300, inside the second dash.
        final shot =
            await rasterise((c) => painter.paint(c, kChromeSize), kChromeSize);
        final c = pixelAt(shot, 300, 13);
        expect(c, nearRgb(want),
            reason: 'paper 0x${paperArgb.toRadixString(16)}: got $c');
      }
    });

    test(
        'M-DT-7: the sheet edge\'s Paint.color is the chrome\'s, whatever '
        'the paper', () {
      for (final (chrome, paperArgb, edge) in const [
        (ChromePalette.dark, kBlueprint, 0xFF8A8A8A),
        (ChromePalette.dark, kWhite, 0xFF8A8A8A),
        (ChromePalette.light, kBlueprint, 0xFF9E9E9E),
      ]) {
        final painter = chromePainter(
            standardPage().copyWith(background: paperArgb),
            chrome: chrome,
            paper: PaperPalette.forPaper(paperArgb));
        final spy = SpyCanvas();
        painter.paint(spy, kChromeSize);
        final rects = spy.named('drawRect').toList();
        expect(rects, hasLength(2), reason: 'the fill, then the edge');
        expect(argbOf(rects[0]), paperArgb, reason: 'the fill is the paper');
        expect(rects[1].paintingStyle, PaintingStyle.stroke);
        expect(argbOf(rects[1]), edge,
            reason: 'paper 0x${paperArgb.toRadixString(16)}');
      }
    });

    test('its Paints are fields: the same objects on the next frame', () {
      final painter = chromePainter(
          standardPage().copyWith(background: kBlueprint, pageBreaks: true),
          chrome: ChromePalette.dark,
          paper: PaperPalette.dark);
      final a = SpyCanvas(), b = SpyCanvas();
      painter.paint(a, kChromeSize);
      painter.paint(b, kChromeSize);
      List<Paint> paints(SpyCanvas s) =>
          [for (final c in s.calls) ...c.args.whereType<Paint>()];
      expect(paints(a), hasLength(5),
          reason: 'fill, edge, minor, major, break');
      for (var i = 0; i < 5; i++) {
        expect(identical(paints(a)[i], paints(b)[i]), isTrue, reason: '#$i');
      }
    });

    test('shouldRepaint: true exactly when a palette differs, by value', () {
      final page = standardPage().copyWith(background: kBlueprint);
      final camera = standardCamera();
      PageChromePainter make(ChromePalette chrome, PaperPalette paper) =>
          chromePainter(page, chrome: chrome, paper: paper, camera: camera);
      final base = make(ChromePalette.dark, PaperPalette.dark);
      final sameCopy =
          make(chromeCopy(ChromePalette.dark), paperCopy(PaperPalette.dark));
      expect(identical(sameCopy.chrome, base.chrome), isFalse,
          reason: 'premise: equal, not identical');
      expect(identical(sameCopy.paper, base.paper), isFalse,
          reason: 'premise: equal, not identical');
      expect(make(ChromePalette.dark, PaperPalette.dark).shouldRepaint(base),
          isFalse);
      expect(sameCopy.shouldRepaint(base), isFalse);
      expect(make(ChromePalette.light, PaperPalette.dark).shouldRepaint(base),
          isTrue,
          reason: 'the chrome alone flipped');
      expect(make(ChromePalette.dark, PaperPalette.light).shouldRepaint(base),
          isTrue,
          reason: 'the paper alone flipped');
    });
  });

  group('RulerPainter and RulerCornerPainter', () {
    const barH = Size(800, kRulerThickness);
    const corner = Size(kRulerThickness, kRulerThickness);

    RulerPainter ruler(ChromePalette chrome, {Offset? pointer}) => RulerPainter(
          axis: RulerAxis.horizontal,
          camera: standardCamera(),
          page: ValueNotifier<PageComponent?>(
              standardPage().copyWith(background: kBlueprint)),
          pointer: ValueNotifier<Offset?>(pointer),
          chrome: chrome,
        );

    RulerCornerPainter cornerPainter(ChromePalette chrome) =>
        RulerCornerPainter(
          page: ValueNotifier<PageComponent?>(
              standardPage().copyWith(background: kBlueprint)),
          chrome: chrome,
        );

    test(
        'M-DT-6: in the dark chrome the bar, ticks, marker and label colour '
        'are the dark set (recording canvas)', () {
      final painter = ruler(ChromePalette.dark, pointer: const Offset(123, 9));
      final spy = SpyCanvas();
      painter.paint(spy, barH);
      expect(argbOf(spy.named('drawRect').single), 0xFF2B2D31, reason: 'bar');
      final lines = spy.named('drawLine').toList();
      final marker = [
        for (final l in lines)
          if (argbOf(l) == 0xFFFF6B66) l
      ];
      expect(marker, hasLength(1), reason: 'the pointer marker');
      final ink = [
        for (final l in lines)
          if (!identical(l, marker.single)) l
      ];
      expect(ink.length, greaterThan(5), reason: 'the base line and ticks');
      for (final l in ink) {
        expect(argbOf(l), 0xFFC8C8C8, reason: 'tick ink');
      }
      final label = painter.debugLastLabel;
      expect(label, isNotNull, reason: 'premise: a label was laid out');
      expect(label!.style?.color?.toARGB32(), 0xFFC8C8C8,
          reason: 'the label TextSpan, not the light ink');
      expect(label.style?.fontSize, kRulerLabelSize);
    });

    test('M-DT-6: the corner box and its symbol are the dark set', () {
      final painter = cornerPainter(ChromePalette.dark);
      final spy = SpyCanvas();
      painter.paint(spy, corner);
      expect(argbOf(spy.named('drawRect').single), 0xFF2B2D31);
      expect(painter.debugLastLabel?.style?.color?.toARGB32(), 0xFFC8C8C8);
      expect(painter.debugLastLabel?.text, 'm');
    });

    test(
        'M-DT-6: in pixels, the dark bar samples 0x2B2D31, its major tick '
        'and its label are light; the light bar stays 0xF2F2F2', () async {
      for (final (chrome, bar, light) in const [
        (ChromePalette.dark, 0xFF2B2D31, true),
        (ChromePalette.light, 0xFFF2F2F2, false),
      ]) {
        final painter = ruler(chrome);
        painter.paint(SpyCanvas(), barH);
        final majors =
            painter.debugLastTicks.where((t) => t.$2).map((t) => t.$1).toList();
        final all = painter.debugLastTicks.map((t) => t.$1).toList();
        // A major well inside the bar, and the next tick after it.
        final i = all.indexWhere((x) => x > 20 && majors.contains(x));
        expect(i, greaterThanOrEqualTo(0), reason: 'premise: a major');
        final tick = all[i], next = all[i + 1];
        final shot = await rasterise((c) => painter.paint(c, barH), barH);

        // Row 15: under the 10 px labels, above the 6 px minor ticks; midway
        // between two ticks it is bare bar.
        final bare = pixelAt(shot, ((tick + next) / 2).floor(), 15);
        expect(bare, nearRgb(bar, tolerance: 0), reason: 'bare bar');

        final tickInk = extreme(shot, tick.floor(), 20, brightest: light);
        // The label starts 2 px right of its tick at y = 1; the test font's
        // glyphs are solid boxes, so its first glyph's middle is ink.
        final glyph = extreme(shot, tick.floor() + 5, 6, brightest: light);
        for (final (what, c) in [('tick', tickInk), ('label', glyph)]) {
          if (light) {
            expect(lum(c), greaterThan(lum(rgbOf(bar)) + 80),
                reason: '$what $c on the dark bar');
          } else {
            expect(lum(c), lessThan(lum(rgbOf(bar)) - 80),
                reason: '$what $c on the light bar');
          }
        }
      }
    });

    test('in pixels, the dark corner box is 0x2B2D31 and its symbol light',
        () async {
      final painter = cornerPainter(ChromePalette.dark);
      final shot = await rasterise((c) => painter.paint(c, corner), corner);
      expect(pixelAt(shot, 1, 1), nearRgb(0xFF2B2D31, tolerance: 0));
      final c = extreme(shot, 12, 12, brightest: true);
      expect(lum(c), greaterThan(lum(rgbOf(0xFF2B2D31)) + 80), reason: '$c');
    });

    test(
        'the label style is built once per painter: the same TextStyle on '
        'every label and every frame', () {
      final painter = ruler(ChromePalette.dark);
      painter.paint(SpyCanvas(), barH);
      final first = painter.debugLastLabel!.style;
      painter.paint(SpyCanvas(), barH);
      expect(identical(painter.debugLastLabel!.style, first), isTrue);
      final c = cornerPainter(ChromePalette.dark);
      c.paint(SpyCanvas(), corner);
      final cornerFirst = c.debugLastLabel!.style;
      c.paint(SpyCanvas(), corner);
      expect(identical(c.debugLastLabel!.style, cornerFirst), isTrue);
    });

    test('the ruler Paints are fields: the same objects on the next frame', () {
      final painter = ruler(ChromePalette.dark, pointer: const Offset(123, 9));
      final a = SpyCanvas(), b = SpyCanvas();
      painter.paint(a, barH);
      painter.paint(b, barH);
      final pa = <Paint>{for (final c in a.calls) ...c.args.whereType<Paint>()};
      final pb = <Paint>{for (final c in b.calls) ...c.args.whereType<Paint>()};
      expect(pa, hasLength(3), reason: 'bar, ink, marker');
      expect(pb, hasLength(3));
      expect(pb.every((p) => pa.any((q) => identical(p, q))), isTrue);
    });

    test('shouldRepaint: true exactly when the chrome differs, by value', () {
      final base = ruler(ChromePalette.dark);
      expect(ruler(ChromePalette.dark).shouldRepaint(base), isFalse);
      expect(ruler(chromeCopy(ChromePalette.dark)).shouldRepaint(base), isFalse,
          reason: 'an equal, non-identical palette');
      expect(ruler(ChromePalette.light).shouldRepaint(base), isTrue);

      final cornerBase = cornerPainter(ChromePalette.dark);
      expect(
          cornerPainter(ChromePalette.dark).shouldRepaint(cornerBase), isFalse);
      expect(
          cornerPainter(chromeCopy(ChromePalette.dark))
              .shouldRepaint(cornerBase),
          isFalse,
          reason: 'an equal, non-identical palette');
      expect(
          cornerPainter(ChromePalette.light).shouldRepaint(cornerBase), isTrue);
    });
  });

  group('RulerFrame', () {
    Widget frame(ChromePalette chrome, GlobalKey key) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 424,
              height: 324,
              child: RulerFrame(
                key: key,
                camera: standardCamera(),
                page: ValueNotifier<PageComponent?>(
                    standardPage().copyWith(background: kBlueprint)),
                chrome: chrome,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

    ChromePalette chromeOf(WidgetTester tester, String key) {
      final painter = tester.widget<CustomPaint>(find.byKey(Key(key))).painter;
      return switch (painter) {
        RulerPainter(:final chrome) => chrome,
        RulerCornerPainter(:final chrome) => chrome,
        _ => throw StateError('$key: $painter'),
      };
    }

    testWidgets(
        'hands its chrome to the two bars and the corner, and a new '
        'one on a rebuild', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(frame(ChromePalette.dark, key));
      for (final k in ['ruler-top', 'ruler-left', 'ruler-corner']) {
        expect(identical(chromeOf(tester, k), ChromePalette.dark), isTrue,
            reason: k);
      }
      await tester.pumpWidget(frame(ChromePalette.light, key));
      for (final k in ['ruler-top', 'ruler-left', 'ruler-corner']) {
        expect(identical(chromeOf(tester, k), ChromePalette.light), isTrue,
            reason: k);
      }
    });
  });

  group('SelectionOverlayPainter', () {
    const view = Size(800, 600);

    SelectionOverlayPainter overlay(GripRig rig, PaperPalette paper) =>
        SelectionOverlayPainter(
          selection: rig.selection,
          tools: rig.tools,
          camera: rig.camera,
          outlines: rig.outlines,
          paper: paper,
          repaint: Listenable.merge(
              [rig.selection, rig.tools, rig.camera, rig.outlines, rig.grips]),
        );

    test(
        'the selection, hover, grips, hot grip and rotation grip take the '
        'paper set handed in (dark set, recording canvas)', () {
      final s =
          gripScene(page: standardPage().copyWith(background: kBlueprint));
      final rig = gripRig(s.document);
      // The polyline's vertices are stretch grips, the circle's centre a
      // move grip (and its quadrants radius grips).
      rig.selection.replace(
          [SelectionKey.root(s.polyline), SelectionKey.root(s.circle)]);
      rig.selection.setHover(SelectionKey.root(s.arcPos));
      rig.grips.hot = 1;
      final paper = PaperPalette.forPaper(kBlueprint);
      final spy = SpyCanvas();
      overlay(rig, paper).paint(spy, view);

      final paths = spy.named('drawPath').toList();
      expect(paths.map(argbOf), [0xFF7FB2FF, 0xFF7FB2FF, 0x997FB2FF],
          reason: 'the two selected outlines, then the hover');
      final raw = spy.named('drawRawPoints').toList();
      expect(raw.map(argbOf), [0xFF7FB2FF, 0xFFC4A0FF, 0xFFFF8A5C],
          reason: 'stretch grips, the move grip, the hot grip');
      expect(rig.grips.rotatable, isTrue, reason: 'premise');
      expect(argbOf(spy.named('drawLine').last), 0xFF7FB2FF,
          reason: 'the rotation grip stem');
      expect(argbOf(spy.named('drawCircle').single), 0xFF7FB2FF,
          reason: 'the rotation grip disc');
    });

    test('the move preview takes the paper set handed in', () {
      final s =
          gripScene(page: standardPage().copyWith(background: kBlueprint));
      final rig = gripRig(s.document);
      rig.selection.replace([SelectionKey.root(s.line)]);
      final grip =
          rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix)
              .centre;
      pressAndMove(rig, grip, grip + const Offset(-45, 38));
      expect(rig.tool.selectionPreviewTransform, isNotNull, reason: 'premise');
      final spy = SpyCanvas();
      overlay(rig, PaperPalette.dark).paint(spy, view);
      // The outline pass pushes the first matrix, the preview pass the
      // second; the paths after it are the preview's.
      final second = spy.calls.indexOf(spy.named('transform').last);
      final previews = [
        for (final c in spy.calls.skip(second))
          if (c.name == 'drawPath') c
      ];
      expect(previews, isNotEmpty);
      for (final c in previews) {
        expect(argbOf(c), 0xFFFFC857);
      }
    });

    test('shouldRepaint: true exactly when the paper set differs, by value',
        () {
      final s = gripScene();
      final rig = gripRig(s.document);
      final base = overlay(rig, PaperPalette.dark);
      expect(overlay(rig, PaperPalette.dark).shouldRepaint(base), isFalse);
      expect(overlay(rig, paperCopy(PaperPalette.dark)).shouldRepaint(base),
          isFalse,
          reason: 'an equal, non-identical palette');
      expect(overlay(rig, PaperPalette.light).shouldRepaint(base), isTrue);
    });
  });
}
