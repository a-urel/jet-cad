// SPIKE 11 -- throwaway. Q6: the sample plan with dimensions, rendered by the
// real floor planner shell inside flutter_test (RenderRepaintBoundary
// .toImage, the software rasteriser). The camera maps world y down the
// screen, so the images are mirrored top to bottom. The test font draws
// every glyph as a box.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

const x0 = 12000.0, y0 = 8000.0;
const l = WallSide.left, r = WallSide.right;

/// The sample plan's walls by name, found by their stored parameters (all
/// at the identity in `startupPlan`).
Map<String, Handle> sampleWallHandles(DraftDocument doc, Placement place) {
  const names = ['E1', 'E2', 'E3', 'E4', 'P1', 'P2', 'P3', 'P4', 'P5'];
  final ws = sampleWalls();
  final out = <String, Handle>{};
  for (final h in doc.components.withComponent<WallParams>()) {
    final p = doc.components.get<WallParams>(h)!;
    final m = doc.tree.accumulatedTransform(h);
    final s = m.transformPoint(p.start);
    for (var i = 0; i < ws.length; i++) {
      if ((s - place.at(ws[i].sx, ws[i].sy)).length < 1e-6 &&
          (m.transformPoint(p.end) - place.at(ws[i].ex, ws[i].ey)).length <
              1e-6) {
        out[names[i]] = h;
      }
    }
  }
  return out;
}

/// Decision 15's dimensions on the sample plan at [place], through a
/// parametric system installed for the purpose and disposed.
Map<String, Handle> addSampleDimensions(DraftDocument doc, Placement place) {
  final sys = installParametric(doc);
  final w = sampleWallHandles(doc, place);
  final g = place.m;
  final out = {
    // Overall width, the outer face of E1: (12,000, 8,000) -> (26,000,
    // 8,000), 14,000, 1,200 below.
    'overall width': addDimension(
        doc, AttachedEnd(w['E1']!, 0, r), AttachedEnd(w['E1']!, 1, r),
        kind: DimKind.horizontal, offset: -1200, at: g),
    // Overall depth, the outer face of E2: (26,000, 8,000) -> (26,000,
    // 17,000), 9,000, 1,200 east (vertical: n = (-1, 0), so negative).
    'overall depth': addDimension(
        doc, AttachedEnd(w['E2']!, 0, r), AttachedEnd(w['E2']!, 1, r),
        kind: DimKind.vertical, offset: -1200, at: g),
    // The Hall, corner to corner: E1/0/left (12,250, 8,250) -> P1/0/left
    // (16,940, 8,250): 4,690.
    'hall': addDimension(
        doc, AttachedEnd(w['E1']!, 0, l), AttachedEnd(w['P1']!, 0, l),
        kind: DimKind.horizontal, offset: 900, at: g),
    // The Kitchen: P1/0/right (17,060, 8,250) -> P5/0/left (21,440,
    // 8,250): 4,380.
    'kitchen': addDimension(
        doc, AttachedEnd(w['P1']!, 0, r), AttachedEnd(w['P5']!, 0, l),
        kind: DimKind.horizontal, offset: 900, at: g),
    // The Bath's diagonal, aligned: E2/0/left (25,750, 8,250) -> a fixed
    // point at (21,560, 11,440): sqrt(4,190² + 3,190²) = 5,266.14.
    'bath diagonal': addDimension(
        doc, AttachedEnd(w['E2']!, 0, l), fixedAt(place.at(21560, 11440), g),
        offset: 0, at: g),
  };
  sys.dispose();
  doc.commands.clearHistory();
  return out;
}

