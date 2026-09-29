// Spec 11 D7 and D8 in the shell, on the sample plan (D17): the dimension
// text follows the paper, never the camera (`RR1`, M-11b and its camera
// half M-11b-cam); a slash inks; an extension line inks from its gap to its
// overshoot (drawn, though never picked: D19); the lines keep their ink at
// 0.25 mm under sub-pixel camera moves (`RR2`, D7's measurement of record);
// on Blueprint paper the ink is the light foreground (`RR3`).
//
// The real shell in `flutter_test`, read back with
// `RenderRepaintBoundary.toImage` **at the view's device pixel ratio** (the
// plan's Ruling 11-15, D7's R-31): either the view's ratio set to 1 and a
// capture at 1 (D7's set-up 2), or the default ratio 3 and a capture at 3
// (set-up 3). Never 10's `toImage()` under ratio 3 (set-up 1), whose
// drop-outs are the capture's own; `RR2` prints set-up 1 as D7's caveat and
// asserts nothing of it. The camera is y up and its translation fractional
// (10-28), and every sample takes the darkest (or, on Blueprint, the
// brightest) of the 3 × 3 device pixels around its point.
//
// The test font draws every glyph as a box one em tall, and DXF text height
// is the cap height (0.7 em): a TEXT of height h, bottom-justified at the
// gap g above its line, inks from g to g + h / 0.7 above it.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

/// The page panel's Blueprint paper.
const int blueprint = 0xFF1F3A5F;

/// The sample plan as the app opens it; with [scale] its page at 1:[scale]
/// and with [background] on that paper, in one page command through a
/// system of its own (a scale change regenerates every dimension, D3's page
/// key; a paper change none), then the history cleared.
DraftDocument samplePlan({double scale = 50, int? background}) {
  final doc = startupPlan(FlutterTextMeasurer());
  if (scale != 50 || background != null) {
    final system = installParametric(doc);
    final page = pageOf(doc);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        page.copyWith(
            scaleDenominator: scale,
            background: background ?? page.background)));
    system.dispose();
    doc.commands.clearHistory();
  }
  expect(driftOf(doc), isEmpty);
  return doc;
}

/// The sample's five dimensions, ascending: the width, the depth, the
/// Hall, the Kitchen, the Bath diagonal.
List<Handle> dimsOf(DraftDocument doc) =>
    doc.components.withComponent<DimensionParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));

/// Relative luminance, 0 (black) to 1 (white).
double lum(List<int> c) =>
    (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;

/// D7's ink test on light paper: the mean channel under a half.
bool isInk(List<int> c) => (c[0] + c[1] + c[2]) / 3 / 255 < 0.5;

/// The shell over one document, pumped once; frames are captured from it at
/// cameras of the test's choosing.
final class Rig {
  Rig._(this.tester, this.view, this.capture);

  final WidgetTester tester;
  final PlannerView view;
  final GlobalKey capture;

  /// Pumps the shell over [doc] at a 1400 x 1000 window.
  static Future<Rig> of(WidgetTester tester, DraftDocument doc) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: capture, child: MaterialApp(home: PlannerShell(document: doc))));
    await tester.pump();
    return Rig._(
        tester, tester.widget<PlannerView>(find.byType(PlannerView)), capture);
  }

  Future<void> close() => tester.pumpWidget(const SizedBox());

  /// The drawing area, global logical pixels.
  Rect get canvas => tester.getRect(find.byType(InteractionLayer));

  /// Sets the camera at [pxPerMm], y up, centred near [at], with the
  /// fractional translation ([dx], [dy]) px on top of 10-28's.
  Future<ViewportTransform> camera(Vector2 at, double pxPerMm,
      {double dx = 0, double dy = 0}) async {
    final size = canvas.size;
    final camera = ViewportTransform(
        worldToScreenMatrix: Transform2(
            pxPerMm,
            0,
            0,
            -pxPerMm,
            size.width / 2 - pxPerMm * at.x + 0.37 + dx,
            size.height / 2 + pxPerMm * at.y + 0.61 + dy));
    view.camera.value = camera;
    await tester.pump();
    return camera;
  }

  /// The frame as it is now, read back at pixel ratio [ratio].
  Future<Frame> frame(double ratio) async {
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final (raw, w, h) = (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width, h = image.height;
      image.dispose();
      return (raw!, w, h);
    }))!;
    return Frame(
        Uint8List.sublistView(raw), w, h, ratio, view.camera.value, canvas);
  }
}

