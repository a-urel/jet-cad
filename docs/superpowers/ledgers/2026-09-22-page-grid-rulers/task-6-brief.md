### Task 6: `PageChromePainter`

**Files:**
- Create: `lib/src/page_chrome_painter.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`
- Test: `test/page_chrome_painter_test.dart`

**Interfaces:**
- Consumes: `GridScale.pick`, `sheetWorldRect`, `PageNotifier`,
  `CameraController`, `chrome_style.dart`.
- Produces: `PageChromePainter({camera, page, repaint, onPaintForTest})`,
  `debugLastMajorCount`, `debugLastMinorCount`, `debugLastBreakCount`
  (test-only counters, reset per paint).

- [ ] **Step 1: Write the failing tests.**

```dart
// test/page_chrome_painter_test.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

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
  0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000,
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
List<double> oracleMajorXs(ViewportTransform cam, PageComponent page, Size size) {
  final step = oracleMajor(cam.scale);
  if (step == null) return const [];
  final sheet = sheetWorldRect(page);
  final visible = cam.visibleWorld(size);
  final minX = math.max(sheet.minX, visible.minX);
  final maxX = math.min(sheet.maxX, visible.maxX);
  if (minX > maxX) return const [];
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
    final (painter, _, _) = rig(page: standardPage().copyWith(background: 0xFFFAF6EC));
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final rects = canvas.named('drawRect').toList();
    expect(rects.first.color, const Color(0xFFFAF6EC));
    expect(canvas.calls.first.name, 'drawRect');
  });

  test('major lines sit where the oracle says, anchored at the sheet corner', () {
    // M-04f and M-04c on one camera; the seeded sweep below is the check.
    final (painter, _, cam) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final raw = canvas.named('drawRawPoints').toList();
    expect(raw, hasLength(2), reason: 'minors then majors');
    final majors = verticalXs(raw.last.args[1] as Float32List);
    final expected = oracleMajorXs(cam.value, standardPage(), kChromeSize);
    expect(majors.length, expected.length);
    for (var i = 0; i < majors.length; i++) {
      expect(majors[i], closeTo(expected[i], 1e-3));
    }
  });

  test('differential: fifty seeded cameras agree with the literal-ladder oracle', () {
    final random = math.Random(0x5EED0004);
    for (var trial = 0; trial < 50; trial++) {
      final scale = math.pow(10.0, -3 + random.nextDouble() * 5).toDouble();  // [1e-3, 1e2]
      final tx = -5000 + random.nextDouble() * 10000;
      final ty = -5000 + random.nextDouble() * 10000;
      final cam = CameraController(ViewportTransform(
          worldToScreenMatrix: Transform2(scale, 0, 0, -scale, tx, ty)));
      final (painter, _, _) = rig(camera: cam);
      final canvas = SpyCanvas();
      painter.paint(canvas, kChromeSize);
      final raw = canvas.named('drawRawPoints').toList();
      final majors = raw.isEmpty ? const <double>[] : verticalXs(raw.last.args[1] as Float32List);
      final expected = oracleMajorXs(cam.value, standardPage(), kChromeSize);
      expect(majors.length, expected.length, reason: 'trial $trial, scale $scale');
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
      final points = call.args[1] as Float32List;
      expect(points.length % 4, 0);
      expect(points.length ~/ 4, anyOf(painter.debugLastMajorCount, painter.debugLastMinorCount));
    }
  });

  test('minors that coincide with a major are not drawn twice', () {
    // Ruling 04-3. Every minor x must differ from every major x.
    final (painter, _, _) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final raw = canvas.named('drawRawPoints').toList();
    final minors = verticalXs(raw.first.args[1] as Float32List);
    final majors = verticalXs(raw.last.args[1] as Float32List);
    for (final m in minors) {
      for (final j in majors) {
        expect((m - j).abs(), greaterThan(1e-3));
      }
    }
    expect(minors, isNotEmpty);
  });

  test('bounded at kMinScale, kMaxScale, and the intersection is the range', () {
    // Invariant 2, M-04t. At 0.001 px/mm the sheet is 14.85 px wide and
    // pick is null: nothing. At 100 px/mm the sheet is 1.485e6 px wide;
    // over the 800 px viewport the bound is 800/64 + 2 = 14 majors and
    // 800/8 + 2 = 102 minors per axis.
    for (final scale in [0.001, 100.0]) {
      final cam = CameraController(ViewportTransform(
          worldToScreenMatrix: Transform2(scale, 0, 0, -scale,
              -7350 * scale + 100, 1230 * scale + 500)));
      final (painter, _, _) = rig(camera: cam);
      painter.paint(SpyCanvas(), kChromeSize);
      expect(painter.debugLastMajorCount, lessThanOrEqualTo(2 * (800 / 64 + 2)));
      expect(painter.debugLastMinorCount, lessThanOrEqualTo(2 * (800 / 8 + 2)));
    }
  });

  test('page breaks tile outward and vanish under a 16 px sheet', () {
    // M-04m. Standard camera: sheet 14 850 mm → 2034 px wide; the visible
    // world spans 800 / 0.137 = 5839 mm, so at most two vertical break
    // lines and two horizontal ones intersect it.
    final (painter, _, _) = rig(page: standardPage().copyWith(pageBreaks: true));
    painter.paint(SpyCanvas(), kChromeSize);
    expect(painter.debugLastBreakCount, inInclusiveRange(1, 4));
    final tiny = CameraController(ViewportTransform(
        worldToScreenMatrix: const Transform2(0.001, 0, 0, -0.001, 400, 300)));
    final (small, _, _) = rig(page: standardPage().copyWith(pageBreaks: true), camera: tiny);
    small.paint(SpyCanvas(), kChromeSize);
    expect(small.debugLastBreakCount, 0);
  });

  test('a chrome toggle through the log adds no entity and rebuilds no index', () {
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
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, standardPage().copyWith(gridVisible: flag, pageBreaks: !flag)));
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
```

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/src/page_chrome_painter.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'chrome_style.dart';
import 'viewport_transform.dart';

