import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
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
  @visibleForTesting
  int debugLastMajorCount = 0;
  @visibleForTesting
  int debugLastMinorCount = 0;
  @visibleForTesting
  int debugLastBreakCount = 0;

  /// Grown once to the bound, reused; `sublistView`s of it reach the canvas.
  ///
  /// Both grid passes of one paint write into *disjoint* spans of it: the
  /// majors start where the minors stopped. That keeps each pass's list an
  /// independently readable view for as long as the paint lasts — a second
  /// pass writing from index 0 would rewrite the numbers the first one
  /// produced, and a canvas that holds the list rather than copying it
  /// (the test double does) would then see the wrong grid.
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
      debugLastMinorCount = _lines(
          canvas, cam, p, minor, minX, minY, maxX, maxY, _minor,
          skipEvery: scale.divisor);
    }
    debugLastMajorCount = _lines(
        canvas, cam, p, scale.majorMm, minX, minY, maxX, maxY, _major,
        start: debugLastMinorCount * 4);
    canvas.restore();
  }

  /// Vertical then horizontal lattice lines of [stepMm] anchored at the
  /// sheet origin inside the range; returns how many were drawn. A minor
  /// index that is a multiple of [skipEvery] coincides with a major and is
  /// left to the major pass (Ruling 04-3). Writing begins at [start] so a
  /// second pass does not tread on the list the first one handed the canvas.
  int _lines(
      Canvas canvas,
      ViewportTransform cam,
      PageComponent p,
      double stepMm,
      double minX,
      double minY,
      double maxX,
      double maxY,
      Paint paint,
      {int skipEvery = 0,
      int start = 0}) {
    final i0 = ((minX - p.originX) / stepMm).ceil();
    final i1 = ((maxX - p.originX) / stepMm).floor();
    final j0 = ((minY - p.originY) / stepMm).ceil();
    final j1 = ((maxY - p.originY) / stepMm).floor();
    final columns = math.max(0, i1 - i0 + 1);
    final rows = math.max(0, j1 - j0 + 1);
    final needed = start + (columns + rows) * 4;
    // A grow leaves the earlier pass's view pointing at the old list, which
    // still holds its own numbers: only this pass writes into the new one.
    if (_buffer.length < needed) _buffer = Float32List(needed);
    final top = cam.worldToScreen(Vector2(minX, maxY));
    final bottom = cam.worldToScreen(Vector2(maxX, minY));
    var n = start;
    // `%` on Dart ints is non-negative, so the skip holds for negative i too.
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
    if (n == start) return 0;
    canvas.drawRawPoints(
        PointMode.lines, Float32List.sublistView(_buffer, start, n), paint);
    return (n - start) ~/ 4;
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
