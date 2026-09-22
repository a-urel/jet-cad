### Task 7: `RulerPainter` and `RulerCornerPainter`

**Files:**
- Create: `lib/src/ruler_painter.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`
- Test: `test/ruler_painter_test.dart`

**Interfaces:**
- Produces: `RulerAxis {horizontal, vertical}`, `RulerPainter({axis,
  camera, page, pointer, repaint})`, `RulerCornerPainter({page, repaint})`,
  `debugLastTicks` (a `List<(double screen, bool major, String? label)>`,
  test-only).

- [ ] **Step 1: Write the failing tests.**

```dart
// test/ruler_painter_test.dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';
import 'support/spy_canvas.dart';

void main() {
  const barH = Size(800, kRulerThickness);
  const barV = Size(kRulerThickness, 600);

  RulerPainter make(RulerAxis axis, {CameraController? camera, Offset? pointer}) =>
      RulerPainter(
        axis: axis,
        camera: camera ?? standardCamera(),
        page: ValueNotifier<PageComponent?>(standardPage()),
        pointer: ValueNotifier<Offset?>(pointer),
      );

  test('major ticks sit at worldToScreen of the lattice, labelled in metres', () {
    // M-04a (translation dropped), M-04b (scale dropped), M-04i (unit).
    // At 0.137 px/mm the major is 500 mm (Task 4). Page x = k·500 is world
    // x = 7350 + k·500; screen x = 0.137·world − 611.5.
    final painter = make(RulerAxis.horizontal);
    painter.paint(SpyCanvas(), barH);
    final majors = painter.debugLastTicks.where((t) => t.$2).toList();
    expect(majors, isNotEmpty);
    for (final tick in majors) {
      final pageX = (tick.$1 + 611.5) / 0.137 - 7350;
      expect(pageX / 500, closeTo(pageX / 500 == 0 ? 0 : (pageX / 500).roundToDouble(), 1e-6));
      expect(tick.$3, formatLength(pageX.roundToDouble(), DisplayUnit.meters));
    }
    final spacing = majors[1].$1 - majors[0].$1;
    expect(spacing, closeTo(500 * 0.137, 1e-6));
    expect(majors.first.$1, isNot(closeTo(0, 1)), reason: 'not at the bar edge by chance');
  });

  test('the left ruler reads upward', () {
    // M-04p: page y increases as screen y decreases.
    final painter = make(RulerAxis.vertical);
    painter.paint(SpyCanvas(), barV);
    final majors = painter.debugLastTicks.where((t) => t.$2).toList();
    expect(majors.length, greaterThan(1));
    final values = [for (final t in majors) double.parse(t.$3!.split(' ').first)];
    for (var i = 1; i < majors.length; i++) {
      expect(majors[i].$1, greaterThan(majors[i - 1].$1), reason: 'ticks ordered down the bar');
      expect(values[i], lessThan(values[i - 1]), reason: 'labels decrease downward');
    }
  });

  test('minor ticks are shorter and unlabelled', () {
    final painter = make(RulerAxis.horizontal);
    final canvas = SpyCanvas();
    painter.paint(canvas, barH);
    final minors = painter.debugLastTicks.where((t) => !t.$2);
    expect(minors, isNotEmpty);
    for (final t in minors) {
      expect(t.$3, isNull);
    }
    final lines = canvas.named('drawLine').toList();
    expect(lines.length, greaterThanOrEqualTo(painter.debugLastTicks.length));
  });

  test('the pointer marker is drawn at the pointer, and not without one', () {
    final painter = make(RulerAxis.horizontal, pointer: const Offset(123.4, 50));
    final canvas = SpyCanvas();
    painter.paint(canvas, barH);
    final marker = canvas.named('drawLine').where((c) => c.color == kRulerPointer).toList();
    expect(marker, hasLength(1));
    expect((marker.single.args[0] as Offset).dx, 123.4);
    final none = SpyCanvas();
    make(RulerAxis.horizontal).paint(none, barH);
    expect(none.named('drawLine').where((c) => c.color == kRulerPointer), isEmpty);
  });

  test('past the ladder top, only the bar and the pointer', () {
    final tiny = CameraController(ViewportTransform(
        worldToScreenMatrix: const Transform2(1e-9, 0, 0, -1e-9, 400, 300)));
    final painter = make(RulerAxis.horizontal, camera: tiny);
    painter.paint(SpyCanvas(), barH);
    expect(painter.debugLastTicks, isEmpty);
  });

  test('the corner shows the unit symbol', () {
    final n = ValueNotifier<PageComponent?>(standardPage().copyWith(displayUnit: DisplayUnit.feetInches));
    final painter = RulerCornerPainter(page: n);
    expect(painter.debugLastSymbol(), isNull);
    painter.paint(SpyCanvas(), const Size(kRulerThickness, kRulerThickness));
    expect(painter.debugLastSymbol(), 'ft');
  });
}
```

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/src/ruler_painter.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
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
        for (var i = ((lo - origin) / step).ceil();
            i <= ((hi - origin) / step).floor();
            i++) {
          final world = origin + i * step;
          final isMajor = i % divisor == 0;
          final screen = _horizontal
              ? cam.worldToScreen(Vector2(world, 0)).x
              : cam.worldToScreen(Vector2(0, world)).y;
          final label =
              isMajor ? formatLength(i * step, p.displayUnit) : null;
          ticks.add((screen, isMajor, label));
          _tick(canvas, size, screen, isMajor, label);
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

  void _tick(Canvas canvas, Size size, double screen, bool isMajor, String? label) {
    final length = isMajor ? kMajorTickPixels : kMinorTickPixels;
    if (_horizontal) {
      canvas.drawLine(
          Offset(screen, size.height), Offset(screen, size.height - length), _ink);
      if (label != null) _label(canvas, label, Offset(screen + 2, 1), 0);
    } else {
      canvas.drawLine(
          Offset(size.width, screen), Offset(size.width - length, screen), _ink);
      if (label != null) _label(canvas, label, Offset(1, screen - 2), -math.pi / 2);
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
    _text.paint(canvas,
        Offset((size.width - _text.width) / 2, (size.height - _text.height) / 2));
  }

  @override
  bool shouldRepaint(RulerCornerPainter old) => false;
}
```

Export `src/ruler_painter.dart`.

- [ ] **Step 4: Run to pass.** `TextPainter.layout` in a plain `test`
  needs the Flutter binding: use `TestWidgetsFlutterBinding.ensureInitialized()`
  at the top of `main` in the test. Then the gate line.
- [ ] **Step 5: Commit** — `feat(render): RulerPainter and the corner`.

---

