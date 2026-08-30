import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/gpu_comparison.dart';

const Size _size = Size(400, 300);
const double _dpr = 2.0;
const double _ppmm = 3.7795275590551185;

// The brief's sample `ResolvedStyle` literals gave only `argb` and
// `lineweightHundredths` -- `ResolvedStyle` actually requires all four named
// arguments (`linetype`, `linetypeScale` included), so both constants below
// add the two the sample dropped.
const ResolvedStyle _thick = ResolvedStyle(
    argb: 0xFF102030,
    lineweightHundredths: 50,
    linetype: Handle.none,
    linetypeScale: 1);
const ResolvedStyle _hairline = ResolvedStyle(
    argb: 0xFF102030,
    lineweightHundredths: 5,
    linetype: Handle.none,
    linetypeScale: 1);
// A stroke wide relative to the small radius the seam-join test below draws
// at, so the join wedge it measures is comfortably above one pixel rather
// than sub-pixel. See that test's own comment for why.
const ResolvedStyle _wideStroke = ResolvedStyle(
    argb: 0xFF102030,
    lineweightHundredths: 200,
    linetype: Handle.none,
    linetypeScale: 1);

/// Every shape Plan B draws, at a scale and an offset chosen so nothing sits
/// on the identity transform, the origin, or an axis.
///
/// **Each element is here because a named mutation needs it**, and the test
/// below says which:
///  - the zigzag has three corners, one left turn and one right, so a sign
///    error in `s` shows on one of them;
///  - the hairpin turns past the miter limit, so the bevel path runs;
///  - the circle is closed, so the seam join runs and its absence is a notch;
///  - the point is a `point()` op. **Its mutation (a point emitted as a
///    stroke, M-B8) cannot be seen here, on any corpus.** `VerticesDrawSink`
///    draws a point as a horizontal half-width segment too -- "a horizontal
///    segment of the stroke's own width is a square of it"
///    (`vertices_draw_sink.dart`'s own `point()`) -- and the shader's
///    `kKindPoint` branch builds the identical square directly in device
///    space. Under any collection-to-device map this instrument can
///    legitimately use (conformal: identity or `devicePixelRatio`-only, the
///    only kind jet-cad's camera ever produces -- see `task-9-report.md` for
///    the probe that found a rotated collection-to-device map *would*
///    separate them, and that a rotated residual upstream of it would not,
///    which is why this is a structural fact and not a corpus gap), the
///    two squares are bit-identical, because
///    both are built axis-aligned in the same frame. M-B8's gate is the
///    record level: `geometry_collector_test.dart`'s "a point is one
///    instance of its own kind" and `collector_differential_test.dart`'s
///    per-instance `kind` assertion both fail immediately on it;
///  - the hairline is under one device pixel, so `_coveredArgb` runs. **Its
///    mutation (M-B1', `_coveredArgb` dropped) can survive here too**, for
///    an unrelated reason: `TriangleRasterizer.inked` is coverage-only (see
///    `gpu_comparison.dart`'s doc), so an alpha fade with no coverage change
///    is invisible to this instrument by construction. Its gate is
///    `geometry_collector_test.dart`'s "a sub-pixel stroke keeps its pixel
///    and gives up alpha" and `collector_differential_test.dart`'s hairline
///    fixture.
///  - the spur has a repeated interior point (its second and third raw
///    points coincide), so the join at the corner past the repeat must span
///    it and take its incoming direction from the last point that actually
///    moved, not from the immediate raw predecessor. The Task 7 shader
///    review found that a collector which wrote a join's `p1` as the raw
///    predecessor rather than the last *moving* point would hand the shader
///    `in_len == 0.0`, take the collapse branch, and draw **nothing** at
///    that corner where the sink draws a full join -- silent absence that no
///    instance-count assertion sees. `geometry_collector_test.dart`'s "a
///    repeated point is spanned by the join, not turned into one" pins this
///    at the record level; this is the same shape, in the pixel gate.
void _corpus(DrawSink sink) {
  sink.polyline(
      Float64List.fromList(
          <double>[20, 40, 90, 40, 90, 110, 160, 110, 160, 40]),
      5,
      _thick,
      closed: false);
  sink.polyline(
      Float64List.fromList(<double>[30, 160, 120, 165, 32, 170]), 3, _thick,
      closed: false);
  sink.circle(260, 90, 55, _thick);
  sink.arc(120, 230, 45, 0.4, 2.1, _thick);
  sink.point(340, 210, _thick);
  sink.polyline(Float64List.fromList(<double>[20, 260, 380, 268]), 2, _hairline,
      closed: false);
  // The repeated-interior-point spur: p1 == p2, then a corner at p2/p3.
  sink.polyline(
      Float64List.fromList(<double>[345, 15, 345, 55, 345, 55, 385, 75]),
      4,
      _thick,
      closed: false);
}

void main() {
  test('the resident arm draws the reference drawing', () {
    final r = measureResidentAgreement(_corpus,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);

    // The anti-vacuity floor, the same one `tile_cache_test.dart:958-959`
    // uses: a comparison of two blank frames agrees perfectly and measures
    // nothing. This corpus must actually put ink on the canvas.
    expect(r.referenceInk, greaterThan(5000), reason: r.toString());
    expect(r.residentInk, greaterThan(5000), reason: r.toString());

    // Spec criterion 1's ink threshold: differing pixels below 1% of live
    // ink. This instrument is coverage-only, so this is the whole of what it
    // can assert -- the per-channel half of criterion 1 is gated by the
    // record-level colour assertions in `geometry_collector_test.dart` and
    // `collector_differential_test.dart`.
    expect(r.differing, lessThan(r.referenceInk ~/ 100), reason: r.toString());
  });

  test('the seam join is load-bearing on the circle', () {
    // Not a mutation run in a comment: this measures the notch the seam join
    // fills, by drawing the same circle as an OPEN run of the same chords.
    // If the numbers came out equal, the corpus test above could not see a
    // missing seam either.
    //
    // **Radius 90 with `_thick` -- the brief's sample numbers -- measures
    // zero here, and that is not this instrument disagreeing with itself.**
    // `GeometryCollector.kFlattenTolerance` (0.25 device px) keeps every
    // chord's sagitta error at or below a quarter of a pixel by
    // construction, and the seam join's own notch is bounded by that same
    // per-chord error -- so at a large radius, where each chord already
    // subtends a shallow angle, the notch a coverage rasterizer could ever
    // register rounds to zero pixels almost everywhere on the circle. A
    // probe run across radii 8-90 and lineweights 50-200 (kept out of this
    // file; see `task-9-report.md`) found the notch becomes reliably
    // multi-pixel only at a small radius with a wide stroke, where each
    // chord's turn angle is large enough that the wedge is no longer
    // sub-pixel -- which is what `_wideStroke` and radius 8 below are
    // chosen for, not to make the assertion pass but to make the corner it
    // is asserting about visible to a rasterizer with 1px granularity at
    // all.
    double inkOf(void Function(DrawSink) draw) => measureResidentAgreement(
          draw,
          size: _size,
          devicePixelRatio: _dpr,
          pixelsPerPaperMm: _ppmm,
        ).residentInk.toDouble();

    final closed = inkOf((s) => s.circle(80, 220, 8, _wideStroke));
    // A 2*pi arc is the same chords, open: no closing chord and no seam.
    final open =
        inkOf((s) => s.arc(80, 220, 8, 0, 6.283185307179586, _wideStroke));
    expect(closed, greaterThan(open),
        reason: 'the closed circle has the closing chord and the seam; '
            'closed=$closed open=$open');
  });
}