/// The sheet, the grid and the page breaks, under `DraftCanvas` in its own
/// `RepaintBoundary` (spec D8). Everything it hands `dart:ui` is a screen
/// coordinate; the grid is enumerated over `visibleWorld ∩ sheet`, never
/// over the sheet, which is what bounds the line count at every zoom.
class PageChromePainter extends CustomPainter {
  PageChromePainter({
    required this.camera,
    required this.page,
    super.repaint,
    this.onPaintForTest,
  });

  final CameraController camera;
  final ValueListenable<PageComponent?> page;
  final void Function()? onPaintForTest;

  /// Test-only, reset per paint.
  int debugLastMajorCount = 0;
  int debugLastMinorCount = 0;
  int debugLastBreakCount = 0;

  /// Grown once to the bound, reused; `sublistView`s of it reach the canvas.
  Float32List _buffer = Float32List(0);

  final Paint _sheetFill = Paint();
  final Paint _sheetEdge = Paint()
    ..color = kSheetEdgeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _minor = Paint()
    ..color = kMinorGridColor
    ..strokeWidth = 1.0;
  final Paint _major = Paint()
    ..color = kMajorGridColor
    ..strokeWidth = 1.0;
  final Paint _breaks = Paint()
    ..color = kPageBreakColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    debugLastMajorCount = 0;
    debugLastMinorCount = 0;
    debugLastBreakCount = 0;
    final p = page.value;
    if (p == null || size.isEmpty) return;
    final cam = camera.value;
    final sheet = sheetWorldRect(p);
    final topLeft = cam.worldToScreen(Vector2(sheet.minX, sheet.maxY));
    final bottomRight = cam.worldToScreen(Vector2(sheet.maxX, sheet.minY));
    final sheetScreen =
        Rect.fromLTRB(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y);

