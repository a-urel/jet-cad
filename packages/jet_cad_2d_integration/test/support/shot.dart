// A window capture for the integration tests (3a Task 28, R-16's room
// lines): the plan library's own test fixture's pixel helpers
// (jet_cad_2d_plan/test/support/canvas_fixture.dart:31-60, the seed's
// themes and the page swatches; :140-210, `windowAt`, `pumpThemed`,
// `rgbOf`, `hex`, `channelDistance`, `Shot`, `shoot`; :212-226,
// `pixelOf`), copied, since another package cannot import it; every name
// it uses is the Flutter layer's, the engine's or `dart:ui`'s.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show CameraGestureDetector, InteractionLayer;
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The floor planner app's seed (F-1), its real light and dark schemes.
const Color seed = Color(0xFF2266CC);
final ThemeData lightTheme = ThemeData(colorSchemeSeed: seed);
final ThemeData darkTheme =
    ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark);

/// The page panel's White and Blueprint swatches (F-7).
const int white = 0xFFFFFFFF;
const int blueprint = 0xFF1F3A5F;

/// The capture: a repaint boundary around the whole window.
final GlobalKey shotKey = GlobalKey(debugLabel: 'shot');

/// The window at [size] logical pixels, device pixel ratio 1, reset after
/// the test.
void windowAt(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pumps [home] under the seed's themes in [mode], at zero theme animation,
/// inside the capture boundary. Pumping it again with another [mode] keeps
/// every state below: the tree has the same shape.
Future<void> pumpThemed(WidgetTester tester, Widget home, ThemeMode mode) =>
    tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: RepaintBoundary(key: shotKey, child: home),
    ));

/// `0xRRGGBB` of a colour.
int rgbOf(Color c) => c.toARGB32() & 0xFFFFFF;

String hex(int rgb) => '0x${rgb.toRadixString(16).padLeft(6, '0')}';

/// The largest per-channel difference of two `0xRRGGBB` values.
int channelDistance(int a, int b) => [16, 8, 0]
    .map((s) => (((a >> s) & 0xFF) - ((b >> s) & 0xFF)).abs())
    .reduce(math.max);

/// One captured frame of the window, at device pixel ratio 1.
final class Shot {
  Shot(this.bytes, this.width, this.height);

  final ByteData bytes;
  final int width, height;

  /// `0xRRGGBB` at pixel ([x], [y]).
  int rgbAt(int x, int y) {
    final i = (y * width + x) * 4;
    return (bytes.getUint8(i) << 16) |
        (bytes.getUint8(i + 1) << 8) |
        bytes.getUint8(i + 2);
  }

  Iterable<int> _block(int x, int y) sync* {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        yield rgbAt(x + dx, y + dy);
      }
    }
  }

  /// The pixel of the 3 x 3 block around ([x], [y]) nearest [rgb].
  int nearest(int x, int y, int rgb) => _block(x, y).reduce(
      (a, b) => channelDistance(a, rgb) <= channelDistance(b, rgb) ? a : b);

  /// The 3 x 3 block's brightest (largest smallest channel) pixel.
  int brightest(int x, int y) =>
      _block(x, y).reduce((a, b) => _minChannel(a) >= _minChannel(b) ? a : b);

  /// The 3 x 3 block's darkest (smallest largest channel) pixel.
  int darkest(int x, int y) =>
      _block(x, y).reduce((a, b) => _maxChannel(a) <= _maxChannel(b) ? a : b);

  /// The most common colour of row [y] from [x0] to [x1] (exclusive).
  int modeOfRow(int y, int x0, int x1) {
    final counts = <int, int>{};
    for (var x = x0; x < x1; x++) {
      counts.update(rgbAt(x, y), (n) => n + 1, ifAbsent: () => 1);
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

int _minChannel(int rgb) =>
    math.min((rgb >> 16) & 0xFF, math.min((rgb >> 8) & 0xFF, rgb & 0xFF));
int _maxChannel(int rgb) =>
    math.max((rgb >> 16) & 0xFF, math.max((rgb >> 8) & 0xFF, rgb & 0xFF));

/// Captures the window as it is now.
Future<Shot> shoot(WidgetTester tester) async {
  final boundary =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final shot = Shot(raw!, image.width, image.height);
    image.dispose();
    return shot;
  }))!;
}

/// The global pixel of world [w] in the [view]th drawing area: the pixel
/// whose square holds the point.
(int, int) pixelOf(WidgetTester tester, Vector2 w, {int view = 0}) {
  final area = find.byType(InteractionLayer).at(view);
  final camera = tester
      .widget<CameraGestureDetector>(find
          .ancestor(of: area, matching: find.byType(CameraGestureDetector))
          .first)
      .camera
      .value;
  final topLeft = tester.getTopLeft(area);
  // The alignment needs a drawing area on whole pixels.
  expect(topLeft.dx, topLeft.dx.roundToDouble());
  expect(topLeft.dy, topLeft.dy.roundToDouble());
  final s = camera.worldToScreen(w);
  return ((topLeft.dx + s.x).floor(), (topLeft.dy + s.y).floor());
}