/// Renders [doc] through the shell, centred on world [centre] at
/// [pxPerMm] turned by [deg]; writes `build/spike_dims/<name>.png` and
/// returns a sampler of the RGBA at a world point.
Future<Color Function(Vector2)> snap(WidgetTester tester, String name,
    DraftDocument doc, Vector2 centre, double pxPerMm,
    {double deg = 0}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final capture = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
      key: capture, child: MaterialApp(home: PlannerShell(document: doc))));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final layer = find.byType(InteractionLayer);
  final size = tester.getSize(layer);
  final topLeft = tester.getTopLeft(layer);
  final linear = Transform2.rotation(deg * math.pi / 180)
      .multiply(Transform2.scale(pxPerMm, pxPerMm));
  final mid = linear.transformPoint(centre);
  final camera = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  view.camera.value = camera;
  await tester.pump();
  final boundary =
      capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final (png, raw, width, height) = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    return (png!, raw!, w, h);
  }))!;
  Directory('build/spike_dims').createSync(recursive: true);
  File('build/spike_dims/$name.png').writeAsBytesSync(png.buffer.asUint8List());
  await tester.pumpWidget(const SizedBox());
  final bytes = Uint8List.sublistView(raw);
  final m = camera.worldToScreenMatrix;
  return (Vector2 w) {
    final s = m.transformPoint(w);
    final px = (topLeft.dx + s.x).round(), py = (topLeft.dy + s.y).round();
    if (px < 0 || py < 0 || px >= width || py >= height) {
      throw RangeError('$w is off the ${width}x$height image');
    }
    final i = (py * width + px) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  };
}

bool isInk(Color c) => (c.r + c.g + c.b) / 3 < 0.5;

/// The run of ink, in world mm, from [from] along [dir] (unit) sampled
/// every [step] mm up to [max]: the first and last inked distance.
(double, double)? inkRun(Color Function(Vector2) at, Vector2 from, Vector2 dir,
    double step, double max) {
  double? first, last;
  for (var t = 0.0; t <= max; t += step) {
    if (isInk(at(from + dir * t))) {
      first ??= t;
      last = t;
    }
  }
  return first == null ? null : (first, last!);
}

