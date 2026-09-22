import 'dart:math' as math;
import 'dart:ui';

// `Float32List` arrives with `ValueNotifier`: `dart:foundation` re-exports
// `dart:typed_data`, and importing both trips `unnecessary_import`.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';
import 'support/spy_canvas.dart';

/// The metric ladder, written out so the oracle shares nothing with
/// `GridScale.pick` (spec, Differential check).
const List<double> kLadderTable = [
  0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, //
  10000, 20000, 50000, 100000, 200000, 500000, 1000000, 2000000, 5000000,
  10000000, 20000000, 50000000,
];

double? oracleMajor(double pxPerMm) {
  for (final step in kLadderTable) {
    if (step * pxPerMm >= 64) return step;
  }
  return null;
}

/// Major-line screen x positions, brute force: every lattice x inside the
/// visible-and-sheet range.
///
/// The intersection is the two-dimensional one: a sheet that the viewport
/// misses vertically shows no grid at all, however much of its x range the
/// viewport spans. Seeded trials 8, 15 and 47 land exactly there.
List<double> oracleMajorXs(
    ViewportTransform cam, PageComponent page, Size size) {
  final step = oracleMajor(cam.scale);
  if (step == null) return const [];
  final sheet = sheetWorldRect(page);
  final visible = cam.visibleWorld(size);
  final minX = math.max(sheet.minX, visible.minX);
  final maxX = math.min(sheet.maxX, visible.maxX);
  final minY = math.max(sheet.minY, visible.minY);
  final maxY = math.min(sheet.maxY, visible.maxY);
  if (minX > maxX || minY > maxY) return const [];
  final out = <double>[];
  for (var i = ((minX - page.originX) / step).ceil();
      i <= ((maxX - page.originX) / step).floor();
      i++) {
    out.add(cam.worldToScreen(Vector2(page.originX + i * step, 0)).x);
  }
  return out;
}

(PageChromePainter, ValueNotifier<PageComponent?>, CameraController) rig(
    {PageComponent? page, CameraController? camera}) {
  final n = ValueNotifier<PageComponent?>(page ?? standardPage());
  final cam = camera ?? standardCamera();
  return (PageChromePainter(camera: cam, page: n), n, cam);
}

/// Vertical lines' x from a recorded `drawRawPoints` list: every pair
/// (x0, y0, x1, y1) with x0 == x1.
List<double> verticalXs(Float32List points) => [
      for (var i = 0; i + 3 < points.length; i += 4)
        if (points[i] == points[i + 2]) points[i].toDouble(),
    ];

