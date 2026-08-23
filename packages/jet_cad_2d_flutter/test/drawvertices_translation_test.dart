// Software Skia's `drawVertices` is not invariant under a whole-device-pixel
// canvas translation -- the instrument property that bounds Plan 3g's tile
// cache, and the reason its accepted gap is a gap rather than a defect.
//
// A tile is rasterised into its own surface, so every vertex reaches Skia
// offset by the tile's position in the frame. That offset is a whole number of
// device pixels and the tile is blitted back at exactly the same whole number,
// so in exact arithmetic the round trip is the identity. It is not the
// identity in `Float32`: the offset moves a coordinate to a different binary
// exponent, and a coordinate near zero that gains a few hundred pixels loses
// its low bits there. For the vertices below the device x moves from
// `-17.943408966064453` to an exact `-401.94340896606445`, which the nearest
// `Float32` renders as `-401.94342041015625` -- an error of 1.144e-05 device
// pixels.
//
// That error is far too small to move an edge past a sample point, *unless*
// the edge passes exactly through one. These vertices are the stroke of a line
// whose device slope is exactly 3/50, so its edge grazes a sample point every
// 50 device pixels, and at each of those the error decides the tie.
//
// Driven with `Canvas.drawVertices` directly -- no `VerticesDrawSink`, no
// `TileCache`, nothing this repository wrote -- so a green run here is a fact
// about `flutter_test`'s software Skia, not about this codebase. **It is
// asserted as non-zero on purpose.** If a Skia upgrade ever makes this path
// translation-invariant, this file goes red, and whoever sees it should
// re-measure `tile_cache_test.dart`'s accepted gap: it may have closed.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// The exact `Float32` vertices `VerticesDrawSink` hands `drawVertices` for
/// one near-axis line -- world `(20, 84)` to `(220, 96)` at the tile rig's
/// camera -- captured through `VerticesDrawSink.observer` and pasted here so
/// this file depends on nothing but `dart:ui`.
final Float32List kNearAxisQuad = Float32List.fromList([
  -8.971704483032227, 205.87159729003906, //
  -9.028295516967773, 204.92840576171875,
  271.0282897949219, 189.07159423828125,
  -9.028295516967773, 204.92840576171875,
  270.9717102050781, 188.12840270996094,
  271.0282897949219, 189.07159423828125,
]);

/// The same span and the same awkward x values, but flat: no perpendicular
/// step for a sub-ulp error to move.
final Float32List kAxisAlignedQuad = Float32List.fromList([
  -8.971704483032227, 205.87159729003906, //
  -8.971704483032227, 204.92840576171875,
  271.0282897949219, 205.87159729003906,
  -8.971704483032227, 204.92840576171875,
  271.0282897949219, 204.92840576171875,
  271.0282897949219, 205.87159729003906,
]);

final Int32List kWhite = Int32List.fromList(List<int>.filled(6, -1));

const int kWidth = 800;
const int kHeight = 600;
const double kDpr = 2.0;

Future<Uint8List> _render(void Function(Canvas) draw) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(kDpr);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(kWidth, kHeight);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Differing pixels between [a] read at `(x + dxDevice, y + dyDevice)` and [b]
/// read at `(x, y)`, over the window both surfaces hold.
int _differing(Uint8List a, Uint8List b, int dxDevice, int dyDevice) {
  var n = 0;
  for (var y = 0; y + dyDevice < kHeight; y++) {
    for (var x = 0; x + dxDevice < kWidth; x++) {
      final ai = ((y + dyDevice) * kWidth + (x + dxDevice)) * 4;
      final bi = (y * kWidth + x) * 4;
      if (a[ai] != b[bi] ||
          a[ai + 1] != b[bi + 1] ||
          a[ai + 2] != b[bi + 2] ||
          a[ai + 3] != b[bi + 3]) {
        n++;
      }
    }
  }
  return n;
}

Future<int> _translationError(Float32List quad, int tileX, int tileY) async {
  void draw(Canvas canvas) {
    final vertices = Vertices.raw(VertexMode.triangles, quad, colors: kWhite);
    // `BlendMode.dst` with per-vertex colours is what `VerticesDrawSink`
    // issues; the mode is irrelevant here and the geometry is the point.
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }

  // 32 logical pixels is 64 device pixels: one tile of the size
  // `tile_fixture.dart` uses. The surface is the same size in both arms, so
  // this isolates the translation from any clip or bounds effect.
  final anchored = await _render(draw);
  final translated = await _render((canvas) {
    canvas.translate(-tileX * 32.0, -tileY * 32.0);
    draw(canvas);
  });
  return _differing(anchored, translated, tileX * 64, tileY * 64);
}

void main() {
  test('a near-axis quad moves under a whole-device-pixel translation',
      () async {
    // Tiles (3,6) through (6,6) of the rig's grid: where this quad's edge
    // grazes a sample point. Measured 2026-08-24: 1, 2, 2, 2.
    var total = 0;
    for (final tileX in [3, 4, 5, 6]) {
      total += await _translationError(kNearAxisQuad, tileX, 6);
    }
    expect(total, greaterThan(0),
        reason: 'if this is now zero, software Skia has become invariant '
            'under an integral-device-pixel translate and the accepted gap '
            'in tile_cache_test.dart should be re-measured');
    // Bounded, so a genuinely broken translate here would still be visible.
    expect(total, lessThan(50));
  });

  test('an axis-aligned quad does not', () async {
    // The control. Same span, same x values, same translations -- a flat edge
    // has no perpendicular step for a sub-ulp error to move across.
    for (final tileX in [3, 4, 5, 6]) {
      expect(await _translationError(kAxisAlignedQuad, tileX, 6), 0,
          reason: 'tile x $tileX');
    }
  });
}
