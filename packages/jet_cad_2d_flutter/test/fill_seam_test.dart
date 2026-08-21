// The translucent seam, measured against the real engine.
//
// A triangulation tiles its interior -- triangles share edges, not area --
// so under an OPAQUE fill there is nothing to see: `VerticesDrawSink.fillPolygon`
// draws `style.argb` directly (never `_coveredArgb`), and Task 14 already
// pins that agreement row at 0.00%. Under a TRANSLUCENT fill the picture can
// change: `Paint.isAntiAlias` defaults true on the vertices `Paint` and
// `VerticesDrawSink` never clears it, so a shared edge between two adjacent
// triangles is covered partially by each of them and the same edge pixel is
// blended twice at partial alpha. `Canvas.drawPath` computes coverage once
// for the whole closed path and has no seam to begin with. Both are real
// geometry, not a bug in either sink -- the question this file answers is
// whether the resulting seam is visible enough, in practice, to route
// translucent fills a different way.
//
// **`TriangleRasterizer` -- the instrument every golden in this repository
// uses -- cannot see this.** Its inner loop is a plain store,
// `pixels[y * width + x] = rgba`: no blending, no alpha compositing, no
// antialiasing, last write wins. A seam test written against it would pass
// against a sink drawing the artefact at full strength, which is this
// codebase's dominant failure mode -- the degenerate fixture -- in its most
// expensive form: one a review has already approved. The instrument here
// instead is a `ui.Picture` recorded through each sink, `picture.toImage()`,
// `toByteData()`, compared pixel by pixel -- the same escape hatch Plan 3d's
// Task 2 used when it needed an answer the rasterizer could not give.
//
// The rule is declared before the measurement, in the design document and
// this task's brief, and repeated here so the expectations below are
// legible without it:
//
//   Routing fires if more than 0.5% of interior pixels differ by more than
//   8/255 in any channel, or any single interior pixel differs by more than
//   32/255.
//
// "Interior" excludes the outer boundary ring, one device pixel wide, where
// ordinary edge antialiasing is not the artefact under test. The exclusion
// is computed from the fixture's own geometry -- point-in-polygon plus a
// distance-to-boundary check -- not from either rendered image, so it cannot
// be biased toward whichever sink happens to agree with it.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Logical viewport and the `flutter_test` binding's own default device
/// pixel ratio -- not overridden here, only asserted, so a future change to
/// the binding's default cannot silently move this measurement's scale
/// without failing loudly first.
const Size kLogicalViewport = Size(400, 300);
const double kDevicePixelRatio = 3.0;
const int kWidth = 1200; // 400 * 3.0
const int kHeight = 900; // 300 * 3.0

/// A convex rectangle with one rectangular notch cut into its top edge --
/// "convex-and-a-notch", the design's own fixture description -- given
/// directly in device-pixel coordinates. Both sinks are driven under an
/// identity residual (their default), so these coordinates *are* the
/// device-pixel geometry each one draws; no camera or paper scale sits
/// between this array and the picture.
///
/// Two reflex vertices, at (500, 300) and (700, 300): enough concavity that
/// `triangulateSimplePolygon` must ear-clip rather than fan, so the
/// triangulation shares interior edges the way a real region's does and the
/// mode-2 seam this file measures has somewhere to occur.
final Float64List _boundary = Float64List.fromList([
  100, 100, //
  500, 100, //
  500, 300, //
  700, 300, //
  700, 100, //
  1100, 100, //
  1100, 800, //
  100, 800, //
  100, 100, // closing duplicate, as the boundary store always carries
]);
const int _boundaryCount = 9;

final Int32List _triangles =
    triangulateSimplePolygon(_boundary, _boundaryCount);

/// Translucent purple over white -- alpha `0x80`, as the design's rule
/// declares. `lineweightHundredths` is nonzero only because the column is
/// shared with strokes; `fillPolygon` never reads it through `_coveredArgb`.
final ResolvedStyle _fillStyle = ResolvedStyle(
  argb: 0x803366CC,
  lineweightHundredths: 10,
  linetype: ReservedHandles.continuousLinetype,
  linetypeScale: 1.0,
);

/// One entity: a single `fillPolygon` call, no boundary stroke. The fixture
/// the design names is the fill alone.
void translucentFill(DrawSink sink) {
  sink.fillPolygon(_boundary, _boundaryCount, _triangles, _fillStyle);
}

DrawSink canvasSink(Canvas canvas) => CanvasDrawSink(
      canvas: canvas,
      pixelsPerPaperMm: 1.0,
      measurer: FlutterTextMeasurer(),
      textStyleOf: (_) =>
          throw UnimplementedError('this fixture carries no text'),
    );

VerticesDrawSink verticesSink(Canvas canvas) => VerticesDrawSink(
      pixelsPerPaperMm: 1.0,
      canvas: canvas,
      devicePixelRatio: kDevicePixelRatio,
    );