void main() {
  test('draws the sheet in its colour under everything', () {
    final (painter, _, _) =
        rig(page: standardPage().copyWith(background: 0xFFFAF6EC));
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final rects = canvas.named('drawRect').toList();
    // `Paint` keeps its colour as four float32 components, so the value read
    // back is not `==` the `Color` that went in; the ARGB word is, and it is
    // the value `PageComponent.background` actually stores.
    expect(rects.first.color?.toARGB32(), 0xFFFAF6EC);
    expect(canvas.calls.first.name, 'drawRect');
  });

  test('major lines sit where the oracle says, anchored at the sheet corner',
      () {
    // M-04f and M-04c on one camera; the seeded sweep below is the check.
    final (painter, _, cam) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final raw = canvas.named('drawRawPoints').toList();
    expect(raw, hasLength(2), reason: 'minors then majors');
    final majors = verticalXs(raw.last.args[1]! as Float32List);
    final expected = oracleMajorXs(cam.value, standardPage(), kChromeSize);
    expect(majors.length, expected.length);
    for (var i = 0; i < majors.length; i++) {
      expect(majors[i], closeTo(expected[i], 1e-3));
    }
  });

  test(
      'differential: fifty seeded cameras agree with the literal-ladder oracle',
      () {
    final random = math.Random(0x5EED0004);
    for (var trial = 0; trial < 50; trial++) {
      // [1e-3, 1e2]
      final scale = math.pow(10.0, -3 + random.nextDouble() * 5).toDouble();
      final tx = -5000 + random.nextDouble() * 10000;
      final ty = -5000 + random.nextDouble() * 10000;
      final cam = CameraController(ViewportTransform(
          worldToScreenMatrix: Transform2(scale, 0, 0, -scale, tx, ty)));
      final (painter, _, _) = rig(camera: cam);
      final canvas = SpyCanvas();
      painter.paint(canvas, kChromeSize);
      final raw = canvas.named('drawRawPoints').toList();
      final majors = raw.isEmpty
          ? const <double>[]
          : verticalXs(raw.last.args[1]! as Float32List);
      final expected = oracleMajorXs(cam.value, standardPage(), kChromeSize);
      expect(majors.length, expected.length,
          reason: 'trial $trial, scale $scale');
      for (var i = 0; i < majors.length; i++) {
        expect(majors[i], closeTo(expected[i], 1e-3), reason: 'trial $trial');
      }
    }
  });

  test('the point list is exactly four numbers per line', () {
    // M-04v.
    final (painter, _, _) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    for (final call in canvas.named('drawRawPoints')) {
      final points = call.args[1]! as Float32List;
      expect(points.length % 4, 0);
      expect(points.length ~/ 4,
          anyOf(painter.debugLastMajorCount, painter.debugLastMinorCount));
    }
  });

  test('minors that coincide with a major are not drawn twice', () {
    // Ruling 04-3. Every minor x must differ from every major x.
    final (painter, _, _) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final raw = canvas.named('drawRawPoints').toList();
    final minors = verticalXs(raw.first.args[1]! as Float32List);
    final majors = verticalXs(raw.last.args[1]! as Float32List);
    for (final m in minors) {
      for (final j in majors) {
        expect((m - j).abs(), greaterThan(1e-3));
      }
    }
    expect(minors, isNotEmpty);
  });

  test('bounded at kMinScale, kMaxScale, and the intersection is the range',
      () {
    // Invariant 2, M-04t. At 0.001 px/mm the sheet is 14.85 px wide, so the
    // whole sheet spans a single major cell. At 100 px/mm the sheet is
    // 1.485e6 px wide; over the 800 px viewport the bound is 800/64 + 2 = 14
    // majors and 800/8 + 2 = 102 minors per axis.
    for (final scale in [0.001, 100.0]) {
      final cam = CameraController(ViewportTransform(
          worldToScreenMatrix: Transform2(
              scale, 0, 0, -scale, -7350 * scale + 100, 1230 * scale + 500)));
      final (painter, _, _) = rig(camera: cam);
      painter.paint(SpyCanvas(), kChromeSize);
      expect(
          painter.debugLastMajorCount, lessThanOrEqualTo(2 * (800 / 64 + 2)));
      expect(painter.debugLastMinorCount, lessThanOrEqualTo(2 * (800 / 8 + 2)));
    }
  });

  test('page breaks tile outward and vanish under a 16 px sheet', () {
    // M-04m. Standard camera: sheet 14 850 mm -> 2034 px wide; the visible
    // world spans 800 / 0.137 = 5839 mm, so at most two vertical break
    // lines and two horizontal ones intersect it.
    final (painter, _, _) =
        rig(page: standardPage().copyWith(pageBreaks: true));
    painter.paint(SpyCanvas(), kChromeSize);
    expect(painter.debugLastBreakCount, inInclusiveRange(1, 4));
    final tiny = CameraController(ViewportTransform(
        worldToScreenMatrix: const Transform2(0.001, 0, 0, -0.001, 400, 300)));
    final (small, _, _) =
        rig(page: standardPage().copyWith(pageBreaks: true), camera: tiny);
    small.paint(SpyCanvas(), kChromeSize);
    expect(small.debugLastBreakCount, 0);
  });

  test('a chrome toggle through the log adds no entity and rebuilds no index',
      () {
    // Invariant 1 / criterion 7, end to end: the painter is a listener,
    // not a writer.
    final doc = documentWithPage();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    final painter = PageChromePainter(camera: standardCamera(), page: n);
    final entities = doc.entities.liveCount;
    final rebuilds = index.rebuildCount;
    for (final flag in [true, false, true]) {
      doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
          standardPage().copyWith(gridVisible: flag, pageBreaks: !flag)));
      painter.paint(SpyCanvas(), kChromeSize);
    }
    doc.commands.undo();
    doc.commands.redo();
    expect(doc.entities.liveCount, entities);
    expect(index.rebuildCount, rebuilds);
  });

  test('null page and zero size paint nothing', () {
    final (painter, n, _) = rig();
    n.value = null;
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    expect(canvas.calls, isEmpty);
    n.value = standardPage();
    painter.paint(canvas, Size.zero);
    expect(canvas.calls, isEmpty);
  });
}