/// One captured frame and the camera it was painted with.
final class Frame {
  Frame(this.bytes, this.width, this.height, this.ratio, this.camera,
      this.canvas);

  final Uint8List bytes;
  final int width, height;
  final double ratio;
  final ViewportTransform camera;
  final Rect canvas;

  /// World millimetres per device pixel.
  double get mmPerPixel => 1 / (camera.scale * ratio);

  /// World [w] in device pixels of the image.
  (double, double) devicePoint(Vector2 w) {
    final s = camera.worldToScreen(w);
    return ((canvas.left + s.x) * ratio, (canvas.top + s.y) * ratio);
  }

  /// Whether world [w] lies on the drawing area, 2 px clear of its edge.
  bool shows(Vector2 w) {
    final s = camera.worldToScreen(w);
    return s.x >= 2 &&
        s.y >= 2 &&
        s.x <= canvas.width - 2 &&
        s.y <= canvas.height - 2;
  }

  List<int> rgbAt(int px, int py) {
    final i = (py * width + px) * 4;
    return [bytes[i], bytes[i + 1], bytes[i + 2]];
  }

  /// The 3 × 3 device pixels around world [w], by luminance: the darkest,
  /// or with [brightest] the brightest.
  List<int> sample(Vector2 w, {bool brightest = false}) {
    expect(shows(w), isTrue, reason: 'premise: $w is on the drawing area');
    final (x, y) = devicePoint(w);
    List<int>? best;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final c = rgbAt(x.floor() + dx, y.floor() + dy);
        if (best == null ||
            (brightest ? lum(c) > lum(best) : lum(c) < lum(best))) {
          best = c;
        }
      }
    }
    return best!;
  }

  /// The inked run from world [from] along unit [dir], sampled every device
  /// pixel up to [max] mm: the first and last inked distance, mm.
  (double, double)? inkRun(Vector2 from, Vector2 dir, double max) {
    double? first, last;
    for (var t = 0.0; t <= max; t += mmPerPixel) {
      if (isInk(sample(from + dir * t))) {
        first ??= t;
        last = t;
      }
    }
    return first == null ? null : (first, last!);
  }
}

/// [h]'s TEXT child's world bounds (the dimensions sit at the identity).
Aabb2 textBounds(DraftDocument doc, Handle h) {
  final slot = doc.entities.slotOf(dimTextHandle(doc, h))!;
  final e = doc.entities;
  final m = doc.tree.accumulatedTransform(h);
  expect([m.a, m.b, m.c, m.d, m.e, m.f], [1, 0, 0, 1, 0, 0],
      reason: 'premise: D17 places each dimension at the identity');
  return entityBounds(
    kind: e.kindAt(slot),
    payload: doc.geometry.read(e.geomIndexAt(slot)),
    measurer: doc.textMeasurer,
    textStyle: doc.textStyleOf(e.textStyleAt(slot)),
    textAttrs: e.textAttrsAt(slot),
    text: e.textAt(slot),
  );
}