/// Records [draw] into a Picture through a fresh sink and rasterises it in
/// the real engine, WITH blending. `TriangleRasterizer` cannot be used here:
/// see the file comment above.
Future<ByteData> renderThrough(WidgetTester tester,
    DrawSink Function(Canvas) make, void Function(DrawSink) draw) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, kWidth.toDouble(), kHeight.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF));
  final sink = make(canvas);
  draw(sink);
  // `CanvasDrawSink` submits as it goes; `VerticesDrawSink` batches and needs
  // an explicit flush to reach the Canvas at all.
  if (sink is VerticesDrawSink) sink.flush();
  final picture = recorder.endRecording();
  final image = await tester.runAsync(() => picture.toImage(kWidth, kHeight));
  addTearDown(image!.dispose);
  final data = (await tester
      .runAsync(() => image.toByteData(format: ImageByteFormat.rawRgba)))!;
  picture.dispose();
  return data;
}

/// Even-odd point-in-polygon test against [_boundary], at a point in the
/// same device-pixel space the fixture is drawn in.
bool _insideBoundary(double px, double py) {
  var inside = false;
  final n = _boundaryCount - 1; // drop the stored closing duplicate
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = _boundary[i * 2], yi = _boundary[i * 2 + 1];
    final xj = _boundary[j * 2], yj = _boundary[j * 2 + 1];
    if ((yi > py) != (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

double _distanceToSegment(
    double px, double py, double ax, double ay, double bx, double by) {
  final abx = bx - ax, aby = by - ay;
  final abLenSq = abx * abx + aby * aby;
  final t = abLenSq == 0
      ? 0.0
      : (((px - ax) * abx + (py - ay) * aby) / abLenSq).clamp(0.0, 1.0);
  final cx = ax + t * abx, cy = ay + t * aby;
  final dx = px - cx, dy = py - cy;
  return math.sqrt(dx * dx + dy * dy);
}

/// The distance from `(px, py)` to the nearest point on [_boundary]'s ring.
double _distanceToBoundary(double px, double py) {
  final n = _boundaryCount - 1;
  var minDist = double.infinity;
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    final d = _distanceToSegment(px, py, _boundary[i * 2], _boundary[i * 2 + 1],
        _boundary[j * 2], _boundary[j * 2 + 1]);
    if (d < minDist) minDist = d;
  }
  return minDist;
}

/// The fixture's own interior, eroded by one device pixel: pixel centres
/// strictly inside [_boundary] and farther than one device pixel from every
/// edge of it.
///
/// Computed purely from the fixture's geometry -- never from either rendered
/// image -- so the mask cannot be biased toward whichever sink happens to
/// agree with it. The scan is bounded to [_boundary]'s own bounding box
/// (with a one-pixel margin) rather than the whole 1200x900 surface, which
/// only trims iteration count and changes nothing else: every pixel outside
/// that box fails `_insideBoundary` regardless.
Iterable<(int, int)> interiorPixels() sync* {
  for (var y = 99; y < 801; y++) {
    for (var x = 99; x < 1101; x++) {
      final cx = x + 0.5, cy = y + 0.5;
      if (!_insideBoundary(cx, cy)) continue;
      if (_distanceToBoundary(cx, cy) <= 1.0) continue;
      yield (x, y);
    }
  }
}

/// The largest per-channel (R, G, B, A) absolute difference between the two
/// captures at device pixel `(x, y)`, out of a `width`-wide RGBA8888 buffer.
int maxChannelDelta(ByteData a, ByteData b, int x, int y, int width) {
  final i = (y * width + x) * 4;
  var worst = 0;
  for (var c = 0; c < 4; c++) {
    final d = (a.getUint8(i + c) - b.getUint8(i + c)).abs();
    if (d > worst) worst = d;
  }
  return worst;
}

void main() {
  testWidgets('the translucent seam, measured', (tester) async {
    expect(tester.view.devicePixelRatio, kDevicePixelRatio,
        reason: 'the fixture and its interior mask are both computed in '
            'device pixels at this ratio; a binding default change would '
            'silently rescale the measurement without this assertion');

    final canvasBytes =
        await renderThrough(tester, canvasSink, translucentFill);
    final verticesBytes =
        await renderThrough(tester, verticesSink, translucentFill);

    var over8 = 0, interior = 0, worst = 0;
    for (final (x, y) in interiorPixels()) {
      interior++;
      final d = maxChannelDelta(canvasBytes, verticesBytes, x, y, kWidth);
      if (d > 8) over8++;
      if (d > worst) worst = d;
    }
    final fraction = over8 / interior;
    // ignore: avoid_print
    print('SEAM interior=$interior over8=$over8 '
        'fraction=${(fraction * 100).toStringAsFixed(3)}% worst=$worst');

    expect(interior, greaterThan(4000),
        reason:
            'non-vacuity: an empty interior would satisfy every bound below');
    expect(fraction, lessThanOrEqualTo(0.005),
        reason: 'above this the plan routes translucent fills through the '
            "fallback sink; see the design's declared rule");
    expect(worst, lessThanOrEqualTo(32));
  });
}