void main() {
  testWidgets(
      'R1 the sample plan with decision 15\'s dimensions, 1:50 and '
      '1:100', (tester) async {
    for (final scale in [50.0, 100.0]) {
      final doc = startupPlan(FlutterTextMeasurer());
      if (scale != 50) {
        final page = doc.components.get<PageComponent>(doc.rootHandle)!;
        final sys = installParametric(doc);
        doc.commands.execute(SetComponentCommand<PageComponent>(
            doc.rootHandle, page.copyWith(scaleDenominator: scale)));
        sys.dispose();
        doc.commands.clearHistory();
      }
      final dims = addSampleDimensions(doc, origin);
      expect(driftOf(doc), isEmpty);
      expect({
        for (final e in dims.entries) e.key: dimText(doc, e.value)
      }, {
        'overall width': '14.00',
        'overall depth': '9.00',
        'hall': '4.69',
        'kitchen': '4.38',
        'bath diagonal': '5.27',
      });
      final tag = '1_${scale.toInt()}';
      await snap(tester, 'r1_sample_dims_$tag', doc,
          Vector2(x0 + 7000, y0 + 4000), 0.052);
      // Zoomed on the Hall and Kitchen dimensions and the overall width's
      // left end: slashes, text, extension-line gaps.
      final at = await snap(
          tester, 'r2_hall_zoom_$tag', doc, Vector2(x0 + 2600, y0 + 700), 0.15);
      await snap(tester, 'r2b_hall_kitchen_partly_off_$tag', doc,
          Vector2(x0 + 4500, y0 + 500), 0.2);
      // The Hall dimension's line at y = 8,250 + 900 = 9,150, x 12,250 ..
      // 16,940. Its text: 2.5 paper mm cap height, 1 paper mm above the
      // line's middle (14,595). The test font's glyph box is one em tall,
      // and DXF text height is cap height (kCapHeightRatio 0.7): the box
      // runs from the gap to gap + h / 0.7.
      final textH = kDimTextPaperMm * scale;
      final gap = kDimTextGapPaperMm * scale;
      final text = inkRun(at, Vector2(14595, 9150 + gap * 0.5), Vector2(0, 1),
          5, gap + textH * 2);
      // The overall width's left extension line, x = 12,000, over paper:
      // from the outer corner y = 8,000 down, a gap of 1.5 paper mm, then
      // ink to the dimension line (y = 6,800) plus 2 paper mm.
      final extGap = kDimExtGapPaperMm * scale;
      final over = kDimExtOvershootPaperMm * scale;
      final ext = inkRun(at, Vector2(12000, 8000 - 5), Vector2(0, -1), 5, 1600);
      // The slash at the Hall line's left end: through (12,250, 9,150) at
      // 45°, one paper mm along it.
      final slashProbe =
          at(Vector2(12250, 9150) + Vector2(1, 1).normalized() * (scale * 1.0));
      // ignore: avoid_print
      print('R2 1:${scale.toInt()}: text ink '
          '${(gap * 0.5 + text!.$1).toStringAsFixed(0)}..${(gap * 0.5 + text.$2).toStringAsFixed(0)} mm above the line '
          '(want ${gap.toStringAsFixed(0)}..${(gap + textH / 0.7).toStringAsFixed(1)}); '
          'extension line ink ${(5 + ext!.$1).toStringAsFixed(0)}..${(5 + ext.$2).toStringAsFixed(0)} mm below the corner '
          '(want ${extGap.toStringAsFixed(0)}..${(1200 + over).toStringAsFixed(0)}); '
          'slash probe ${isInk(slashProbe) ? 'ink' : 'paper'}');
      expect(gap * 0.5 + text.$1, closeTo(gap, 10));
      expect(gap * 0.5 + text.$2, closeTo(gap + textH / 0.7, 10));
      expect(5 + ext.$1, closeTo(extGap, 10));
      expect(5 + ext.$2, closeTo(1200 + over, 10));
      expect(isInk(slashProbe), isTrue);
      // The same text at twice the camera scale: the same world height
      // (the text follows the paper, never the camera, M-11b).
      final at2 = await snap(tester, 'r2c_hall_zoom_x2_$tag', doc,
          Vector2(x0 + 2600, y0 + 1100), 0.3);
      final text2 = inkRun(at2, Vector2(14595, 9150 + gap * 0.5), Vector2(0, 1),
          2, gap + textH * 2)!;
      // ignore: avoid_print
      print('R2c 1:${scale.toInt()} at 0.3 px/mm: text ink '
          '${(gap * 0.5 + text2.$1).toStringAsFixed(0)}..${(gap * 0.5 + text2.$2).toStringAsFixed(0)} mm');
      expect(text2.$2 - text2.$1, closeTo(text.$2 - text.$1, 10));
    }
  });

  testWidgets(
      'R3 the sample plan at the corpus far origin, turned 23°, '
      'every wall in its own group', (tester) async {
    final plan = buildPlan(sampleWalls(),
        openings: sampleOpenings,
        place: corpusGroups,
        measurer: FlutterTextMeasurer());
    final doc = plan.doc;
    plan.system.dispose();
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, startupPage(doc.extents)));
    final dims = addSampleDimensions(doc, corpusGroups);
    expect(driftOf(doc), isEmpty);
    expect(dimText(doc, dims['overall width']!), '14.00');
    expect(dimText(doc, dims['bath diagonal']!), '5.27');
    // The camera turned -23° so the plan reads upright; and not turned.
    final centre = corpusGroups.at(x0 + 7000, y0 + 4000);
    await snap(tester, 'r3_far_origin_23deg', doc, centre, 0.052);
    await snap(tester, 'r3_far_origin_23deg_camera_turned', doc, centre, 0.052,
        deg: -23);
    await snap(tester, 'r3_far_origin_zoom', doc,
        corpusGroups.at(x0 + 4500, y0 + 500), 0.2);
  });
}