void main() {
  testWidgets(
      'RR1 the dimension text is the same world height at 0.15 and 0.3 '
      'px/mm and doubles at 1:100; a slash inks; the extension line inks from '
      'its gap', (tester) async {
    // D7's set-up 2: the view at device pixel ratio 1, captured at 1.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    final heights = <String, double>{};
    for (final scale in const [50.0, 100.0]) {
      final doc = samplePlan(scale: scale);
      final [width, _, hall, _, _] = dimsOf(doc);
      // D7's paper constants at 1:scale, world mm: the text's cap height
      // 2.5 · scale (125, 250), its gap above the line 1.0 · scale (50,
      // 100), the extension line's gap 1.5 · scale (75, 150) and overshoot
      // 2.0 · scale (100, 200), a slash 3.0 · scale long (150, 300).
      final capH = 2.5 * scale, gap = 1.0 * scale;
      final extGap = 1.5 * scale, over = 2.0 * scale;
      // The Hall's line: y 8,250 + 900 = 9,150, x 12,250–16,940; its text
      // "4.69", four glyph boxes centred on x 14,595. The probe column is a
      // sixteenth of the text's width right of its centre: inside the third
      // glyph at this size and at half of it (a camera-scaled text,
      // M-11b-cam, shrinks about its bottom centre).
      expect(dimText(doc, hall), '4.69');
      final (q0, q1) = dimLines(doc, hall)[0];
      expect([q0.x, q0.y, q1.x, q1.y], [12250, 9150, 16940, 9150]);
      final box = textBounds(doc, hall);
      expect((box.minX + box.maxX) / 2, closeTo(14595, 1e-6),
          reason: 'premise: centred on the line');
      final column = 14595 + (box.maxX - box.minX) / 16;
      // The width's extension line at a: x 12,000, from the outer corner
      // (12,000, 8,000) − the gap down to the line (7,500) − the overshoot.
      final (e0, e1) = dimLines(doc, width)[1];
      expect(
          [e0.x, e0.y, e1.x, e1.y], [12000, 8000 - extGap, 12000, 7500 - over],
          reason: 'premise: the width\'s extension line at a');
      final rig = await Rig.of(tester, doc);
      for (final px in const [0.15, 0.3]) {
        await rig.camera(Vector2(13350, 8475), px);
        final f = await rig.frame(1.0);
        final tol = 2 * f.mmPerPixel; // two device pixels, world mm
        // The text's band takes three: the 3 × 3 darkest sample widens a
        // glyph's ink by up to one device pixel at each edge, on top of the
        // two (the Task 15 review measured 6.2 of 6.67 mm at 0.3 px/mm, and
        // 12.9 of 13.3 mm at 0.15 px/mm at another sub-pixel offset). Over
        // 36 sub-pixel offsets at each scale and zoom, the worst edge is 1.93
        // device pixels off (Task 16's sweep).
        final textTol = 3 * f.mmPerPixel;
        final tag = '1:${scale.toInt()} at $px px/mm';
        // The text: from half the gap above the line, upwards.
        final run = f.inkRun(
            Vector2(column, 9150 + gap / 2), Vector2(0, 1), gap + 2 * capH);
        expect(run, isNotNull, reason: '$tag: the text inks its column');
        final lo = gap / 2 + run!.$1, hi = gap / 2 + run.$2;
        // The slash at the Hall line's a end, (12,250, 9,150), 45° up and
        // right: a probe one paper mm along it; the mirror probe, off it.
        final along = Vector2(1, 1).normalized() * scale;
        final slash = f.sample(Vector2(12250, 9150) + along);
        final off = f.sample(Vector2(12250, 9150) + Vector2(along.x, -along.y));
        // The extension line, from 25 mm under the corner (clear of the
        // wall's own face stroke by more than a 3 × 3 block) downwards.
        final ext = f.inkRun(
            Vector2(12000, 8000 - 25), Vector2(0, -1), 500 + over + 70 - 25);
        expect(ext, isNotNull, reason: '$tag: the extension line inks');
        final extLo = 25 + ext!.$1, extHi = 25 + ext.$2;
        final gapMid = f.sample(Vector2(12000, 8000 - (25 + extGap) / 2));
        // ignore: avoid_print
        print('RR1 $tag: text ink ${lo.toStringAsFixed(1)}..'
            '${hi.toStringAsFixed(1)} mm above the line (want '
            '$gap..${(gap + capH / 0.7).toStringAsFixed(1)}, tol '
            '${textTol.toStringAsFixed(1)}); slash '
            '${isInk(slash) ? 'ink' : 'paper'}'
            ', off it ${isInk(off) ? 'ink' : 'paper'}; extension line ink '
            '${extLo.toStringAsFixed(1)}..${extHi.toStringAsFixed(1)} mm below '
            'the corner (want $extGap..${500 + over}), gap '
            '${isInk(gapMid) ? 'ink' : 'paper'}');
        expect(lo, closeTo(gap, textTol), reason: '$tag: the text\'s bottom');
        expect(hi, closeTo(gap + capH / 0.7, textTol),
            reason: '$tag: the text\'s top, g + h / 0.7');
        heights['$scale $px'] = hi - lo;
        expect(isInk(slash), isTrue, reason: '$tag: the slash inks');
        expect(isInk(off), isFalse, reason: '$tag: premise: beside it paper');
        expect(extLo, closeTo(extGap, tol),
            reason: '$tag: the extension line starts past its gap');
        expect(extHi, closeTo(500 + over, tol),
            reason: '$tag: and ends past the line by the overshoot');
        expect(isInk(gapMid), isFalse, reason: '$tag: paper within the gap');
      }
      await rig.close();
    }
    // The same world height at both zooms (the paper, never the camera),
    // and twice it at 1:100: 178.6 and 357.1 mm, each within two device
    // pixels at 0.15 px/mm (13.3 mm).
    expect(heights['50.0 0.3']!, closeTo(heights['50.0 0.15']!, 2 / 0.15));
    expect(heights['100.0 0.3']!, closeTo(heights['100.0 0.15']!, 2 / 0.15));
    expect(heights['100.0 0.15']!,
        closeTo(2 * heights['50.0 0.15']!, 2 * 2 / 0.15));
  });

  testWidgets(
      'RR2 D7\'s sweep: at 0.25 mm, captured at the view\'s device pixel '
      'ratio, no frame loses an axis-aligned dimension line at 0.052, 0.15 '
      'and 0.3 px/mm', (tester) async {
    // A measurement of record (S-10): it owns no mutant. D7's method on
    // D17's dimensions: the width's line y 7,500 (x 12,000–26,000, text at
    // 19,000), the depth's x 26,300 (y 8,000–17,000, text at 12,500), the
    // Hall's y 9,150 (x 12,250–16,940, text from 14,238); each probed well
    // inside its ends and clear of its text.
    final probes = <(String, Vector2, Vector2, bool)>[
      ('width', Vector2(13000, 7500), Vector2(17500, 7500), true),
      ('depth', Vector2(26300, 9000), Vector2(26300, 11500), false),
      ('hall', Vector2(12700, 9150), Vector2(13900, 9150), true),
    ];
    final zooms = [
      (0.052, Vector2(19000, 12000)),
      (0.15, Vector2(15000, 8500)),
      (0.3, Vector2(14000, 8500)),
    ];
    // (view ratio, capture ratio, asserted): set-ups 2 and 3, then set-up 1,
    // printed as D7's caveat and never asserted.
    const setups = [(1.0, 1.0, true), (3.0, 3.0, true), (3.0, 1.0, false)];
    final lines = <String>[];
    for (final (dpr, ratio, asserted) in setups) {
      tester.view.devicePixelRatio = dpr;
      final doc = samplePlan();
      expect(
          dimsOf(doc).map((d) => dimLines(doc, d)[0]).take(3).toList(),
          [
            (Vector2(12000, 7500), Vector2(26000, 7500)),
            (Vector2(26300, 8000), Vector2(26300, 17000)),
            (Vector2(12250, 9150), Vector2(16940, 9150)),
          ],
          reason: 'premise: the probed lines');
      final rig = await Rig.of(tester, doc);
      for (final (px, centre) in zooms) {
        final frames = <String, int>{}, lost = <String, int>{};
        for (var axis = 0; axis < 2; axis++) {
          for (var k = 0; k < 32; k++) {
            await rig.camera(centre, px,
                dx: axis == 0 ? k / 32 : 0, dy: axis == 1 ? k / 32 : 0);
            final f = await rig.frame(ratio);
            for (final (name, a, b, horizontal) in probes) {
              // A horizontal line is swept by the y translation, a vertical
              // one by the x.
              if (horizontal != (axis == 1)) continue;
              if (!f.shows(a) || !f.shows(b)) continue;
              frames[name] = (frames[name] ?? 0) + 1;
              // D7's count: the device columns (rows) along the probe, every
              // third, with ink in the row (column) holding the line's
              // centre or either neighbour.
              final (ax, ay) = f.devicePoint(a);
              final (bx, by) = f.devicePoint(b);
              var inked = 0, total = 0;
              if (horizontal) {
                final row = ay.floor();
                for (var x = ax.ceil(); x < bx.floor(); x += 3) {
                  total++;
                  if (isInk(f.rgbAt(x, row - 1)) ||
                      isInk(f.rgbAt(x, row)) ||
                      isInk(f.rgbAt(x, row + 1))) {
                    inked++;
                  }
                }
              } else {
                final col = ax.floor();
                final lo = ay < by ? ay : by, hi = ay < by ? by : ay;
                for (var y = lo.ceil(); y < hi.floor(); y += 3) {
                  total++;
                  if (isInk(f.rgbAt(col - 1, y)) ||
                      isInk(f.rgbAt(col, y)) ||
                      isInk(f.rgbAt(col + 1, y))) {
                    inked++;
                  }
                }
              }
              if (total > 0 && inked * 2 < total) {
                lost[name] = (lost[name] ?? 0) + 1;
              }
            }
          }
        }
        final line = '${asserted ? '' : 'set-up 1, D7\'s caveat, not '
                'asserted: '}lineweight $kDimLineweight at $px px/mm (dpr '
            '$dpr, captured at $ratio): frames per probe $frames, frames with '
            'the line lost $lost';
        lines.add(line);
        expect(frames, isNotEmpty, reason: 'premise: a probe is visible');
        if (asserted) expect(lost, isEmpty, reason: line);
      }
      await rig.close();
    }
    tester.view.resetDevicePixelRatio();
    // ignore: avoid_print
    print(lines.join('\n'));
  });

  testWidgets('RR3 on Blueprint paper the dimension ink is the foreground',
      (tester) async {
    // D7's set-up 3: the view at its default ratio 3, captured at 3, so the
    // 0.25 mm line is 2.83 device pixels wide and one of them is wholly
    // covered.
    expect(tester.view.devicePixelRatio, 3.0);
    final doc = samplePlan(background: blueprint);
    final [_, _, hall, _, _] = dimsOf(doc);
    expect(dimText(doc, hall), '4.69',
        reason: 'premise: the Hall\'s value (that a paper change regenerates '
            'nothing is DO2\'s)');
    // ACI 7 on Blueprint is white (fix/post-07's `foregroundFor`).
    expect(foregroundFor(blueprint), 0xFFFFFF, reason: 'premise');
    final rig = await Rig.of(tester, doc);
    await rig.camera(Vector2(13800, 9150), 0.15);
    final f = await rig.frame(3.0);
    final box = textBounds(doc, hall);
    // On the Hall's line, x 13,300; in the text's first glyph, 50 + 89.3 mm
    // above the line (half its em, 125 / 0.7 / 2); the paper 50 mm below
    // the line, clear of everything.
    final line = f.sample(Vector2(13300, 9150), brightest: true);
    final text = f.sample(
        Vector2(box.minX + (box.maxX - box.minX) / 8, 9150 + 50 + 89.3),
        brightest: true);
    final paper = f.sample(Vector2(13300, 9100), brightest: true);
    // ignore: avoid_print
    print('RR3 on Blueprint: line $line, text $text, paper $paper');
    for (final (what, c) in [('the line', line), ('the text', text)]) {
      for (final ch in c) {
        expect(ch, greaterThanOrEqualTo(230),
            reason: '$what reads the light foreground, not the dark: $c');
      }
    }
    expect(lum(paper), lessThan(0.35), reason: 'premise: the paper is dark');
    await rig.close();
  });
}
