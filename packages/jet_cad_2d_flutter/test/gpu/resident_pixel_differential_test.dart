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
///  - the point is a `point()` op, whose mutation (a point emitted as a
///    stroke, M-B8) this instrument DOES see -- an earlier draft of this
///    comment claimed the two arms drew bit-identical squares and that was
///    wrong; see `task-9-report.md`'s "Fix round 1" section for the
///    corrected arithmetic (a 7.56x3.78 device-pixel rectangle where both
///    the reference and the correct resident arm draw a 3.78x3.78 square,
///    because the mutated code subtracts a DEVICE-space half-width from a
///    COLLECTION-space centre before `collectionToDevice` doubles that
///    offset again -- exactly the shear `kKindPoint` exists to prevent, per
///    `geometry_collector.dart:284-289`). It is still also gated at the
///    record level, independently: `geometry_collector_test.dart`'s "a
///    point is one instance of its own kind" and
///    `collector_differential_test.dart`'s per-instance `kind` assertion
///    both fail immediately on it;
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
    // `collector_differential_test.dart`. Kept alongside the tight bound
    // below because it is the spec's own criterion and should stay visible,
    // even though on this corpus it is far looser than what the collector
    // and shader actually achieve.
    expect(r.differing, lessThan(r.referenceInk ~/ 100), reason: r.toString());

    // A tight absolute bound, not a threshold moved to make anything pass:
    // the measured value on this corpus is 0 and stays 0 on every run, so
    // `differing` is asserted near that, not near the 1%-of-ink slack above.
    // `differing` is not asserted at exactly 0 because the two arms compute
    // in different float precisions all the way to the rasteriser: the
    // collector's record is `Float32List` (about 1.19e-7 relative
    // precision) while `VerticesDrawSink` computes in `double` throughout,
    // so at this corpus's device-pixel coordinate magnitudes (order 1e2-1e3)
    // the two arms' triangle vertices can differ by roughly
    // `1e3 * 1.19e-7 ~= 1.2e-4` device pixels -- far too small to move a
    // pixel's coverage in general, but not zero, and a pixel whose centre
    // happens to sit within that margin of a triangle edge could flip
    // `TriangleRasterizer`'s half-open inside test on one side or the other.
    // `lessThan(4)` admits a couple of such boundary flips -- plausible
    // float32-rounding noise -- while staying two orders of magnitude below
    // every named-mutation kill measured for this file (M-B3'/M-B7/M-B15 on
    // the seam test below, M-B8 above): a future 1-2px drift here reads as
    // rounding, not as a regression this bound was loosened to hide.
    expect(r.differing, lessThan(4), reason: r.toString());
  });

  test('the seam join is load-bearing on the circle', () {
    // Two assertions below, deliberately not one, and the differential
    // goes FIRST:
    //
    //  1. The actual differential, on the closed draw: `r.differing` must
    //     stay near zero. The reference draws this seam too, so a collector
    //     that drops or misplaces the join disagrees with the REFERENCE
    //     here.
    //  2. A resident-arm SELF-consistency probe, second and supplementary:
    //     the same circle drawn CLOSED must ink more than drawn as an OPEN
    //     run of the same chords. This alone never reads `referenceInk` or
    //     `r.differing` -- it would still pass if the resident arm agreed
    //     with nothing at all, so long as it agreed with itself more when
    //     closed, which is why it is not asserted first: `expect` throws on
    //     its first failure, and a mutation that breaks both must be seen
    //     failing the differential, not only this weaker probe.
    //
    // **Radius 90 with `_thick` -- the brief's sample numbers -- measures
    // zero on (1) and (2) alike, and that is not this instrument
    // disagreeing with itself.** `GeometryCollector.kFlattenTolerance`
    // (0.25 device px) keeps every chord's sagitta error at or below a
    // quarter of a pixel by construction, and the seam join's own notch is
    // bounded by that same per-chord error -- so at a large radius, where
    // each chord already subtends a shallow angle, the notch a coverage
    // rasterizer could ever register rounds to zero pixels almost
    // everywhere on the circle (an independent area computation puts
    // radius 90's notch at about 0.27 square device pixels -- provably
    // invisible to a 1px-granularity rasteriser). A probe run across radii
    // 8-90 and lineweights 50-200 (kept out of this file; see
    // `task-9-report.md`) found the notch becomes reliably multi-pixel only
    // at a small radius with a wide stroke (radius 8's notch is about 14
    // square device pixels), where each chord's turn angle is large enough
    // that the wedge is no longer sub-pixel -- which is what `_wideStroke`
    // and radius 8 below are chosen for, not to make the assertion pass but
    // to make the corner it is asserting about visible to a rasterizer with
    // 1px granularity at all.
    final closedAgreement = measureResidentAgreement(
        (s) => s.circle(80, 220, 8, _wideStroke),
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm);
    // A 2*pi arc is the same chords, open: no closing chord back to point 0
    // and no seam join. (Its OWN final `_runTo` still lands near the start
    // angle -- a full sweep's last sample is `start + sweep`, not a
    // zero-length skip back to point 0 -- so both draws include a
    // closing-length chord; only the closed draw adds the seam join on top
    // of it. That is why M-B3'/M-B7/M-B15 below read the closed circle
    // exactly `1484 == 1484`-style equal to the open one, rather than
    // leaving some smaller chord-sized residue: the whole gap this
    // assertion measures IS the one seam join, nothing else.)
    final openInk = measureResidentAgreement(
            (s) => s.arc(80, 220, 8, 0, 6.283185307179586, _wideStroke),
            size: _size,
            devicePixelRatio: _dpr,
            pixelsPerPaperMm: _ppmm)
        .residentInk
        .toDouble();

    // The differential itself, asserted FIRST so a run that fails both
    // this and the self-consistency check below reports on the
    // differential specifically -- `expect` throws on its first failure,
    // and the differential is the one this task's fix round asked to see
    // redden. The reference draws this seam too (about 14 square device
    // pixels at this radius/stroke), so a collector that drops the seam,
    // collapses it onto its vertex, or gets its side wrong disagrees with
    // the REFERENCE here, not only with its own open-run twin. Same bound
    // and same reasoning as the corpus test's tight bound above.
    expect(closedAgreement.differing, lessThan(4),
        reason: 'the reference and resident arms must agree on the seam '
            'itself; ${closedAgreement.toString()}');

    // The resident-arm self-consistency probe, second: still worth keeping,
    // because it is the only one of the two that says anything about the
    // resident arm's OWN closed-vs-open behaviour independent of the
    // reference.
    expect(closedAgreement.residentInk.toDouble(), greaterThan(openInk),
        reason: 'the closed circle has the seam join on top of the same '
            'closing-length chord the open run already draws; '
            'closed=${closedAgreement.residentInk} open=$openInk');
  });
}