    _sheetFill.color = Color(p.background);
    canvas.drawRect(sheetScreen, _sheetFill);
    canvas.drawRect(sheetScreen, _sheetEdge);
    if (p.gridVisible) _paintGrid(canvas, size, cam, p, sheet, sheetScreen);
    if (p.pageBreaks) _paintBreaks(canvas, size, cam, p, sheet);
  }

  void _paintGrid(Canvas canvas, Size size, ViewportTransform cam,
      PageComponent p, Aabb2 sheet, Rect sheetScreen) {
    final scale =
        GridScale.pick(p.displayUnit, cam.scale, floorMm: p.gridStepMm);
    if (scale == null) return;
    final visible = cam.visibleWorld(size);
    // The iteration range. The clip below only trims the half-pixel at the
    // sheet's edge; at kMaxScale the sheet is 1.5e6 px wide and iterating
    // it would be fifteen thousand lines per axis (spec review B3).
    final minX = math.max(visible.minX, sheet.minX);
    final maxX = math.min(visible.maxX, sheet.maxX);
    final minY = math.max(visible.minY, sheet.minY);
    final maxY = math.min(visible.maxY, sheet.maxY);
    if (minX > maxX || minY > maxY) return;

    canvas.save();
    canvas.clipRect(sheetScreen);
    final minor = scale.minorMm;
    if (minor != null) {
      debugLastMinorCount = _lines(canvas, cam, p, minor, minX, minY, maxX,
          maxY, _minor, skipEvery: scale.divisor);
    }
    debugLastMajorCount =
        _lines(canvas, cam, p, scale.majorMm, minX, minY, maxX, maxY, _major);
    canvas.restore();
  }

  /// Vertical then horizontal lattice lines of [stepMm] anchored at the
  /// sheet origin inside the range; returns how many were drawn. A minor
  /// index that is a multiple of [skipEvery] coincides with a major and is
  /// left to the major pass (Ruling 04-3).
  int _lines(Canvas canvas, ViewportTransform cam, PageComponent p,
      double stepMm, double minX, double minY, double maxX, double maxY,
      Paint paint, {int skipEvery = 0}) {
    final i0 = ((minX - p.originX) / stepMm).ceil();
    final i1 = ((maxX - p.originX) / stepMm).floor();
    final j0 = ((minY - p.originY) / stepMm).ceil();
    final j1 = ((maxY - p.originY) / stepMm).floor();
    final columns = math.max(0, i1 - i0 + 1);
    final rows = math.max(0, j1 - j0 + 1);
    final needed = (columns + rows) * 4;
    if (_buffer.length < needed) _buffer = Float32List(needed);
    final top = cam.worldToScreen(Vector2(minX, maxY));
    final bottom = cam.worldToScreen(Vector2(maxX, minY));
    var n = 0;
    for (var i = i0; i <= i1; i++) {
      if (skipEvery > 0 && i % skipEvery == 0) continue;
      final x = cam.worldToScreen(Vector2(p.originX + i * stepMm, minY)).x;
      _buffer[n++] = x;
      _buffer[n++] = top.y;
      _buffer[n++] = x;
      _buffer[n++] = bottom.y;
    }
    for (var j = j0; j <= j1; j++) {
      if (skipEvery > 0 && j % skipEvery == 0) continue;
      final y = cam.worldToScreen(Vector2(minX, p.originY + j * stepMm)).y;
      _buffer[n++] = top.x;
      _buffer[n++] = y;
      _buffer[n++] = bottom.x;
      _buffer[n++] = y;
    }
    if (n == 0) return 0;
    canvas.drawRawPoints(
        PointMode.lines, Float32List.sublistView(_buffer, 0, n), paint);
    return n ~/ 4;
  }

  void _paintBreaks(Canvas canvas, Size size, ViewportTransform cam,
      PageComponent p, Aabb2 sheet) {
    final w = sheet.maxX - sheet.minX;
    final h = sheet.maxY - sheet.minY;
    if (w * cam.scale < kBreaksMinSheetPixels ||
        h * cam.scale < kBreaksMinSheetPixels) {
      return;
    }
    final visible = cam.visibleWorld(size);
    final path = Path();
    var count = 0;
    for (var i = ((visible.minX - p.originX) / w).ceil();
        i <= ((visible.maxX - p.originX) / w).floor();
        i++) {
      final x = cam.worldToScreen(Vector2(p.originX + i * w, 0)).x;
      _dash(path, Offset(x, 0), Offset(x, size.height));
      count++;
    }
    for (var j = ((visible.minY - p.originY) / h).ceil();
        j <= ((visible.maxY - p.originY) / h).floor();
        j++) {
      final y = cam.worldToScreen(Vector2(0, p.originY + j * h)).y;
      _dash(path, Offset(0, y), Offset(size.width, y));
      count++;
    }
    debugLastBreakCount = count;
    if (count > 0) canvas.drawPath(path, _breaks);
  }

  /// 6 px on, 4 px off, along a screen segment.
  static void _dash(Path path, Offset a, Offset b) {
    final length = (b - a).distance;
    if (length == 0) return;
    final dir = (b - a) / length;
    for (var t = 0.0; t < length; t += 10) {
      final s = a + dir * t;
      final e = a + dir * math.min(t + 6, length);
      path.moveTo(s.dx, s.dy);
      path.lineTo(e.dx, e.dy);
    }
  }

  @override
  bool shouldRepaint(PageChromePainter old) => false;
}
```

Export `src/page_chrome_painter.dart`.

- [ ] **Step 4: Run to pass.** The "sheet in its colour" test reads
  `RecordedCall.color`; `SpyCanvas` snapshots the paint's colour at call
  time, so the field `Paint` is fine. Then the gate line.
- [ ] **Step 5: Commit** — `feat(render): PageChromePainter — sheet, grid
  over the visible intersection, page breaks`.

---

