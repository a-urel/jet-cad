// The rasterizer is test infrastructure, so it gets its own tests: a golden
// compared through a broken scan-converter is a green test and a wrong
// drawing.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart';

import 'triangle_rasterizer.dart';

Float32List _tri(List<double> xy) => Float32List.fromList(xy);
Int32List _rgb(int argb) => Int32List.fromList(List<int>.filled(3, argb));

void main() {
  test('a triangle covers its interior and not its outside', () {
    // MUTATION: reuse edge AB's direction (bx - ax, by - ay) for edge BC
    // instead of (cx - bx, cy - by) -- a plausible copy-paste when writing
    // the three edge functions. Run: (2, 2) is *not* what goes dark -- at
    // (2, 2) the corrupted w1 comes out 7.5, still non-negative, so the
    // "inside" assertion stays green. What actually goes red is "past the
    // hypotenuse": (5, 5) newly satisfies the corrupted w1 and reads inked
    // when it should not.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 6, 1, 1, 6]), _rgb(0xFFFF0000));
    expect(r.inked(2, 2), isTrue, reason: 'inside');
    expect(r.inked(5, 5), isFalse, reason: 'past the hypotenuse');
    expect(r.inked(7, 7), isFalse, reason: 'outside the bounding box');
  });

  test('winding does not matter', () {
    // MUTATION: reject triangles whose edge functions come out negative and
    // the clockwise one vanishes. `drawVertices` culls nothing, so neither
    // does this.
    //
    // Both sides are pinned to `isTrue`, not just to each other: comparing
    // `cw.inked(2, 2)` against `ccw.inked(2, 2)` alone is satisfied equally
    // by "both true" and "both false", so a mutation that rejects every
    // triangle regardless of winding (e.g. `w0 > 0` in place of `w0 >= 0`
    // dropping the boundary, or any change that goes dark on both windings
    // together) leaves the two sides equal and the test green.
    final ccw = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 6, 1, 1, 6]), _rgb(0xFF00FF00));
    final cw = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 1, 6, 6, 1]), _rgb(0xFF00FF00));
    expect(ccw.inked(2, 2), isTrue, reason: 'counter-clockwise');
    expect(cw.inked(2, 2), isTrue, reason: 'clockwise');
  });

  test('a later triangle draws over an earlier one', () {
    // The buffer's order is the draw order, and the rasterizer must not
    // reorder it -- that is the property the whole sink is built around.
    //
    // MUTATION: skip a pixel that is already inked and this reads red.
    //
    // The expected constant is `0xFF0000`, not `0x0000FF`: the ARGB->RGBA
    // repack puts R at the packed value's byte 0 and B at byte 2 (verified
    // directly -- `rgba(0xFFFF0000) & 0xFFFFFF == 0xFF`,
    // `rgba(0xFF0000FF) & 0xFFFFFF == 0xFF0000`), so blue's marker in the
    // masked low 24 bits is `0xFF0000` and red's is `0x0000FF`.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([0, 0, 8, 0, 0, 8]), _rgb(0xFFFF0000))
      ..observe(_tri([0, 0, 8, 0, 0, 8]), _rgb(0xFF0000FF));
    expect(r.pixels[1 * 8 + 1] & 0x00FFFFFF, 0xFF0000);
  });

  test(
      'a later triangle wins the overlap within a single observe() call, '
      'not just across separate calls', () {
    // Every ordering test above submits one triangle per `observe` call,
    // which pins *call* order, not *buffer* order -- and buffer order is
    // the actual property `VerticesDrawSink.flush` relies on: one call
    // submits an entire frame's triangles in one buffer, walk order first
    // to last (`vertices_draw_sink.dart:32-33`, `observe`'s own doc comment
    // above).
    //
    // MUTATION: walk the buffer back to front --
    // `for (var t = ((colors.length ~/ 3) - 1) * 3; t >= 0; t -= 3)`.
    // A test that submits one triangle per call cannot tell this apart from
    // correct code: reversing which triangle a loop visits first does
    // nothing when the loop only ever sees one triangle. This test submits
    // both triangles in the same buffer, so it is the one that actually
    // exercises the loop's direction.
    final positions = Float32List.fromList([
      0, 0, 8, 0, 0, 8, // red, first in the buffer
      0, 0, 8, 0, 0, 8, // blue, second in the buffer, same footprint
    ]);
    final colors = Int32List.fromList([
      ...List.filled(3, 0xFFFF0000),
      ...List.filled(3, 0xFF0000FF),
    ]);
    final r = TriangleRasterizer(8, 8)..observe(positions, colors);
    expect(r.pixels[1 * 8 + 1] & 0x00FFFFFF, 0xFF0000,
        reason: 'blue is later in the buffer, so it should win');
  });

  test('sub-full alpha survives the ARGB->RGBA repack, not just RGB', () {
    // MUTATION: replace `(argb & 0xFF000000)` with the literal `0xFF000000`
    // (assume every triangle is opaque). Every other fixture in this file
    // uses `0xFF......` alpha, so that substitution would stay green
    // everywhere except here.
    //
    // `VerticesDrawSink._coveredArgb` (`vertices_draw_sink.dart:515`)
    // deliberately fades a stroke thinner than one device pixel instead of
    // drawing it at full opacity, so a rasterizer that silently forced alpha
    // to `0xFF` would certify a Task 10 golden of a thin lineweight as fully
    // opaque when the sink actually drew it faded.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 6, 1, 1, 6]), _rgb(0x80112233));
    expect(r.pixels[2 * 8 + 2], 0x80332211,
        reason: 'alpha 0x80 preserved, R and B swapped into the packed '
            'RGBA value');
  });

  test(
      'two overlapping triangles: whichever is submitted last wins the '
      'overlap, and only the overlap', () {
    // Two distinct triangles (not the identity, not the origin, not equal
    // sides) with a region unique to each and a region shared by both, so a
    // mutation that just paints "last colour everywhere" or "first colour
    // everywhere" is distinguishable from one that gets the overlap wrong.
    //
    // A = (0,0),(5,0),(0,5): x>=0, y>=0, x+y<=5.
    // B = (1,1),(6,1),(1,6): x>=1, y>=1, x+y<=7.
    // (0,0) is inside A only. (5,1) is inside B only. (2,2) is inside both.
    //
    // MUTATION: track "inked at all" instead of "last colour", e.g. skip a
    // pixel once any triangle has touched it, and the overlap keeps A's
    // colour under both submission orders.
    //
    // Markers are the ARGB->RGBA-packed value's low 24 bits, not the ARGB
    // literal read naively: R lands at packed byte 0 and B at byte 2, so
    // red's marker is `0x0000FF` and blue's is `0xFF0000` (verified directly
    // against the packing formula, same as the test above).
    final a = _tri([0, 0, 5, 0, 0, 5]);
    final b = _tri([1, 1, 6, 1, 1, 6]);
    const red = 0xFFFF0000;
    const blue = 0xFF0000FF;
    const redMarker = 0x0000FF;
    const blueMarker = 0xFF0000;

    final aThenB = TriangleRasterizer(8, 8)
      ..observe(a, _rgb(red))
      ..observe(b, _rgb(blue));
    expect(aThenB.pixels[0 * 8 + 0] & 0x00FFFFFF, redMarker, reason: 'A-only');
    expect(aThenB.pixels[1 * 8 + 5] & 0x00FFFFFF, blueMarker, reason: 'B-only');
    expect(aThenB.pixels[2 * 8 + 2] & 0x00FFFFFF, blueMarker,
        reason: 'overlap, B submitted last');

    final bThenA = TriangleRasterizer(8, 8)
      ..observe(b, _rgb(blue))
      ..observe(a, _rgb(red));
    expect(bThenA.pixels[0 * 8 + 0] & 0x00FFFFFF, redMarker, reason: 'A-only');
    expect(bThenA.pixels[1 * 8 + 5] & 0x00FFFFFF, blueMarker, reason: 'B-only');
    expect(bThenA.pixels[2 * 8 + 2] & 0x00FFFFFF, redMarker,
        reason: 'overlap, A submitted last');
  });

  test('geometry outside the surface is clipped, not wrapped', () {
    // A = (-20,-20), B = (30,-20), C = (-20,30): the right-angle vertex is
    // far outside the surface in both axes (drives the raw bounding box
    // negative, which is what removing the clamp turns into a RangeError),
    // and the hypotenuse (edge BC) actually crosses the canvas -- verified
    // directly against the edge functions: (0,0) has w0=1025, w1=450,
    // w2=1025 (inside), and (7,7) has w0=1375, w1=-250, w2=1375 (outside, on
    // the far side of BC alone). A triangle whose hypotenuse never reaches
    // the canvas at all would pass this test by accident, whichever pixel it
    // picked, so the fixture has to actually cut the surface.
    //
    // MUTATION: drop the row and column clamps and this throws a RangeError,
    // or worse, writes a pixel on the opposite edge.
    //
    // MUTATION: `x <= maxX` -> `x < maxX` (an off-by-one on the loop bound,
    // easy to write by analogy with a half-open range). `ceil(30)` clamps to
    // `width - 1 == 7`, so column 7 is only reached because the loop is
    // inclusive of `maxX`; drop that and the whole rightmost column of the
    // clamped bounding box is never visited, silently. (7, 0) sits at
    // x + y = 8 <= 10 -- genuinely inside this triangle, and reachable only
    // through that inclusive last column -- so it is the assertion that
    // catches it; (7, 7) alone would not, since it is outside the triangle
    // either way.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([-20, -20, 30, -20, -20, 30]), _rgb(0xFF000000));
    expect(r.inked(0, 0), isTrue);
    expect(r.inked(7, 0), isTrue, reason: 'the clamped box\'s last column');
    expect(r.inked(7, 7), isFalse);
  });

  test(
      'a triangle entirely off the surface inks nothing, even after its '
      'bounding box is clamped onto the surface', () {
    // A = (20,20), B = (25,20), C = (20,25): the whole triangle is beyond
    // both edges of an 8x8 surface. `floor`/`ceil` then the row and column
    // clamps collapse its bounding box onto pixel (7,7) alone -- a real
    // pixel, well inside the canvas -- so this only inks nothing if the
    // per-pixel edge test still runs inside the clamped box; a rasterizer
    // that shortcuts "clamped bbox is small, just fill it" would light (7,7)
    // up regardless of the triangle's true edges.
    //
    // MUTATION: `if (w0 < 0 && w1 < 0 && w2 < 0) continue;` (De Morgan's flip
    // on the reject test) -- at (7.5, 7.5) only two of the three edge values
    // are negative, so the mutant no longer rejects it and (7,7) inks.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([20, 20, 25, 20, 20, 25]), _rgb(0xFF000000));
    expect(List.generate(64, (i) => r.pixels[i]).every((p) => p == 0), isTrue);
  });

  test('a degenerate triangle inks nothing', () {
    // MUTATION: divide by a zero area and every pixel comes out NaN-inked.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 5, 1, 3, 1]), _rgb(0xFF000000));
    expect(List.generate(64, (i) => r.pixels[i]).every((p) => p == 0), isTrue);
  });

  test('vertices exactly on pixel centres ink the pixels they sit on', () {
    // A = (1.5,1.5), B = (5.5,1.5), C = (1.5,4.5) -- all three vertices are
    // pixel centres. At a vertex, two of the three edge functions are exactly
    // zero (the two edges meeting there) and the third is strictly positive,
    // so under the inclusive `w >= 0` fill rule every vertex's own pixel is
    // inked, not just points strictly inside.
    //
    // MUTATION: `if (w0 <= 0 || w1 <= 0 || w2 <= 0) continue;` -- excludes
    // the boundary, and every vertex pixel (which sits exactly on two edges)
    // goes dark.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1.5, 1.5, 5.5, 1.5, 1.5, 4.5]), _rgb(0xFF000000));
    expect(r.inked(1, 1), isTrue, reason: 'vertex A');
    expect(r.inked(5, 1), isTrue, reason: 'vertex B');
    expect(r.inked(1, 4), isTrue, reason: 'vertex C');
    expect(r.inked(0, 1), isFalse, reason: 'one column left of the triangle');
  });

  test(
      'an edge that passes exactly through a pixel centre inks it: the '
      'inclusive side of the boundary wins, on both edges of a shared seam',
      () {
    // A = (2.5,0.5), B = (2.5,6.5), C = (6.5,3.5). Edge AB is the vertical
    // line x = 2.5, so every pixel centre with x = 2.5 -- not just a
    // vertex -- has w = 0 on that edge alone (its other two edge values are
    // strictly positive here). The rasterizer includes it: the fill rule is
    // `w >= 0` on every edge of every triangle, so two triangles that meet
    // exactly on this line would both claim the seam pixel and whichever
    // draws last owns it -- consistent with "last triangle wins", which is
    // the property this whole scan-converter exists to preserve.
    //
    // MUTATION: `if (w0 <= 0 || w1 <= 0 || w2 <= 0) continue;` -- excludes
    // the boundary, and pixel (2,3), sitting exactly on edge AB, goes dark.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([2.5, 0.5, 2.5, 6.5, 6.5, 3.5]), _rgb(0xFF000000));
    expect(r.inked(2, 3), isTrue, reason: 'on the edge line x = 2.5');
    expect(r.inked(1, 3), isFalse, reason: 'one column past the edge');
  });

  test(
      'wired to a real VerticesDrawSink flush, it reads the submitted '
      'stroke band and the exact ARGB->RGBA channel order', () async {
    // Exercises the actual seam this class exists for: a real
    // `VerticesDrawSink` walk, through its `FlushObserver`, into the
    // rasterizer -- not a hand-assembled triangle list. The colour
    // 0xFF112233 has three distinct, non-repeating channels, so a swapped or
    // dropped channel in the ARGB -> RGBA repacking is visible rather than
    // hidden by two channels happening to share a value.
    //
    // MUTATION: pack straight through without swapping R and B (treat the
    // input as already RGBA) and the read-back pixel comes out 0xFF112233
    // instead of the expected 0xFF332211.
    final rasterizer = TriangleRasterizer(64, 64);
    final sink = VerticesDrawSink(
      pixelsPerPaperMm: 4.0,
      canvas: Canvas(PictureRecorder()),
    )..observer = rasterizer.observe;

    sink
      ..beginResidual(Transform2.identity())
      ..polyline(
        Float64List.fromList([10, 32, 54, 32]),
        2,
        const ResolvedStyle(
          argb: 0xFF112233,
          lineweightHundredths: 100,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
        ),
        closed: false,
      )
      ..endResidual()
      ..flush();

    // half-width = 100/100 * 4.0 / 2 = 2.0, so the quad spans y in [30, 34].
    expect(rasterizer.inked(30, 32), isTrue, reason: 'inside the stroke band');
    expect(rasterizer.inked(5, 32), isFalse, reason: 'left of the stroke');
    expect(rasterizer.inked(30, 40), isFalse, reason: 'below the stroke band');
    expect(rasterizer.pixels[32 * 64 + 30], 0xFF332211,
        reason: 'ARGB 0xFF112233 repacked to RGBA, R and B swapped');

    // The `pixels` buffer alone does not exercise `toImage`, the fourth of
    // the four members this class exists to hand to Tasks 10 and 11
    // (`matchesGoldenFile` reads an `Image`, not a `Uint32List`). Reading
    // the encoded image straight back with `rawRgba` and comparing against
    // the same buffer pins that the whole `decodeImageFromPixels` round
    // trip -- width, height, pixel format and byte order together -- lands
    // the exact bytes this class wrote, not merely an image of the right
    // dimensions.
    //
    // MUTATION: pass `ui.PixelFormat.bgra8888` instead of `rgba8888` to
    // `decodeImageFromPixels`, and the round-tripped pixel reads back with
    // its outer channels swapped again -- 0xFF112233, not 0xFF332211,
    // undoing the very swap this test's first half just checked.
    final image = await rasterizer.toImage();
    addTearDown(image.dispose);
    expect(image.width, 64);
    expect(image.height, 64);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);
    final roundTripped = bytes!.buffer.asUint32List();
    expect(roundTripped[32 * 64 + 30], 0xFF332211,
        reason: 'toImage round-trips the packed pixel exactly');
    expect(roundTripped[32 * 64 + 5], 0,
        reason: 'and leaves an untouched pixel at zero');
  });
}
