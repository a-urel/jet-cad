import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'chrome_style.dart';

enum RulerAxis { horizontal, vertical }

/// One ruler bar (spec D11): ticks from the shared ladder, zero at the
/// sheet corner, labels in the display unit, a pointer marker. The bar is
/// co-extensive with the drawing area on its axis, so `size` on that axis
/// is the child's, and every tick is placed through `camera.worldToScreen`.
class RulerPainter extends CustomPainter {
  RulerPainter({
    required this.axis,
    required this.camera,
    required this.page,
    required this.pointer,
    super.repaint,
  });

  final RulerAxis axis;
  final CameraController camera;
  final ValueListenable<PageComponent?> page;
  final ValueListenable<Offset?> pointer;

  /// Test-only: (screen coordinate along the axis, isMajor, label).
  @visibleForTesting
  List<(double, bool, String?)> debugLastTicks = const [];

  final Paint _background = Paint()..color = kRulerBackground;
  final Paint _ink = Paint()
    ..color = kRulerInk
    ..strokeWidth = 1.0;
  final Paint _marker = Paint()
    ..color = kRulerPointer
    ..strokeWidth = 1.0;
  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr);

  bool get _horizontal => axis == RulerAxis.horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    final ticks = <(double, bool, String?)>[];
    canvas.drawRect(Offset.zero & size, _background);
    if (_horizontal) {
      canvas.drawLine(Offset(0, size.height - 0.5),
          Offset(size.width, size.height - 0.5), _ink);
    } else {
      canvas.drawLine(Offset(size.width - 0.5, 0),
          Offset(size.width - 0.5, size.height), _ink);
    }
    final p = page.value;
    final cam = camera.value;
    if (p != null && !size.isEmpty) {
      final scale =
          GridScale.pick(p.displayUnit, cam.scale, floorMm: p.gridStepMm);
      if (scale != null) {
        final step = scale.minorMm ?? scale.majorMm;
        final divisor = scale.divisor;
        // Ruling 04-4: the bar's own size gives the right range on its axis.
        final visible = cam.visibleWorld(size);
        final origin = _horizontal ? p.originX : p.originY;
        final lo = _horizontal ? visible.minX : visible.minY;
        final hi = _horizontal ? visible.maxX : visible.maxY;
        final i0 = ((lo - origin) / step).ceil();
        final i1 = ((hi - origin) / step).floor();
        // The horizontal camera axis is not flipped, so ascending world x is
        // ascending screen x; the vertical axis is (world y is up, screen y
        // is down — ViewportTransform's documented flip), so ascending world
        // y is *descending* screen y. Iterating i1 down to i0 on that axis
        // keeps debugLastTicks in ascending-screen order on both bars, i.e.
        // in the order a reader walks the ruler from its near edge outward.
        void addTick(int i) {
          final world = origin + i * step;
          final isMajor = i % divisor == 0;
          final screen = _horizontal
              ? cam.worldToScreen(Vector2(world, 0)).x
              : cam.worldToScreen(Vector2(0, world)).y;
          final label = isMajor ? formatLength(i * step, p.displayUnit) : null;
          ticks.add((screen, isMajor, label));
          _tick(canvas, size, screen, isMajor, label);
        }

        if (_horizontal) {
          for (var i = i0; i <= i1; i++) {
            addTick(i);
          }
        } else {
          for (var i = i1; i >= i0; i--) {
            addTick(i);
          }
        }
      }
    }
    final pointerAt = pointer.value;
    if (pointerAt != null) {
      final s = _horizontal ? pointerAt.dx : pointerAt.dy;
      if (_horizontal) {
        canvas.drawLine(Offset(s, 0), Offset(s, size.height), _marker);
      } else {
        canvas.drawLine(Offset(0, s), Offset(size.width, s), _marker);
      }
    }
    debugLastTicks = ticks;
  }

  void _tick(
      Canvas canvas, Size size, double screen, bool isMajor, String? label) {
    final length = isMajor ? kMajorTickPixels : kMinorTickPixels;
    if (_horizontal) {
      canvas.drawLine(Offset(screen, size.height),
          Offset(screen, size.height - length), _ink);
      if (label != null) _label(canvas, label, Offset(screen + 2, 1), 0);
    } else {
      canvas.drawLine(Offset(size.width, screen),
          Offset(size.width - length, screen), _ink);
      if (label != null) {
        _label(canvas, label, Offset(1, screen - 2), -math.pi / 2);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, double angle) {
    _text.text = TextSpan(
        text: text,
        style: const TextStyle(color: kRulerInk, fontSize: kRulerLabelSize));
    _text.layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    _text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RulerPainter old) => false;
}

/// The 24 × 24 box where the bars meet: the unit's symbol.
class RulerCornerPainter extends CustomPainter {
  RulerCornerPainter({required this.page, super.repaint});

  final ValueListenable<PageComponent?> page;
  final Paint _background = Paint()..color = kRulerBackground;
  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr);
  String? _lastSymbol;

  /// Test-only.
  @visibleForTesting
  String? debugLastSymbol() => _lastSymbol;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _background);
    final symbol = page.value?.displayUnit.symbol;
    _lastSymbol = symbol;
    if (symbol == null) return;
    _text.text = TextSpan(
        text: symbol,
        style: const TextStyle(color: kRulerInk, fontSize: kRulerLabelSize));
    _text.layout();
    _text.paint(
        canvas,
        Offset(
            (size.width - _text.width) / 2, (size.height - _text.height) / 2));
  }

  @override
  bool shouldRepaint(RulerCornerPainter old) => false;
}
